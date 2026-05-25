module modulation

using DSP
using Statistics
using LinearAlgebra

export classify_modulation, demodulate_ask, demodulate_fsk, demodulate_psk,
       demodulate_qam, demodulate_apsk, modulate_ask, modulate_fsk,
       modulate_psk, modulate_qam, calculate_evm, calculate_mer,
       estimate_symbol_rate, estimate_carrier_frequency, timing_recovery

abstract type ModulationScheme end

struct ASK <: ModulationScheme
    order::Int
end
struct FSK <: ModulationScheme
    order::Int
    freq_separation::Float64
end
struct PSK <: ModulationScheme
    order::Int
end
struct QAM <: ModulationScheme
    order::Int
end
struct APSK <: ModulationScheme
    order::Int
    ring_ratios::Vector{Float64}
end

function modulate_ask(symbols::Vector{Int}, carrier_freq::Float64, fs::Float64;
                      amplitude::Float64=1.0, symbol_rate::Float64=1000.0)
    Ts = 1 / symbol_rate
    t = 0:(1/fs):(length(symbols) * Ts - 1/fs)
    signal = zeros(Float64, length(t))

    for (i, sym) in enumerate(symbols)
        start_idx = round(Int, (i-1) * Ts * fs) + 1
        end_idx = min(round(Int, i * Ts * fs), length(t))
        idx_range = start_idx:end_idx
        signal[idx_range] .= amplitude * sym * cos.(2π * carrier_freq * t[idx_range])
    end

    return signal
end

function modulate_psk(symbols::Vector{Int}, carrier_freq::Float64, fs::Float64;
                      amplitude::Float64=1.0, symbol_rate::Float64=1000.0, order::Int=4)
    Ts = 1 / symbol_rate
    t = 0:(1/fs):(length(symbols) * Ts - 1/fs)
    signal = zeros(Float64, length(t))

    for (i, sym) in enumerate(symbols)
        phase = 2π * sym / order
        start_idx = round(Int, (i-1) * Ts * fs) + 1
        end_idx = min(round(Int, i * Ts * fs), length(t))
        idx_range = start_idx:end_idx
        signal[idx_range] .= amplitude * cos.(2π * carrier_freq * t[idx_range] .+ phase)
    end

    return signal
end

function modulate_fsk(symbols::Vector{Int}, carrier_freq::Float64, fs::Float64;
                      amplitude::Float64=1.0, symbol_rate::Float64=1000.0,
                      freq_deviation::Float64=500.0)
    Ts = 1 / symbol_rate
    t = 0:(1/fs):(length(symbols) * Ts - 1/fs)
    signal = zeros(Float64, length(t))

    for (i, sym) in enumerate(symbols)
        freq = carrier_freq + sym * freq_deviation
        start_idx = round(Int, (i-1) * Ts * fs) + 1
        end_idx = min(round(Int, i * Ts * fs), length(t))
        idx_range = start_idx:end_idx
        signal[idx_range] .= amplitude * cos.(2π * freq * t[idx_range])
    end

    return signal
end

function modulate_qam(symbols::Vector{T}, carrier_freq::Float64, fs::Float64;
                      amplitude::Float64=1.0, symbol_rate::Float64=1000.0) where {T<:Complex}
    Ts = 1 / symbol_rate
    t = 0:(1/fs):(length(symbols) * Ts - 1/fs)
    signal = zeros(Float64, length(t))

    for (i, sym) in enumerate(symbols)
        start_idx = round(Int, (i-1) * Ts * fs) + 1
        end_idx = min(round(Int, i * Ts * fs), length(t))
        idx_range = start_idx:end_idx
        I = real(sym)
        Q = imag(sym)
        signal[idx_range] .= amplitude * (I .* cos.(2π * carrier_freq * t[idx_range]) .-
                                           Q .* sin.(2π * carrier_freq * t[idx_range]))
    end

    return signal
end

