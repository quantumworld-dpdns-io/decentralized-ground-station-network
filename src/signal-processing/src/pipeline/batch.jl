module batch

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
using ..io.file_formats
using ..pipeline.signal_pipeline
using ..ml.classifier

export BatchProcessor, BatchConfig, BatchResult,
       run_batch_processing, process_file_list,
       aggregate_results, BatchFileInfo

struct BatchFileInfo
    path::String
    format::String
    size_bytes::Int
    duration_seconds::Float64
    sample_rate::Float64
    center_freq::Float64
end

mutable struct BatchConfig
    input_files::Vector{String}
    output_dir::String
    pipeline_config::signal_pipeline.PipelineConfig
    recursive::Bool
    max_files::Int
    parallel::Bool
    max_workers::Int
    save_individual::Bool
    save_aggregate::Bool
    aggregate_format::String
    overwrite::Bool
end

function BatchConfig(;
    input_files::Vector{String}=String[],
    output_dir::String="./results",
    recursive::Bool=false,
    max_files::Int=0,
    parallel::Bool=true,
    max_workers::Int=Threads.nthreads(),
    save_individual::Bool=true,
    save_aggregate::Bool=true,
    aggregate_format::String="arrow",
    overwrite::Bool=false,
)
    pipe_config = signal_pipeline.PipelineConfig()
    return BatchConfig(input_files, output_dir, pipe_config, recursive,
                       max_files, parallel, max_workers, save_individual,
                       save_aggregate, aggregate_format, overwrite)
end

mutable struct BatchResult
    total_files::Int
    processed::Int
    failed::Int
    results::Vector{signal_pipeline.PipelineResult}
    file_info::Vector{BatchFileInfo}
    processing_times::Vector{Float64}
    aggregate_spectrum::Dict{String,Any}
    aggregate_modulation::Dict{String,Any}
    average_snr::Float64
    total_duration_seconds::Float64
    start_time::Float64
    end_time::Float64
    success::Bool
    error_messages::Vector{String}
end

function BatchResult()
    return BatchResult(0, 0, 0, signal_pipeline.PipelineResult[],
                       BatchFileInfo[], Float64[],
                       Dict{String,Any}(), Dict{String,Any}(),
                       0.0, 0.0, 0.0, 0.0, true, String[])
end

function run_batch_processing(
    input_files::Vector{String},
    output_dir::String,
    config::Dict{String,Any}=Dict{String,Any}(),
) -> BatchResult
    batch_config = BatchConfig(input_files=input_files, output_dir=output_dir)
    return process_file_list(batch_config)
end

function process_file_list(config::BatchConfig) -> BatchResult
    result = BatchResult()
    result.start_time = time()
    result.total_files = length(config.input_files)

    mkpath(config.output_dir)

    files_to_process = config.input_files
    if config.max_files > 0
        files_to_process = files_to_process[1:min(config.max_files, length(files_to_process))]
    end

    result.file_info = [scan_file(f) for f in files_to_process]

    if config.parallel
        process_parallel(config, files_to_process, result)
    else
        process_sequential(config, files_to_process, result)
    end

    if config.save_aggregate
        save_aggregate_results(config, result)
    end

    result.end_time = time()
    result.success = result.failed == 0
    return result
end

function process_sequential(config::BatchConfig, files::Vector{String}, result::BatchResult)
    for (idx, filepath) in enumerate(files)
        proc_start = time()
        try
            samples = file_formats.read_signal_file(filepath)
            pipeline_result = signal_pipeline.run_processing_pipeline(samples, config.pipeline_config)
            push!(result.results, pipeline_result)
            push!(result.processing_times, (time() - proc_start) * 1000)
            result.processed += 1

            if config.save_individual
                base = splitext(basename(filepath))[1]
                out_path = joinpath(config.output_dir, base * "_result.arrow")
                arrow_io.write_results(out_path, Dict{String,Any}(
                    "spectrum_frequencies" => get(pipeline_result.spectrum, "frequencies", Float64[]),
                    "spectrum_magnitude" => get(pipeline_result.spectrum, "magnitude", Float64[]),
                    "snr" => pipeline_result.snr_estimate,
                    "peak_frequencies" => pipeline_result.peak_frequencies,
                    "processing_time_ms" => pipeline_result.processing_time_ms,
                ))
            end
        catch e
            push!(result.error_messages, "Error processing $filepath: $e")
            result.failed += 1
        end

        if idx % 10 == 0
            @info "Batch progress: $idx/$(length(files)) files"
        end
    end
