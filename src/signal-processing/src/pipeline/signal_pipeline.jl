module signal_pipeline

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

export run_processing_pipeline, PipelineConfig, ProcessingStage,
       PipelineResult, configure_pipeline

abstract type ProcessingStage end

struct IQCorrectionStage <: ProcessingStage
    dc_offset_removal::Bool
    iq_imbalance_correction::Bool
    phase_correction::Bool
end

struct FilterStage <: ProcessingStage
    enabled::Bool
    filter_type::Symbol
    cutoff_freqs::Vector{Float64}
    filter_order::Int
end

struct DownconvertStage <: ProcessingStage
    enabled::Bool
    target_freq::Float64
    sample_rate::Float64
end

struct DemodulateStage <: ProcessingStage
    enabled::Bool
    modulation_scheme::String
    symbol_rate::Float64
end

struct AnalyzeStage <: ProcessingStage
    compute_spectrum::Bool
    compute_spectrogram::Bool
    compute_modulation::Bool
    compute_snr::Bool
    find_peaks::Bool
end

struct OutputStage <: ProcessingStage
    format::String
    include_raw::Bool
    file_path::String
end

@enum PipelineErrorCode begin
    SUCCESS
    INVALID_INPUT
    DECIMATION_ERROR
    FILTER_ERROR
    DEMODULATION_ERROR
    ANALYSIS_ERROR
    OUTPUT_ERROR
    TIMEOUT
end

mutable struct PipelineConfig
    input_format::String
    sample_rate::Float64
    center_freq::Float64
    stages::Vector{ProcessingStage}
    decimation_factor::Int
    enable_debug::Bool
    timeout_ms::Int
end

function PipelineConfig(;
    input_format::String="cf32",
    sample_rate::Float64=2.5e6,
    center_freq::Float64=2.4e9,
    decimation_factor::Int=1,
    enable_debug::Bool=false,
    timeout_ms::Int=60000,
)
    config = PipelineConfig(input_format, sample_rate, center_freq,
                           ProcessingStage[], decimation_factor,
                           enable_debug, timeout_ms)
    push!(config.stages, IQCorrectionStage(true, true, false))
    push!(config.stages, FilterStage(true, :bandpass, [1000.0, 500000.0], 64))
    push!(config.stages, AnalyzeStage(true, true, true, true, true))
    push!(config.stages, OutputStage("arrow", false, ""))
    return config
end

mutable struct PipelineResult
    success::Bool
    error_code::PipelineErrorCode
    error_message::String
    spectrum::Dict{String,Any}
    spectrogram::Dict{String,Any}
    modulation_result::Dict{String,Any}
    snr_estimate::Float64
    peak_frequencies::Vector{Float64}
    peak_amplitudes::Vector{Float64}
    processing_time_ms::Float64
    iq_corrected::Vector{Complex{Float32}}
    metadata::Dict{String,Any}
    timing::Dict{String,Float64}
end

function PipelineResult()
    return PipelineResult(
        false, SUCCESS, "",
        Dict{String,Any}(), Dict{String,Any}(),
        Dict{String,Any}(), 0.0,
        Float64[], Float64[],
        0.0, Complex{Float32}[],
        Dict{String,Any}(), Dict{String,Float64}(),
    )
end

function configure_pipeline(; kwargs...) -> PipelineConfig
    config = PipelineConfig()
    for (key, value) in kwargs
        if key == :input_format
            config.input_format = value
        elseif key == :sample_rate
            config.sample_rate = value
        elseif key == :center_freq
            config.center_freq = value
        elseif key == :decimation_factor
            config.decimation_factor = value
        elseif key == :enable_debug
            config.enable_debug = value
        elseif key == :stages
            config.stages = value
        end
    end
    return config
end