function demodulate_ask(signal::Vector{T}, carrier_freq::Float64, fs::Float64;
                        symbol_rate::Float64=1000.0, order::Int=2) where {T<:Number}
    Ts = 1 / symbol_rate
    samples_per_symbol = round(Int, Ts * fs)
    t = (0:length(signal)-1) / fs

    carrier = cos.(2π * carrier_freq * t)
    mixed = signal .* carrier

    b, a = DSP.Butterworth(4, carrier_freq / fs)
    baseband = DSP.filt(b, a, mixed)

    num_symbols = length(signal) ÷ samples_per_symbol
    symbols = zeros(Int, num_symbols)
    levels = range(0, 1, length=order)

    for i in 1:num_symbols
        idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        if maximum(idx) <= length(baseband)
            energy = mean(abs.(baseband[idx]))
            _, nearest = findmin(abs.(energy .- levels))
            symbols[i] = nearest - 1
        end
    end

    return symbols
end

function demodulate_psk(signal::Vector{T}, carrier_freq::Float64, fs::Float64;
                        symbol_rate::Float64=1000.0, order::Int=4) where {T<:Number}
    Ts = 1 / symbol_rate
    samples_per_symbol = round(Int, Ts * fs)
    t = (0:length(signal)-1) / fs

    carrier_i = cos.(2π * carrier_freq * t)
    carrier_q = -sin.(2π * carrier_freq * t)
    i_component = signal .* carrier_i
    q_component = signal .* carrier_q

    b, a = DSP.Butterworth(4, carrier_freq / fs)
    i_baseband = DSP.filt(b, a, i_component)
    q_baseband = DSP.filt(b, a, q_component)

    num_symbols = length(signal) ÷ samples_per_symbol
    symbols = zeros(Int, num_symbols)
    phases = 2π * (0:order-1) / order

    for i in 1:num_symbols
        idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        if maximum(idx) <= length(i_baseband)
            I = mean(i_baseband[idx])
            Q = mean(q_baseband[idx])
            phase = atan(Q, I)
            phase_diff = mod.(phase .- phases .+ π, 2π) .- π
            _, nearest = findmin(abs.(phase_diff))
            symbols[i] = nearest - 1
        end
    end

    return symbols
end

function demodulate_fsk(signal::Vector{T}, carrier_freq::Float64, fs::Float64;
                        symbol_rate::Float64=1000.0, order::Int=2,
                        freq_deviation::Float64=500.0) where {T<:Number}
    Ts = 1 / symbol_rate
    samples_per_symbol = round(Int, Ts * fs)
    t = (0:length(signal)-1) / fs

    num_symbols = length(signal) ÷ samples_per_symbol
    symbols = zeros(Int, num_symbols)
    freqs = [carrier_freq + k * freq_deviation for k in 0:order-1]

    for i in 1:num_symbols
        idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        if maximum(idx) <= length(signal)
            segment = signal[idx]
            energies = [sum(abs.(segment .* cos.(2π * f * t[idx]))) for f in freqs]
            _, nearest = findmax(energies)
            symbols[i] = nearest - 1
        end
    end

    return symbols
end

function demodulate_qam(signal::Vector{T}, carrier_freq::Float64, fs::Float64;
                        symbol_rate::Float64=1000.0, order::Int=16) where {T<:Number}
    Ts = 1 / symbol_rate
    samples_per_symbol = round(Int, Ts * fs)
    t = (0:length(signal)-1) / fs

    carrier_i = cos.(2π * carrier_freq * t)
    carrier_q = -sin.(2π * carrier_freq * t)
    i_component = signal .* carrier_i
    q_component = signal .* carrier_q

    b, a = DSP.Butterworth(4, carrier_freq / fs)
    i_baseband = DSP.filt(b, a, i_component)
    q_baseband = DSP.filt(b, a, q_component)

    num_symbols = length(signal) ÷ samples_per_symbol
    symbols = zeros(Int, num_symbols)
    sqrt_order = Int(sqrt(order))
    constellation = [(2*i - sqrt_order + 1) + im*(2*j - sqrt_order + 1) for i in 0:sqrt_order-1, j in 0:sqrt_order-1]
    constellation_flat = constellation[:]

    for i in 1:num_symbols
        idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        if maximum(idx) <= length(i_baseband)
            I = mean(i_baseband[idx])
            Q = mean(q_baseband[idx])
            received = I + im*Q
            distances = abs.(received .- constellation_flat)
            _, nearest = findmin(distances)
            symbols[i] = nearest - 1
        end
    end

    return symbols
