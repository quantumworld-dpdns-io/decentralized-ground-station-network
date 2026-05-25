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
include("io/sdr.jl")
include("io/arrow.jl")
include("pipeline/signal_pipeline.jl")
include("ml/classifier.jl")

const VERSION = v"0.1.0"
const MODULE_NAME = "DGSN_SignalProcessing"

function __init__()
    FFTW.set_num_threads(Threads.nthreads())
end

function process_file(input_path::String, output_path::String; config::Dict{String,Any}=Dict{String,Any}())
    samples = io.read_iq_samples(input_path)
    result = pipeline.run_processing_pipeline(samples, config)
    io.write_results(output_path, result)
    return result
end

function process_stream(samples::Vector{Complex{Float32}}; config::Dict{String,Any}=Dict{String,Any}())
    return pipeline.run_processing_pipeline(samples, config)
end

end