function run_processing_pipeline(
    samples::Vector{Complex{T}},
    config::PipelineConfig,
) -> PipelineResult where {T<:Number}
    result = PipelineResult()
    start_time = time()
    timings = Dict{String,Float64}()
    current_signal = Complex{Float32}.(samples)

    if isempty(samples)
        result.error_code = INVALID_INPUT
        result.error_message = "Empty input signal"
        return result
    end

    for stage in config.stages
        stage_start = time()

        if stage isa IQCorrectionStage
            current_signal = run_iq_correction(current_signal, stage)

        elseif stage isa FilterStage && stage.enabled
            current_signal = run_filter_stage(current_signal, config.sample_rate, stage)

        elseif stage isa DownconvertStage && stage.enabled
            current_signal = run_downconversion(current_signal, config.sample_rate, stage)

        elseif stage isa DemodulateStage && stage.enabled
            result.modulation_result = run_demodulation(current_signal, config.sample_rate, stage)

        elseif stage isa AnalyzeStage
            result = run_analysis(current_signal, config.sample_rate, stage, result)
            if stage.compute_snr
                result.snr_estimate = estimate_signal_snr(current_signal)
            end

        elseif stage isa OutputStage
            if !isempty(stage.file_path)
                save_pipeline_output(stage.file_path, result, stage)
            end
        end

        timings[string(typeof(stage))] = (time() - stage_start) * 1000
    end

    result.iq_corrected = current_signal
    result.success = true
    result.error_code = SUCCESS
    result.processing_time_ms = (time() - start_time) * 1000
    result.timing = timings
    result.metadata["input_length"] = length(samples)
    result.metadata["sample_rate"] = config.sample_rate
    result.metadata["center_freq"] = config.center_freq

    return result
end

function run_iq_correction(
    signal::Vector{Complex{Float32}},
    stage::IQCorrectionStage,
) -> Vector{Complex{Float32}}
    corrected = copy(signal)

    if stage.dc_offset_removal
        dc = mean(corrected)
        corrected .-= dc
    end

    if stage.iq_imbalance_correction
        i_power = mean(real(corrected).^2)
        q_power = mean(imag(corrected).^2)
        iq_product = mean(real(corrected) .* imag(corrected))

        if i_power > 0 && q_power > 0
            gain_imbalance = sqrt(q_power / i_power)
            phase_imbalance = -asin(iq_product / sqrt(i_power * q_power))

            corrected = real(corrected) .+
                        im * (real(corrected) * sin(phase_imbalance) +
                              imag(corrected) * cos(phase_imbalance) / gain_imbalance)
        end
    end

    return corrected
end

function run_filter_stage(
    signal::Vector{Complex{Float32}},
    fs::Float64,
    stage::FilterStage,
) -> Vector{Complex{Float32}}
    if length(stage.cutoff_freqs) < 2
        return signal
    end

    lo = stage.cutoff_freqs[1]
    hi = stage.cutoff_freqs[2]

    if lo <= 0
        filtered = filters.lowpass_filter(real(signal), hi, fs, order=stage.filter_order)
        filtered_q = filters.lowpass_filter(imag(signal), hi, fs, order=stage.filter_order)
    else
        filtered = filters.bandpass_filter(real(signal), lo, hi, fs, order=stage.filter_order)
        filtered_q = filters.bandpass_filter(imag(signal), lo, hi, fs, order=stage.filter_order)
    end

    min_len = min(length(filtered), length(filtered_q))
    return Complex{Float32}.(filtered[1:min_len], filtered_q[1:min_len])
end

function run_downconversion(
    signal::Vector{Complex{Float32}},
    fs::Float64,
    stage::DownconvertStage,
) -> Vector{Complex{Float32}}
    n = length(signal)
    t = (0:n-1) / fs
    lo = exp.(-2π * im * stage.target_freq .* t)
    return signal .* Complex{Float32}.(lo)
end

