module doppler

using FFTW
using LinearAlgebra
using Statistics

export estimate_doppler_shift, correct_doppler_shift,
       doppler_rate_estimation, cross_ambiguity_function,
       estimate_doppler_from_preamble, doppler_compensation_pll,
       doppler_fft_method, coarse_fine_doppler_estimation

struct DopplerEstimate
    frequency_offset::Float64
    doppler_rate::Float64
    confidence::Float64
    method::String
end

function estimate_doppler_shift(signal::Vector{Complex{T}}, fs::Float64; carrier_freq::Float64=0.0, method::Symbol=:fft) where {T<:Number}
    if method == :fft
        return doppler_fft_method(signal, fs, carrier_freq=carrier_freq)
    elseif method == :phase
        return estimate_doppler_from_phase(signal, fs)
    else
        return doppler_fft_method(signal, fs, carrier_freq=carrier_freq)
    end
end

function doppler_fft_method(signal::Vector{Complex{T}}, fs::Float64; carrier_freq::Float64=0.0) where {T<:Number}
    n = length(signal)
    nfft = nextpow(2, n)

    window = hann(n)
    windowed = signal .* window

    spectrum = abs2.(fft(windowed, nfft))
    freqs = fftfreq(nfft, fs)

    positive_idx = 1:(nfft ÷ 2)
    positive_spectrum = spectrum[positive_idx]
    positive_freqs = abs.(freqs[positive_idx])

    peak_idx = argmax(positive_spectrum)
    estimated_offset = positive_freqs[peak_idx]

    power_ratio = positive_spectrum[peak_idx] / sum(positive_spectrum)

    return DopplerEstimate(estimated_offset, 0.0, power_ratio, "fft")
end

function estimate_doppler_from_phase(signal::Vector{Complex{T}}, fs::Float64) where {T<:Number}
    n = length(signal)
    phase = angle.(signal)
    unwrapped_phase = unwrap(phase)
    dt = 1 / fs
    t = (0:n-1) * dt

    coeffs = hcat(ones(n), t) \ unwrapped_phase
    freq_offset = coeffs[2] / (2π)
    phase_noise = unwrapped_phase - (coeffs[1] .+ coeffs[2] .* t)
    confidence = 1.0 / (std(phase_noise) + eps())

    return DopplerEstimate(freq_offset, 0.0, confidence, "phase")
end

function correct_doppler_shift(signal::Vector{Complex{T}}, fs::Float64, doppler_est::DopplerEstimate) where {T<:Number}
    n = length(signal)
    t = (0:n-1) / fs
    correction = exp.(-2π * im * doppler_est.frequency_offset .* t)
    return signal .* correction
end

function doppler_rate_estimation(signal::Vector{Complex{T}}, fs::Float64; segment_duration::Float64=0.1) where {T<:Number}
    n = length(signal)
    segment_samples = round(Int, segment_duration * fs)
    num_segments = n ÷ segment_samples
    offsets = Float64[]

    for i in 1:num_segments
        start_idx = (i - 1) * segment_samples + 1
        end_idx = min(start_idx + segment_samples - 1, n)
        segment = signal[start_idx:end_idx]
        est = doppler_fft_method(segment, fs)
        push!(offsets, est.frequency_offset)
    end

    if length(offsets) >= 2
        t_segments = (0:length(offsets)-1) * segment_duration
        coeffs = hcat(ones(length(t_segments)), t_segments) \ offsets
        doppler_rate = coeffs[2]
    else
        doppler_rate = 0.0
    end

    return offsets, doppler_rate
end

function cross_ambiguity_function(signal::Vector{Complex{T}}, reference::Vector{Complex{T}}, fs::Float64; max_doppler::Float64=1000.0) where {T<:Number}
    n = min(length(signal), length(reference))
    nfft = nextpow(2, 2 * n - 1)
    delay_range = -n+1:n-1
    doppler_range = range(-max_doppler, max_doppler, length=128)

    ambiguity = zeros(Float64, length(delay_range), length(doppler_range))

    ref_fft = fft(reference[1:n], nfft)

    for (d_idx, doppler) in enumerate(doppler_range)
        t = (0:n-1) / fs
        shifted = signal[1:n] .* exp.(-2π * im * doppler .* t)
        sig_fft = fft(shifted, nfft)
        cross = ifft(sig_fft .* conj(ref_fft))
        ambiguity[:, d_idx] = abs.(cross[1:length(delay_range)])
    end

    return delay_range, doppler_range, ambiguity
end

function estimate_doppler_from_preamble(signal::Vector{Complex{T}}, preamble::Vector{Complex{T}}, fs::Float64) where {T<:Number}
    n_preamble = length(preamble)
    n_signal = length(signal)
    correlations = zeros(Complex{Float64}, n_signal - n_preamble + 1)
    doppler_trials = range(-500.0, 500.0, length=21)
    best_doppler = 0.0
    best_corr = 0.0

    for doppler in doppler_trials
        t = (0:n_preamble-1) / fs
        compensated = signal[1:n_preamble] .* exp.(-2π * im * doppler .* t)
        corr = abs(sum(compensated .* conj(preamble)))
        if corr > best_corr
            best_corr = corr
            best_doppler = doppler
        end
    end

    confidence = best_corr / (n_preamble * maximum(abs.(preamble))^2 + eps())
    return DopplerEstimate(best_doppler, 0.0, confidence, "preamble")
end

function doppler_compensation_pll(signal::Vector{Complex{T}}, fs::Float64; loop_bw::Float64=0.01) where {T<:Number}
    n = length(signal)
    phase = 0.0
    freq = 0.0
    alpha = 4 * loop_bw / (1 + 2 * loop_bw)
    beta = 4 * loop_bw^2 / (1 + 2 * loop_bw)
    corrected = zeros(Complex{Float64}, n)

    for i in 1:n
        nco = exp(-im * phase)
        corrected[i] = signal[i] * nco
        error = imag(corrected[i]) * real(corrected[i])
        phase += alpha * error + freq
        freq += beta * error
    end

    return corrected, freq
end

function coarse_fine_doppler_estimation(signal::Vector{Complex{T}}, fs::Float64; coarse_resolution::Float64=100.0, fine_range::Float64=50.0) where {T<:Number}
    coarse_est = doppler_fft_method(signal, fs)
    coarse_offset = coarse_est.frequency_offset

    fine_offsets = range(coarse_offset - fine_range, coarse_offset + fine_range, step=coarse_resolution / 10)
    best_offset = coarse_offset
    best_power = 0.0

    n = length(signal)
    nfft = nextpow(2, n)

    for offset in fine_offsets
        t = (0:n-1) / fs
        corrected = signal .* exp.(-2π * im * offset .* t)
        power = sum(abs2.(fft(corrected, nfft))[1:(nfft ÷ 2)])
        if power > best_power
            best_power = power
            best_offset = offset
        end
    end

    return DopplerEstimate(best_offset, 0.0, coarse_est.confidence, "coarse_fine")
end

function hann(n::Int) -> Vector{Float64}
    return 0.5 * (1 .- cos.(2π * (0:n-1) / (n - 1)))
end

function unwrap(phase::Vector{T}) where {T<:Number}
    unwrapped = copy(phase)
    for i in 2:length(unwrapped)
        diff = unwrapped[i] - unwrapped[i-1]
        while diff > π
            diff -= 2π
        end
        while diff < -π
            diff += 2π
        end
        unwrapped[i] = unwrapped[i-1] + diff
    end
    return unwrapped
end

end