end

function demodulate_apsk(signal::Vector{T}, carrier_freq::Float64, fs::Float64;
                         symbol_rate::Float64=1000.0, order::Int=16,
                         ring_ratios::Vector{Float64}=[1.0, 2.0]) where {T<:Number}
    Ts = 1 / symbol_rate
    samples_per_symbol = round(Int, Ts * fs)
    t = (0:length(signal)-1) / fs

    carrier_i = cos.(2π * carrier_freq * t)
    carrier_q = -sin.(2π * carrier_freq * t)
    i_component = signal .* carrier_i
    q_component = signal .* carrier_q

    b, a = DSP.Butterworth(4, carrier_freq / fs)
    i_baseband = DSP.filt(b, a, i_component)
    q_baseband = DSP.filt(b, a, q_component)

    num_symbols = length(signal) ÷ samples_per_symbol
    symbols = zeros(Int, num_symbols)

    num_rings = length(ring_ratios)
    points_per_ring = order ÷ num_rings
    constellation = Complex{Float64}[]
    for (ring, ratio) in enumerate(ring_ratios)
        for p in 0:points_per_ring-1
            phase = 2π * p / points_per_ring + π / points_per_ring * (ring - 1)
            push!(constellation, ratio * exp(im * phase))
        end
    end

    for i in 1:num_symbols
        idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        if maximum(idx) <= length(i_baseband)
            I = mean(i_baseband[idx])
            Q = mean(q_baseband[idx])
            received = I + im*Q
            distances = abs.(received .- constellation)
            _, nearest = findmin(distances)
            symbols[i] = nearest - 1
        end
    end

    return symbols
end

function classify_modulation(signal::Vector{T}, fs::Float64) where {T<:Number}
    features = extract_modulation_features(signal, fs)
    score_ask = score_ask_features(features)
    score_fsk = score_fsk_features(features)
    score_psk = score_psk_features(features)
    score_qam = score_qam_features(features)

    scores = [
        ("ASK", score_ask),
        ("FSK", score_fsk),
        ("PSK", score_psk),
        ("QAM", score_qam),
    ]
    sort!(scores, by=x -> x[2], rev=true)

    return scores[1][1], scores
end

function extract_modulation_features(signal::Vector{T}, fs::Float64) where {T<:Number}
    n = length(signal)
    normalized = signal / (std(signal) + eps())
    instantaneous_amplitude = abs.(normalized)
    instantaneous_phase = angle.(normalized)
    instantaneous_frequency = diff(instantaneous_phase) * fs / (2π)

    gamma_max = maximum(instantaneous_amplitude) / (mean(instantaneous_amplitude) + eps())
    sigma_ap = std(instantaneous_phase[instantaneous_amplitude .> mean(instantaneous_amplitude)])
    sigma_dp = std(diff(instantaneous_phase)[instantaneous_amplitude[2:end] .> mean(instantaneous_amplitude)])
    sigma_aa = std(instantaneous_amplitude)
    sigma_af = std(instantaneous_frequency)

    spectrum = abs.(fft(signal))
    spectral_symmetry = abs(sum(spectrum[1:n÷2]) - sum(spectrum[n÷2+1:end])) / (sum(spectrum) + eps())

    return Dict(
        "gamma_max" => gamma_max,
        "sigma_ap" => sigma_ap,
        "sigma_dp" => sigma_dp,
        "sigma_aa" => sigma_aa,
        "sigma_af" => sigma_af,
        "spectral_symmetry" => spectral_symmetry,
        "kurtosis" => kurtosis(real(signal)),
        "skewness" => skewness(real(signal)),
    )
end

function score_ask_features(features::Dict)::Float64
    score = 0.0
    if features["gamma_max"] > 2.0
        score += 1.0
    end
    if features["sigma_aa"] > 0.3
        score += 1.0
    end
    if features["sigma_ap"] < 0.5
        score += 1.0
    end
    return score
end

function score_fsk_features(features::Dict)::Float64
    score = 0.0
    if features["sigma_af"] > 0.3
        score += 1.0
    end
    if features["sigma_ap"] > 0.5
        score += 1.0
    end
    if abs(features["kurtosis"]) < 1.0
        score += 1.0
    end
    return score
