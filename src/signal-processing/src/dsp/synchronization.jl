module synchronization

using DSP
using LinearAlgebra
using Statistics

export frame_sync, preamble_detection, correlate_preamble,
       schmidl_cox_sync, detect_frame_start, symbol_timing_estimation,
       fine_frequency_sync, coarse_frequency_sync, guard_interval_detection,
       find_preamble_peak, threshold_detection

struct SyncResult
    frame_start::Int
    frequency_offset::Float64
    timing_offset::Float64
    correlation_peak::Float64
    confidence::Float64
    preamble_found::Bool
end

function preamble_detection(signal::Vector{Complex{T}}, preamble::Vector{Complex{T}}; threshold::Float64=0.5) where {T<:Number}
    n = length(signal)
    m = length(preamble)
    correlation = correlate_preamble(signal, preamble)
    peak_val = maximum(abs.(correlation))
    peak_idx = argmax(abs.(correlation))

    confidence = peak_val / (m * maximum(abs.(preamble))^2 + eps())
    found = confidence >= threshold

    return SyncResult(
        peak_idx, 0.0, 0.0,
        peak_val, confidence, found
    )
end

function correlate_preamble(signal::Vector{T}, preamble::Vector{T}) where {T<:Number}
    n = length(signal)
    m = length(preamble)
    result = zeros(Complex{Float64}, n - m + 1)

    for i in 1:(n - m + 1)
        segment = signal[i:i+m-1]
        result[i] = sum(segment .* conj(preamble))
    end

    return result
end

function frame_sync(signal::Vector{Complex{T}}, sync_word::Vector{Int}; threshold::Float64=0.5) where {T<:Number}
    n = length(signal)
    m = length(sync_word)
    sync_complex = Complex{Float64}.(sync_word)
    correlation = zeros(Float64, n - m + 1)

    for i in 1:(n - m + 1)
        seg = signal[i:i+m-1]
        corr = 0.0
        for j in 1:m
            corr += real(seg[j] * conj(sync_complex[j]))
        end
        correlation[i] = abs(corr)
    end

    peak_val = maximum(correlation)
    peak_idx = argmax(correlation)
    confidence = peak_val / (m + eps())
    found = confidence >= threshold

    return SyncResult(peak_idx, 0.0, 0.0, peak_val, confidence, found)
end

function schmidl_cox_sync(signal::Vector{Complex{T}}, fs::Float64) where {T<:Number}
    n = length(signal)
    L = 64
    P = zeros(Complex{Float64}, n - L)
    R = zeros(Float64, n - L)

    for d in 1:(n - L)
        P[d] = sum(signal[d:d+L-1] .* conj(signal[d+L:d+2L-1]))
        R[d] = sum(abs2.(signal[d+L:d+2L-1]))
    end

    M = abs2.(P) ./ (R.^2 .+ eps())

    peak_idx = argmax(M)
    timing_metric = M[peak_idx]
    coarse_freq_offset = angle(P[peak_idx]) / (π * L)

    return SyncResult(
        peak_idx, coarse_freq_offset, 0.0,
        timing_metric, timing_metric, timing_metric > 0.5
    )
end

function detect_frame_start(signal::Vector{Complex{T}}, threshold::Float64=0.1) where {T<:Number}
    n = length(signal)
    power = abs2.(signal)
    window_size = 32
    moving_avg = DSP.filt(ones(window_size) / window_size, [1.0], power)

    frame_start = 1
    for i in window_size:n
        if moving_avg[i] > threshold * maximum(moving_avg)
            frame_start = i - window_size
            break
        end
    end

    return frame_start
end

function symbol_timing_estimation(signal::Vector{Complex{T}}, fs::Float64, symbol_rate::Float64) where {T<:Number}
    samples_per_symbol = round(Int, fs / symbol_rate)
    n = length(signal)

    square_mag = abs2.(signal)
    nfft = nextpow(2, n)
    spectrum = abs2.(fft(square_mag, nfft))
    freqs = abs.(fftfreq(nfft, fs))

    positive_idx = 2:(nfft ÷ 2)
    clock_component = spectrum[positive_idx]
    clock_freqs = freqs[positive_idx]

    peak_idx = argmax(clock_component)
    estimated_rate = clock_freqs[peak_idx]

    timing_offset = 0.0
    if estimated_rate > 0
        timing_offset = mod(angle(spectrum[peak_idx]) / (2π * estimated_rate / fs), 1.0)
    end

    return estimated_rate, timing_offset
end

function fine_frequency_sync(signal::Vector{Complex{T}}, pilot_symbols::Vector{Complex{T}}) where {T<:Number}
    n = min(length(signal), length(pilot_symbols))
    phase_diff = angle.(signal[1:n] .* conj(pilot_symbols[1:n]))
    freq_offset = mean(diff(phase_diff)) / (2π)
    return freq_offset
end

function coarse_frequency_sync(signal::Vector{Complex{T}}, fs::Float64) where {T<:Number}
    n = length(signal)
    nfft = nextpow(2, n)
    spectrum = abs2.(fft(signal, nfft))
    freqs = fftfreq(nfft, fs)

    positive_idx = 1:(nfft ÷ 2)
    peak_idx = argmax(spectrum[positive_idx])
    freq_offset = abs(freqs[positive_idx[peak_idx]])

    return freq_offset
end

function guard_interval_detection(signal::Vector{Complex{T}}, cp_length::Int, fft_size::Int) where {T<:Number}
    n = length(signal)
    num_symbols = n ÷ (fft_size + cp_length)
    correlation = 0.0

    for sym_idx in 1:num_symbols
        start_idx = (sym_idx - 1) * (fft_size + cp_length) + 1
        cp_end = start_idx + cp_length - 1
        sym_end = start_idx + fft_size + cp_length - 1

        if cp_end <= n && sym_end <= n
            cp_part = signal[start_idx:cp_end]
            sym_part = signal[sym_end-cp_length+1:sym_end]
            correlation += abs(sum(cp_part .* conj(sym_part)))
        end
    end

    return correlation / (num_symbols * cp_length + eps())
end

function find_preamble_peak(correlation::Vector{Float64}; min_distance::Int=64)
    n = length(correlation)
    peaks = Int[]

    for i in 2:(n - 1)
        if correlation[i] > correlation[i-1] && correlation[i] > correlation[i+1]
            push!(peaks, i)
        end
    end

    filtered = Int[]
    for p in peaks
        if isempty(filtered) || p - filtered[end] >= min_distance
            push!(filtered, p)
        elseif correlation[p] > correlation[filtered[end]]
            filtered[end] = p
        end
    end

    return filtered
end

function threshold_detection(correlation::Vector{Float64}, threshold::Float64)
    n = length(correlation)
    peaks = Int[]

    i = 1
    while i <= n
        if correlation[i] > threshold
            peak_start = i
            while i <= n && correlation[i] > threshold
                i += 1
            end
            peak_end = i - 1
            _, max_idx = findmax(correlation[peak_start:peak_end])
            push!(peaks, peak_start + max_idx - 1)
        else
            i += 1
        end
    end

    return peaks
end

end