function run_demodulation(
    signal::Vector{Complex{Float32}},
    fs::Float64,
    stage::DemodulateStage,
) -> Dict{String,Any}
    result = Dict{String,Any}()
    result["scheme"] = stage.modulation_scheme
    result["symbol_rate"] = stage.symbol_rate

    if stage.modulation_scheme == "qpsk"
        symbols = modulation.demodulate_psk(real(signal), 0.0, fs, symbol_rate=stage.symbol_rate, order=4)
        result["symbols"] = symbols
        result["bits_per_symbol"] = 2
    elseif stage.modulation_scheme == "bpsk"
        symbols = modulation.demodulate_psk(real(signal), 0.0, fs, symbol_rate=stage.symbol_rate, order=2)
        result["symbols"] = symbols
        result["bits_per_symbol"] = 1
    elseif stage.modulation_scheme == "qam16"
        symbols = modulation.demodulate_qam(signal, 0.0, fs, symbol_rate=stage.symbol_rate, order=16)
        result["symbols"] = symbols
        result["bits_per_symbol"] = 4
    elseif stage.modulation_scheme == "qam64"
        symbols = modulation.demodulate_qam(signal, 0.0, fs, symbol_rate=stage.symbol_rate, order=64)
        result["symbols"] = symbols
        result["bits_per_symbol"] = 6
    end

    return result
end

function run_analysis(
    signal::Vector{Complex{Float32}},
    fs::Float64,
    stage::AnalyzeStage,
    result::PipelineResult,
) -> PipelineResult
    if stage.compute_spectrum
        freqs, spec = fft_analysis.compute_spectrum(signal, fs, nfft=4096)
        result.spectrum["frequencies"] = freqs
        result.spectrum["magnitude"] = spec
        result.spectrum["nfft"] = 4096

        if stage.find_peaks
            peaks = fft_analysis.find_peaks(spec, freqs, min_height=maximum(spec) * 0.1, n_peaks=10)
            result.peak_frequencies = [p[1] for p in peaks]
            result.peak_amplitudes = [p[2] for p in peaks]
        end
    end

    if stage.compute_spectrogram
        freqs, specgram = fft_analysis.compute_spectrogram(signal, fs, nfft=1024, noverlap=512)
        result.spectrogram["frequencies"] = freqs
        result.spectrogram["times"] = collect(0:size(specgram, 2)-1) * (1024 - 512) / fs
        result.spectrogram["spectrogram"] = specgram
    end

    if stage.compute_modulation
        scheme, scores = modulation.classify_modulation(signal, fs)
        result.modulation_result["detected_scheme"] = scheme
        result.modulation_result["scores"] = scores
    end

    return result
end

function estimate_signal_snr(signal::Vector{Complex{Float32}}) -> Float64
    n = length(signal)
    if n < 100
        return 0.0
    end
    signal_power = mean(abs2.(signal))
    noise_power = estimate_noise_power(signal)
    if noise_power <= 0
        return 100.0
    end
    return 10 * log10(signal_power / noise_power)
end

function estimate_noise_power(signal::Vector{Complex{Float32}}) -> Float64
    n = length(signal)
    nfft = nextpow(2, n)
    spectrum = abs2.(fft(signal, nfft))
    sorted_power = sort(spectrum)
    noise_floor = mean(sorted_power[1:max(1, nfft ÷ 4)])
    return noise_floor
end

function save_pipeline_output(path::String, result::PipelineResult, stage::OutputStage)
    output_data = Dict{String,Any}()
    if stage.include_raw
        output_data["iq_corrected"] = result.iq_corrected
    end
    output_data["spectrum_frequencies"] = get(result.spectrum, "frequencies", Float64[])
    output_data["spectrum_magnitude"] = get(result.spectrum, "magnitude", Float64[])
    output_data["snr"] = result.snr_estimate
    output_data["peak_frequencies"] = result.peak_frequencies
    output_data["peak_amplitudes"] = result.peak_amplitudes
    output_data["processing_time_ms"] = result.processing_time_ms

    if endswith(path, ".arrow")
        arrow_io.write_results(path, output_data)
    elseif endswith(path, ".csv")
        writedlm(path, hcat(output_data["spectrum_frequencies"], output_data["spectrum_magnitude"]), ',')
    end
end

end
