using Test
using DGSN_SignalProcessing

@testset "DGSN Signal Processing Test Suite" begin
    include("test_dsp.jl")
    include("test_pipeline.jl")
end
