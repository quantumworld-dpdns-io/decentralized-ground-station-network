module fft_analysis

using FFTW
using LinearAlgebra
using Statistics

export compute_spectrum, compute_spectrogram, compute_power_spectral_density,
       compute_waterfall, compute_cyclic_autocorrelation,
       compute_harmonic_products, find_peaks, compute_snr,
       compute_phase_noise, window_function, stft,
       compute_cepstrum, compute_mfcc, compute_spectral_kurtosis,
       goertzel_algorithm, zoom_fft, compute_cross_spectrum,
       compute_coherence, compute_autocorrelation

abstract type WindowFunction end

struct HammingWindow <: WindowFunction end
struct HannWindow <: WindowFunction end
struct BlackmanWindow <: WindowFunction end
struct KaiserWindow <: WindowFunction
    beta::Float64
end
struct GaussianWindow <: WindowFunction
    sigma::Float64
end
struct FlatTopWindow <: WindowFunction end

function window_function(n::Int, window_type::WindowFunction=HannWindow())::Vector{Float64}
    if window_type isa HammingWindow
        return 0.54 .- 0.46 .* cos.(2π * (0:n-1) / (n - 1))
    elseif window_type isa HannWindow
        return 0.5 .* (1 .- cos.(2π * (0:n-1) / (n - 1)))
    elseif window_type isa BlackmanWindow
        a0, a1, a2 = 0.42, 0.5, 0.08
        return a0 .- a1 .* cos.(2π * (0:n-1) / (n - 1)) .+ a2 .* cos.(4π * (0:n-1) / (n - 1))
    elseif window_type isa KaiserWindow
        beta = window_type.beta
        I0(x) = sum((x / 2)^(2k) / factorial(k)^2 for k in 0:20)
        w = [I0(beta * sqrt(1 - ((2i / (n - 1)) - 1)^2)) / I0(beta) for i in 0:n-1]
        return w
    elseif window_type isa GaussianWindow
        sigma = window_type.sigma
        return exp.(-0.5 * (((0:n-1) .- (n-1)/2) / (sigma * (n-1)/2)) .^ 2)
    elseif window_type isa FlatTopWindow
        a0, a1, a2, a3, a4 = 0.21557895, -0.41663158, 0.277263158, -0.083578947, 0.006947368
        idx = 0:n-1
        return a0 .+ a1 .* cos.(2π * idx / (n - 1)) .+ a2 .* cos.(4π * idx / (n - 1)) .+
               a3 .* cos.(6π * idx / (n - 1)) .+ a4 .* cos.(8π * idx / (n - 1))
    end
end

function compute_spectrum(
    signal::Vector{T},
    fs::Float64=1.0;
    nfft::Int=1024,
    window_type::WindowFunction=HannWindow(),
    detrend::Bool=true,
    scaling::Symbol=:magnitude,
) where {T<:Number}
    n = length(signal)
    nfft_actual = nfft > 0 ? nfft : nextpow(2, n)

    data = detrend ? detrend_signal(signal) : copy(signal)
    win = window_function(n, window_type)
    windowed = data .* win

    spectrum = fft(windowed, nfft_actual)
    freqs = fftfreq(nfft_actual, fs)

    if scaling == :magnitude
        spectrum_mag = abs.(spectrum) ./ sum(win)
    elseif scaling == :power
        spectrum_mag = abs2.(spectrum) ./ (sum(win)^2)
    elseif scaling == :psd
        spectrum_mag = abs2.(spectrum) ./ (fs * sum(win.^2))
    else
        spectrum_mag = abs.(spectrum)
    end

    positive_idx = 1:(nfft_actual ÷ 2 + 1)
    return freqs[positive_idx], spectrum_mag[positive_idx]
end

function compute_power_spectral_density(
    signal::Vector{T},
    fs::Float64=1.0;
    nfft::Int=1024,
    window_type::WindowFunction=HannWindow(),
    noverlap::Int=512,
) where {T<:Number}
    freqs, psd_avg = compute_spectrogram(signal, fs, nfft=nfft, window_type=window_type, noverlap=noverlap, scaling=:psd)
    psd_mean = mean(psd_avg, dims=2)[:]
    return freqs, psd_mean
end