end

function score_psk_features(features::Dict)::Float64
    score = 0.0
    if features["gamma_max"] < 1.5
        score += 1.0
    end
    if features["sigma_ap"] > 0.3
        score += 1.0
    end
    if features["sigma_dp"] > 0.5
        score += 1.0
    end
    if features["spectral_symmetry"] < 0.1
        score += 1.0
    end
    return score
end

function score_qam_features(features::Dict)::Float64
    score = 0.0
    if features["gamma_max"] > 1.5 && features["gamma_max"] < 3.0
        score += 1.0
    end
    if features["sigma_aa"] > 0.2 && features["sigma_aa"] < 0.6
        score += 1.0
    end
    if abs(features["kurtosis"]) < 1.5
        score += 1.0
    end
    if features["spectral_symmetry"] < 0.15
        score += 1.0
    end
    return score
end

function calculate_evm(received::Vector{T}, ideal::Vector{T}) where {T<:Number}
    error_power = sum(abs2.(received - ideal))
    ref_power = sum(abs2.(ideal))
    evm_rms = sqrt(error_power / (ref_power + eps())) * 100
    return evm_rms
end

function calculate_mer(received::Vector{T}, ideal::Vector{T}) where {T<:Number}
    signal_power = sum(abs2.(ideal))
    noise_power = sum(abs2.(received - ideal))
    mer_db = 10 * log10(signal_power / (noise_power + eps()))
    return mer_db
end

function estimate_symbol_rate(signal::Vector{T}, fs::Float64) where {T<:Number}
    n = length(signal)
    nfft = nextpow(2, n)
    spectrum = abs2.(fft(signal, nfft))

    square_signal = abs2.(signal)
    square_spectrum = abs2.(fft(square_signal, nfft))
    freqs = abs.(fftfreq(nfft, fs))

    positive_idx = 2:(nfft ÷ 2)
    clock_component = square_spectrum[positive_idx]
    clock_freqs = freqs[positive_idx]

    peak_idx = argmax(clock_component)
    estimated_symbol_rate = clock_freqs[peak_idx]

    return estimated_symbol_rate
end

function estimate_carrier_frequency(signal::Vector{T}, fs::Float64) where {T<:Number}
    n = length(signal)
    nfft = nextpow(2, n)
    spectrum = abs2.(fft(signal, nfft))
    freqs = fftfreq(nfft, fs)

    positive_idx = 1:(nfft ÷ 2)
    magnitude = spectrum[positive_idx]
    freq_range = freqs[positive_idx]

    peak_idx = argmax(magnitude)
    estimated_freq = abs(freq_range[peak_idx])

    return estimated_freq
end

function timing_recovery(signal::Vector{T}, fs::Float64, symbol_rate::Float64;
                         method::Symbol=:gardner) where {T<:Number}
    Tsym = fs / symbol_rate
    n = length(signal)
    num_symbols = floor(Int, n / Tsym)
    recovered = zeros(Complex{Float64}, num_symbols)

    if method == :gardner
        for i in 1:num_symbols
            idx = round(Int, (i - 1) * Tsym) + 1
            if idx <= n
                recovered[i] = signal[idx]
            end
        end
    elseif method == :early_late
        early_offset = 0.25
        for i in 1:num_symbols
            idx = round(Int, (i - 1) * Tsym) + 1
            early_idx = max(1, round(Int, idx - early_offset * Tsym))
            late_idx = min(n, round(Int, idx + early_offset * Tsym))
            if early_idx <= n && late_idx <= n
                early = signal[early_idx]
                late = signal[late_idx]
                recovered[i] = (early + late) / 2
            end
        end
    end

    return recovered
end

function kurtosis(x::Vector{T}) where {T<:Number}
    n = length(x)
    mu = mean(x)
    m2 = sum((x .- mu).^2) / n
    m4 = sum((x .- mu).^4) / n
    return m4 / (m2^2 + eps()) - 3
end

function skewness(x::Vector{T}) where {T<:Number}
    n = length(x)
    mu = mean(x)
    m2 = sum((x .- mu).^2) / n
    m3 = sum((x .- mu).^3) / n
    return m3 / (m2^1.5 + eps())
end

end
