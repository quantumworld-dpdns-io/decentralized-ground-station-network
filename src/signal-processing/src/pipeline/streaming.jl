module streaming

using DSP
using FFTW
using Statistics
using LinearAlgebra
using Random

using ..dsp.filters
using ..dsp.fft_analysis
using ..dsp.modulation
using ..io.arrow_io
using ..io.sdr
using ..pipeline.signal_pipeline

export StreamingPipeline, StreamConfig, start_stream, stop_stream,
       process_buffer, StreamResult, StreamCallback,
       SDRStreamSource, FileStreamSource

abstract type StreamSource end

struct SDRStreamSource <: StreamSource
    device_type::String
    center_freq::Float64
    sample_rate::Float64
    gain::Float64
    buffer_size::Int
end

struct FileStreamSource <: StreamSource
    filename::String
    format::String
    chunk_size::Int
end

mutable struct StreamConfig
    source::StreamSource
    buffer_size::Int
    overlap_samples::Int
    enable_processing::Bool
    enable_recording::Bool
    output_format::String
    output_dir::String
    max_duration_seconds::Float64
    callback_interval::Int
end

function StreamConfig(;
    source::StreamSource=SDRStreamSource("hackrf", 2.4e9, 2.5e6, 40.0, 65536),
    buffer_size::Int=65536,
    overlap_samples::Int=1024,
    enable_processing::Bool=true,
    enable_recording::Bool=false,
    output_format::String="cf32",
    output_dir::String=".",
    max_duration_seconds::Float64=Inf,
    callback_interval::Int=10,
)
    return StreamConfig(source, buffer_size, overlap_samples, enable_processing,
                        enable_recording, output_format, output_dir,
                        max_duration_seconds, callback_interval)
end

mutable struct StreamResult
    total_samples::Int
    buffers_processed::Int
    elapsed_seconds::Float64
    sample_rate::Float64
    center_freq::Float64
    spectrum_estimate::Dict{String,Any}
    snr_estimate::Float64
    active::Bool
    error_message::String
    processing_times::Vector{Float64}
end

function StreamResult()
    return StreamResult(0, 0, 0.0, 0.0, 0.0,
                        Dict{String,Any}(), 0.0,
                        false, "", Float64[])
end

abstract type StreamCallback end

struct LoggingCallback <: StreamCallback
    log_interval::Int
end

struct SaveCallback <: StreamCallback
    output_path::String
    format::String
end

mutable struct StreamingPipeline
    config::StreamConfig
    source::StreamSource
    result::StreamResult
    callbacks::Vector{StreamCallback}
    running::Bool
    buffer_queue::Vector{Vector{Complex{Float32}}}
    processing_pipeline::signal_pipeline.PipelineConfig
    recording_handle::Union{IOStream, Nothing}
    total_captured::Int
end

function StreamingPipeline(config::StreamConfig)
    source = config.source
    pipe_config = signal_pipeline.PipelineConfig(
        sample_rate=source.sample_rate,
        center_freq=source.center_freq,
    )
    return StreamingPipeline(config, source, StreamResult(),
                             StreamCallback[], false,
                             Vector{Complex{Float32}}[],
                             pipe_config, nothing, 0)
end

function start_stream(pipeline::StreamingPipeline)
    pipeline.running = true
    pipeline.result.active = true
    pipeline.result.sample_rate = pipeline.source.sample_rate
    pipeline.result.center_freq = pipeline.source.center_freq

    if pipeline.config.enable_recording
        timestamp = string(round(Int, time()))
        fname = joinpath(pipeline.config.output_dir, "stream_$timestamp.$(pipeline.config.output_format)")
        pipeline.recording_handle = open(fname, "w")
    end

    start_time = time()
    buffer_count = 0

    while pipeline.running
        current_time = time()
        elapsed = current_time - start_time
        if elapsed >= pipeline.config.max_duration_seconds
            break
        end

        buffer = acquire_buffer(pipeline)
        if isempty(buffer)
            sleep(0.001)
            continue
        end

        if pipeline.config.enable_processing
            process_buffer(pipeline, buffer)
        end

        if pipeline.config.enable_recording && pipeline.recording_handle !== nothing
            write(pipeline.recording_handle, reinterpret(Float32, buffer))
        end

        pipeline.total_captured += length(buffer)
        buffer_count += 1
        pipeline.result.buffers_processed = buffer_count
        pipeline.result.total_samples = pipeline.total_captured
        pipeline.result.elapsed_seconds = elapsed

        if buffer_count % pipeline.config.callback_interval == 0
            process_callbacks(pipeline)
        end
    end

    stop_stream(pipeline)
    return pipeline.result
end

function acquire_buffer(pipeline::StreamingPipeline) -> Vector{Complex{Float32}}
    source = pipeline.config.source
    if source isa FileStreamSource
        if !isfile(source.filename)
            return Complex{Float32}[]
        end
        data = open(source.filename, "r") do io
            if pipeline.total_captured > 0
                seek(io, pipeline.total_captured * 8)
            end
            raw = read(io, source.chunk_size * 8)
            reinterpret(Complex{Float32}, raw)
        end
        return data
    else
        buffer_size = source.buffer_size
        return rand(Complex{Float32}, buffer_size) * 0.01
    end
end

function process_buffer(pipeline::StreamingPipeline, buffer::Vector{Complex{Float32}})
    start_time = time()
    result = signal_pipeline.run_processing_pipeline(buffer, pipeline.processing_pipeline)
    elapsed = (time() - start_time) * 1000

    push!(pipeline.result.processing_times, elapsed)
    if length(pipeline.result.processing_times) > 100
        popfirst!(pipeline.result.processing_times)
    end

    if haskey(result.spectrum, "magnitude")
        spectrum_mag = result.spectrum["magnitude"]
        if isempty(get(pipeline.result.spectrum_estimate, "magnitude", Float64[]))
            pipeline.result.spectrum_estimate = result.spectrum
        else
            alpha = 0.3
            prev = pipeline.result.spectrum_estimate["magnitude"]
            if length(prev) == length(spectrum_mag)
                pipeline.result.spectrum_estimate["magnitude"] = alpha .* spectrum_mag .+ (1 - alpha) .* prev
            end
        end
    end

    pipeline.result.snr_estimate = 0.9 * pipeline.result.snr_estimate + 0.1 * result.snr_estimate
end

function process_callbacks(pipeline::StreamingPipeline)
    for cb in pipeline.callbacks
        if cb isa LoggingCallback
            @info "Stream: $(pipeline.result.total_samples) samples, " *
                  "SNR: $(round(pipeline.result.snr_estimate, digits=1)) dB, " *
                  "buffers: $(pipeline.result.buffers_processed)"
        end
    end
end

function stop_stream(pipeline::StreamingPipeline)
    pipeline.running = false
    pipeline.result.active = false

    if pipeline.recording_handle !== nothing
        close(pipeline.recording_handle)
        pipeline.recording_handle = nothing
    end
end

function add_callback!(pipeline::StreamingPipeline, callback::StreamCallback)
    push!(pipeline.callbacks, callback)
end

function remove_callbacks!(pipeline::StreamingPipeline)
    empty!(pipeline.callbacks)
end

end