function compute_spectrogram(
    signal::Vector{T},
    fs::Float64=1.0;
    nfft::Int=1024,
    window_type::WindowFunction=HannWindow(),
    noverlap::Int=512,
    scaling::Symbol=:psd,
) where {T<:Number}
    n = length(signal)
    step = nfft - noverlap
    nframes = (n - noverlap) ÷ step

    win = window_function(nfft, window_type)
    freqs = fftfreq(nfft, fs)[1:(nfft ÷ 2 + 1)]
    spectrogram = zeros(Float64, length(freqs), nframes)

    for i in 0:(nframes - 1)
        start_idx = i * step + 1
        end_idx = start_idx + nfft - 1
        if end_idx <= n
            segment = signal[start_idx:end_idx] .* win
            spec = fft(segment, nfft)

            if scaling == :psd
                power = abs2.(spec[1:(nfft ÷ 2 + 1)]) ./ (fs * sum(win.^2))
            elseif scaling == :power
                power = abs2.(spec[1:(nfft ÷ 2 + 1)]) ./ (sum(win)^2)
            else
                power = abs.(spec[1:(nfft ÷ 2 + 1)])
            end

            spectrogram[:, i + 1] = power
        end
    end

    return freqs, spectrogram
end

function compute_waterfall(
    signal::Vector{T},
    fs::Float64;
    nfft::Int=1024,
    nperseg::Int=1024,
    noverlap::Int=0,
) where {T<:Number}
    return compute_spectrogram(signal, fs, nfft=nfft, noverlap=noverlap)
end

function compute_cyclic_autocorrelation(
    signal::Vector{T},
    fs::Float64;
    alpha::Float64=0.0,
    max_lag::Int=256,
    nfft::Int=1024,
) where {T<:Number}
    n = length(signal)
    lag_range = -max_lag:max_lag
    result = zeros(Complex{Float64}, length(lag_range))

    shift = exp.(-2π * im * alpha * (0:n-1) / fs)

    for (i, lag) in enumerate(lag_range)
        lag_abs = abs(lag)
        if lag_abs < n
            if lag >= 0
                x1 = signal[1:n-lag_abs]
                x2 = signal[1+lag_abs:end]
            else
                x1 = signal[1+lag_abs:end]
                x2 = signal[1:n-lag_abs]
            end
            result[i] = mean(x1 .* conj(x2) .* shift[1:length(x1)])
        end
    end

    return lag_range, result
end

function compute_harmonic_products(
    spectrum::Vector{Float64},
    n_harmonics::Int=3,
) -> Vector{Float64}
    n = length(spectrum)
    product_spectrum = copy(spectrum)

    for h in 2:n_harmonics
        downsampled = spectrum[1:h:end]
        min_len = min(length(product_spectrum), length(downsampled))
        product_spectrum[1:min_len] .*= downsampled[1:min_len]
    end

    return product_spectrum
end

function find_peaks(
    spectrum::Vector{Float64},
    freqs::Vector{Float64};
    min_height::Float64=0.0,
    min_distance::Int=1,
    n_peaks::Int=-1,
) -> Vector{Tuple{Float64, Float64, Int}}
    n = length(spectrum)
    peaks = Tuple{Float64, Float64, Int}[]

    for i in 2:(n - 1)
        if spectrum[i] > spectrum[i-1] && spectrum[i] > spectrum[i+1]
            if spectrum[i] >= min_height
                push!(peaks, (freqs[i], spectrum[i], i))
            end
        end
    end

    sort!(peaks, by=x -> x[2], rev=true)

    if min_distance > 1 && !isempty(peaks)
        filtered = [(peaks[1]...)]
        for p in peaks[2:end]
            too_close = false
            for fp in filtered
                if abs(p[3] - fp[3]) < min_distance
                    too_close = true
                    break
                end
            end
            if !too_close
                push!(filtered, p)
            end
        end
        peaks = filtered
    end

    if n_peaks > 0
        peaks = peaks[1:min(n_peaks, length(peaks))]
    end

    return peaks
end

function compute_snr(
    signal_power::Float64,
    noise_power::Float64,
) -> Float64
    if noise_power <= 0
        return Inf
    end
    return 10 * log10(signal_power / noise_power)
end

function estimate_snr_from_spectrum(
    spectrum::Vector{Float64},
    signal_band::UnitRange{Int},
    noise_band::UnitRange{Int},
) -> Float64
    signal_power = mean(spectrum[signal_band])
    noise_power = mean(spectrum[noise_band])
    return compute_snr(signal_power, noise_power)
end

