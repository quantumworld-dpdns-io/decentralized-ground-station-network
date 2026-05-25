module DGSN_SignalProcessing

using DSP
using FFTW
using Optim
using Statistics
using DelimitedFiles
using LinearAlgebra
using Random

export dsp, io, pipeline, ml

include("dsp/filters.jl")
include("dsp/fft.jl")
include("dsp/modulation.jl")
include("dsp/demodulation.jl")
include("dsp/doppler.jl")
include("dsp/synchronization.jl")
include("io/sdr.jl")
include("io/arrow.jl")
include("io/file_formats.jl")
include("pipeline/signal_pipeline.jl")
include("pipeline/streaming.jl")
include("pipeline/batch.jl")
include("ml/classifier.jl")
include("ml/anomaly.jl")
include("ml/fingerprinting.jl")

const VERSION = v"0.2.0"
const MODULE_NAME = "DGSN_SignalProcessing"

function __init__()
    FFTW.set_num_threads(Threads.nthreads())
end

function process_file(input_path::String, output_path::String; config::Dict{String,Any}=Dict{String,Any}())
    ext = splitext(input_path)[2]
    if ext in (".iq", ".bin", ".cfile", ".sigmf-data")
        samples = file_formats.read_signal_file(input_path)
    else
        samples = io.read_iq_samples(input_path)
    end
    result = pipeline.run_processing_pipeline(samples, config)
    if endswith(output_path, ".arrow")
        io.write_results(output_path, result)
    else
        io.write_results(output_path, result)
    end
    return result
end

function process_stream(samples::Vector{Complex{Float32}}; config::Dict{String,Any}=Dict{String,Any}())
    return pipeline.run_processing_pipeline(samples, config)
end

function batch_process(input_files::Vector{String}, output_dir::String; config::Dict{String,Any}=Dict{String,Any}())
    return pipeline.run_batch_processing(input_files, output_dir, config)
end

end