end

function process_parallel(config::BatchConfig, files::Vector{String}, result::BatchResult)
    lock = ReentrantLock()
    prog = Threads.Atomic{Int}(0)

    Threads.@threads for filepath in files
        try
            samples = file_formats.read_signal_file(filepath)
            pipeline_result = signal_pipeline.run_processing_pipeline(samples, config.pipeline_config)

            Threads.lock(lock) do
                push!(result.results, pipeline_result)
                push!(result.processing_times, pipeline_result.processing_time_ms)
                result.processed += 1

                if config.save_individual
                    base = splitext(basename(filepath))[1]
                    out_path = joinpath(config.output_dir, base * "_result.arrow")
                    arrow_io.write_results(out_path, Dict{String,Any}(
                        "spectrum_frequencies" => get(pipeline_result.spectrum, "frequencies", Float64[]),
                        "spectrum_magnitude" => get(pipeline_result.spectrum, "magnitude", Float64[]),
                        "snr" => pipeline_result.snr_estimate,
                    ))
                end
            end
        catch e
            Threads.lock(lock) do
                push!(result.error_messages, "Error processing $filepath: $e")
                result.failed += 1
            end
        end

        Threads.atomic_add!(prog, 1)
        val = prog[]
        if val % 10 == 0
            @info "Batch progress: $val/$(length(files)) files"
        end
    end
end

function aggregate_results(result::BatchResult)
    if isempty(result.results)
        return
    end

    all_snrs = Float64[]
    all_peak_freqs = Float64[]
    mod_counts = Dict{String,Int}()

    for r in result.results
        push!(all_snrs, r.snr_estimate)
        append!(all_peak_freqs, r.peak_frequencies)

        mod_type = get(r.modulation_result, "detected_scheme", "unknown")
        mod_counts[mod_type] = get(mod_counts, mod_type, 0) + 1
    end

    result.average_snr = mean(all_snrs)
    result.total_duration_seconds = sum(getfield.(result.file_info, :duration_seconds))

    result.aggregate_spectrum["average_snr"] = result.average_snr
    result.aggregate_spectrum["snr_std"] = std(all_snrs)
    result.aggregate_spectrum["num_peaks"] = length(all_peak_freqs)

    result.aggregate_modulation = Dict{String,Any}(
        "modulation_counts" => mod_counts,
        "total_classified" => sum(values(mod_counts)),
    )
end

function save_aggregate_results(config::BatchConfig, result::BatchResult)
    aggregate_results(result)

    output = Dict{String,Any}(
        "total_files" => result.total_files,
        "processed" => result.processed,
        "failed" => result.failed,
        "average_snr" => result.average_snr,
        "total_duration_seconds" => result.total_duration_seconds,
        "processing_time_seconds" => result.end_time - result.start_time,
        "modulation_counts" => get(result.aggregate_modulation, "modulation_counts", Dict()),
        "error_count" => length(result.error_messages),
    )

    agg_path = joinpath(config.output_dir, "aggregate_results.arrow")
    arrow_io.write_results(agg_path, output)

    csv_path = joinpath(config.output_dir, "batch_summary.csv")
    open(csv_path, "w") do io
        write(io, "file,processed,snr,processing_time_ms,modulation\n")
        for (i, r) in enumerate(result.results)
            fname = basename(config.input_files[i])
            mod_type = get(r.modulation_result, "detected_scheme", "unknown")
            write(io, "$fname,true,$(r.snr_estimate),$(r.processing_time_ms),$mod_type\n")
        end
    end
end

function scan_file(filepath::String) -> BatchFileInfo
    size_bytes = stat(filepath).size
    return BatchFileInfo(filepath, splitext(filepath)[2], size_bytes, 0.0, 0.0, 0.0)
end

end