function compute_phase_noise(
    signal::Vector{T},
    fs::Float64;
    carrier_freq::Float64=0.0,
    offset_range::UnitRange{Int}=1:100,
) where {T<:Number}
    phase = unwrap(angle.(signal))
    n = length(phase)
    dt = 1 / fs

    phase_deviation = phase .- mean(phase)
    nfft = nextpow(2, n)
    phase_spectrum = abs2.(fft(phase_deviation, nfft))
    freqs = fftfreq(nfft, fs)[1:(nfft ÷ 2 + 1)]

    positive_idx = 1:(nfft ÷ 2 + 1)
    phase_noise = 10 * log10.(phase_spectrum[positive_idx] / fs)

    offset_min = max(1, offset_range.start)
    offset_max = min(length(phase_noise), offset_range.stop)

    return freqs[offset_min:offset_max], phase_noise[offset_min:offset_max]
end

function stft(
    signal::Vector{T},
    fs::Float64;
    nfft::Int=1024,
    window_length::Int=256,
    noverlap::Int=128,
    window_type::WindowFunction=HannWindow(),
) where {T<:Number}
    step = window_length - noverlap
    nframes = (length(signal) - window_length) ÷ step + 1

    win = window_function(window_length, window_type)
    freqs = fftfreq(nfft, fs)[1:(nfft ÷ 2 + 1)]
    times = [0.0]
    stft_matrix = zeros(Float64, length(freqs), nframes)

    for i in 0:(nframes - 1)
        start_idx = i * step + 1
        end_idx = start_idx + window_length - 1
        if end_idx <= length(signal)
            segment = signal[start_idx:end_idx] .* win
            padded = zeros(Complex{Float64}, nfft)
            padded[1:window_length] = segment
            spec = fft(padded)
            stft_matrix[:, i + 1] = abs.(spec[1:(nfft ÷ 2 + 1)])
            push!(times, i * step / fs)
        end
    end

    return times, freqs, stft_matrix
end

function compute_cepstrum(signal::Vector{T}) where {T<:Number}
    spectrum = fft(signal)
    log_spectrum = log.(abs.(spectrum) .+ eps())
    cepstrum = real(ifft(log_spectrum))
    return cepstrum
end

function compute_mfcc(signal::Vector{T}, fs::Float64; num_coeffs::Int=13, nfft::Int=256) where {T<:Number}
    n = length(signal)
    spectrum = abs.(fft(signal, nfft))
    freqs = linspace(0, fs / 2, nfft ÷ 2 + 1)

    num_filters = 26
    mel_low = 0
    mel_high = 2595 * log10(1 + fs / 1400)
    mel_points = range(mel_low, mel_high, length=num_filters + 2)
    hz_points = 700 * (10 .^(mel_points / 2595) .- 1)
    bin_points = round.(Int, hz_points / fs * nfft) .+ 1
    bin_points = min.(bin_points, nfft ÷ 2 + 1)

    filterbank = zeros(num_filters, nfft ÷ 2 + 1)
    for m in 2:(num_filters + 1)
        l = bin_points[m - 1]
        c = bin_points[m]
        r = bin_points[m + 1]
        for k in l:c
            filterbank[m - 1, k] = (k - l) / (c - l)
        end
        for k in c:r
            filterbank[m - 1, k] = (r - k) / (r - c)
        end
    end

    power_spec = abs2.(spectrum[1:(nfft ÷ 2 + 1)])
    mel_energy = filterbank * power_spec
    log_mel_energy = log.(mel_energy .+ eps())

    mfccs = zeros(num_coeffs)
    for i in 1:num_coeffs
        for j in 1:num_filters
            mfccs[i] += log_mel_energy[j] * cos(i * (j - 0.5) * π / num_filters)
        end
    end

    return mfccs
end

function compute_spectral_kurtosis(signal::Vector{T}, fs::Float64; nfft::Int=256, noverlap::Int=128) where {T<:Number}
    n = length(signal)
    step = nfft - noverlap
    nframes = (n - noverlap) ÷ step
    win = window_function(nfft, HannWindow())

    s2 = zeros(Float64, nfft ÷ 2 + 1)
    s4 = zeros(Float64, nfft ÷ 2 + 1)
    count = zeros(Int, nfft ÷ 2 + 1)

    for i in 0:(nframes - 1)
        start_idx = i * step + 1
        end_idx = start_idx + nfft - 1
        if end_idx <= n
            segment = signal[start_idx:end_idx] .* win
            spec = abs.(fft(segment, nfft))[1:(nfft ÷ 2 + 1)]
            s2 .+= spec.^2
            s4 .+= spec.^4
            count .+= 1
        end
    end

    s2 ./= count
    s4 ./= count
    kurtosis = (s4 ./ (s2.^2 .+ eps())) .- 2
    return fftfreq(nfft, fs)[1:(nfft ÷ 2 + 1)], kurtosis
end

function goertzel_algorithm(signal::Vector{T}, target_freq::Float64, fs::Float64) where {T<:Number}
    n = length(signal)
    k = round(Int, target_freq * n / fs)
    omega = 2π * k / n
    coeff = 2 * cos(omega)
    s0 = 0.0
    s1 = 0.0
    s2 = 0.0

    for i in 1:n
        s0 = real(signal[i]) + coeff * s1 - s2
        s2 = s1
        s1 = s0
    end

    power = s2^2 + s1^2 - coeff * s1 * s2
    return power
end

function zoom_fft(signal::Vector{T}, fs::Float64, f_center::Float64, f_span::Float64; nfft::Int=1024) where {T<:Number}
    n = length(signal)
    t = (0:n-1) / fs
    shifted = signal .* exp.(-2π * im * f_center .* t)
    decimation_factor = max(1, floor(Int, fs / f_span))
    decimated = shifted[1:decimation_factor:end]
    spec = abs.(fft(decimated, nfft))
    freqs = range(f_center - f_span / 2, f_center + f_span / 2, length=nfft ÷ 2 + 1)
    return freqs, spec[1:(nfft ÷ 2 + 1)]
end

function compute_cross_spectrum(x::Vector{T}, y::Vector{T}, fs::Float64; nfft::Int=1024) where {T<:Number}
    X = fft(x, nfft)
    Y = fft(y, nfft)
    cross = X .* conj(Y)
    freqs = fftfreq(nfft, fs)[1:(nfft ÷ 2 + 1)]
    return freqs, cross[1:(nfft ÷ 2 + 1)]
end

function compute_coherence(x::Vector{T}, y::Vector{T}, fs::Float64; nfft::Int=256, noverlap::Int=128) where {T<:Number}
    n = length(x)
    step = nfft - noverlap
    nframes = (n - noverlap) ÷ step
    win = window_function(nfft, HannWindow())

    pxy_sum = zeros(Complex{Float64}, nfft ÷ 2 + 1)
    pxx_sum = zeros(Float64, nfft ÷ 2 + 1)
    pyy_sum = zeros(Float64, nfft ÷ 2 + 1)

    for i in 0:(nframes - 1)
        start_idx = i * step + 1
        end_idx = start_idx + nfft - 1
        if end_idx <= n
            seg_x = x[start_idx:end_idx] .* win
            seg_y = y[start_idx:end_idx] .* win
            X = fft(seg_x, nfft)[1:(nfft ÷ 2 + 1)]
            Y = fft(seg_y, nfft)[1:(nfft ÷ 2 + 1)]
            pxy_sum .+= X .* conj(Y)
            pxx_sum .+= abs2.(X)
            pyy_sum .+= abs2.(Y)
        end
    end

    coherence = abs2.(pxy_sum) ./ ((pxx_sum .* pyy_sum) .+ eps())
    freqs = fftfreq(nfft, fs)[1:(nfft ÷ 2 + 1)]
    return freqs, coherence
end

function compute_autocorrelation(signal::Vector{T}; max_lag::Int=-1) where {T<:Number}
    n = length(signal)
    if max_lag <= 0 || max_lag >= n
        max_lag = n - 1
    end
    result = zeros(Float64, max_lag + 1)
    mean_signal = mean(signal)
    var_signal = var(signal)
    for lag in 0:max_lag
        sum_val = 0.0
        count = 0
        for i in 1:(n - lag)
            sum_val += (signal[i] - mean_signal) * (signal[i + lag] - mean_signal)
            count += 1
        end
        result[lag + 1] = sum_val / (count * var_signal + eps())
    end
    return 0:max_lag, result
end

function detrend_signal(signal::Vector{T}) where {T<:Number}
    n = length(signal)
    x = 1.0:n
    coeffs = [sum(real(signal) .* x) / sum(x.^2), sum(imag(signal) .* x) / sum(x.^2)]
    trend = complex.(coeffs[1] * x, coeffs[2] * x)
    return signal - trend
end

function linspace(start::Float64, stop::Float64, n::Int)
    return range(start, stop, length=n)
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
