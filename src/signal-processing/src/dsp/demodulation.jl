module demodulation

using DSP
using LinearAlgebra
using Statistics

export carrier_recovery_pll, timing_recovery_mueller, matched_filter_demod,
       symbol_slicer, differential_decode, frequency_offset_correction,
       phase_recovery_costas, demodulate_bpsk, demodulate_qpsk,
       demodulate_8psk, demodulate_16qam, demodulate_64qam,
       soft_slicer, llr_calculation, hard_decision

struct PLLState
    phase::Float64
    freq::Float64
    damping::Float64
    bandwidth::Float64
    alpha::Float64
    beta::Float64
end

function PLLState(;phase::Float64=0.0, freq::Float64=0.0, damping::Float64=0.707, bandwidth::Float64=0.01)
    theta_n = bandwidth / (damping + 0.25 / damping)
    alpha = 4 * damping * theta_n / (1 + 2 * damping * theta_n + theta_n^2)
    beta = 4 * theta_n^2 / (1 + 2 * damping * theta_n + theta_n^2)
    return PLLState(phase, freq, damping, bandwidth, alpha, beta)
end

function carrier_recovery_pll(signal::Vector{Complex{T}}, fs::Float64; carrier_freq::Float64=0.0, loop_bw::Float64=0.01) where {T<:Number}
    n = length(signal)
    pll = PLLState(bandwidth=loop_bw)
    corrected = zeros(Complex{Float64}, n)
    t = (0:n-1) / fs

    for i in 1:n
        nco = exp(-im * (2π * t[i] * carrier_freq + pll.phase))
        corrected[i] = signal[i] * nco
        phase_error = imag(corrected[i]) * real(corrected[i])
        pll.phase += pll.alpha * phase_error
        pll.freq += pll.beta * phase_error
    end

    return corrected, pll
end

function phase_recovery_costas(signal::Vector{Complex{T}}; order::Int=4) where {T<:Number}
    n = length(signal)
    pll = PLLState(bandwidth=0.01)
    corrected = zeros(Complex{Float64}, n)

    for i in 1:n
        phase_est = pll.phase
        corrected[i] = signal[i] * exp(-im * phase_est)
        if order == 2
            error = real(corrected[i]) * imag(corrected[i])
        elseif order == 4
            error = real(corrected[i])^2 * imag(corrected[i])^2
            error *= sign(real(corrected[i]) * imag(corrected[i]))
        else
            error = real(corrected[i]) * imag(corrected[i]) * (real(corrected[i])^2 - imag(corrected[i])^2)
        end
        pll.phase += pll.alpha * error
        pll.freq += pll.beta * error
    end

    return corrected
end

function timing_recovery_mueller(signal::Vector{Complex{T}}, samples_per_symbol::Int; method::Symbol=:mueller) where {T<:Number}
    n = length(signal)
    num_symbols = n ÷ samples_per_symbol
    recovered = zeros(Complex{Float64}, num_symbols)
    timing_error = 0.0
    timing_phase = 0.0
    mu = 0.01

    for i in 1:num_symbols
        idx = round(Int, i * samples_per_symbol + timing_phase)
        idx = clamp(idx, 1, n)
        recovered[i] = signal[idx]

        if i > 1
            if method == :mueller
                timing_error = real(recovered[i-1]) * real(recovered[i]) + imag(recovered[i-1]) * imag(recovered[i])
            elseif method == :zero_crossing
                timing_error = real(recovered[i]) * (real(recovered[i]) - real(recovered[i-1]))
            elseif method == :gardner
                mid_idx = round(Int, (i - 0.5) * samples_per_symbol + timing_phase)
                mid_idx = clamp(mid_idx, 1, n)
                mid_sample = signal[mid_idx]
                timing_error = real(recovered[i-1] - recovered[i]) * real(mid_sample) +
                               imag(recovered[i-1] - recovered[i]) * imag(mid_sample)
            end
            timing_phase += mu * timing_error
        end
    end

    return recovered
end

function matched_filter_demod(signal::Vector{Complex{T}}, pulse_shape::Vector{Float64}) where {T<:Number}
    n = length(signal)
    m = length(pulse_shape)
    result = zeros(Complex{Float64}, n + m - 1)

    for i in 1:n
        for j in 1:m
            if i + j - 1 <= length(result)
                result[i + j - 1] += signal[i] * pulse_shape[j]
            end
        end
    end

    return result
end

function frequency_offset_correction(signal::Vector{Complex{T}}, fs::Float64; freq_offset::Float64=0.0) where {T<:Number}
    n = length(signal)
    t = (0:n-1) / fs
    return signal .* exp.(-2π * im * freq_offset .* t)
end

function symbol_slicer(symbols::Vector{Complex{T}}, constellation::Vector{Complex{Float64}}) where {T<:Number}
    n = length(symbols)
    decisions = zeros(Int, n)

    for i in 1:n
        distances = abs.(symbols[i] .- constellation)
        _, decisions[i] = findmin(distances)
    end

    return decisions .- 1
end

function hard_decision(symbol::Complex{T}) where {T<:Number}
    return real(symbol) > 0 ? 1 : 0
end

function soft_slicer(symbol::Complex{T}, constellation::Vector{Complex{Float64}}) -> Vector{Float64}
    n = length(constellation)
    llrs = zeros(Float64, Int(log2(n)))

    distances = abs.(symbol .- constellation)
    for bit_idx in 1:length(llrs)
        min_dist_0 = Inf
        min_dist_1 = Inf
        for (i, d) in enumerate(distances)
            bit_val = (i - 1) >> (bit_idx - 1) & 1
            if bit_val == 0
                min_dist_0 = min(min_dist_0, d)
            else
                min_dist_1 = min(min_dist_1, d)
            end
        end
        llrs[bit_idx] = min_dist_0 - min_dist_1
    end

    return llrs
end

function llr_calculation(symbols::Vector{Complex{T}}, noise_variance::Float64, constellation::Vector{Complex{Float64}}) where {T<:Number}
    n = length(symbols)
    num_bits = Int(log2(length(constellation)))
    llrs = zeros(Float64, n, num_bits)

    for i in 1:n
        for bit_idx in 1:num_bits
            num_0 = 0.0
            den_0 = 0.0
            num_1 = 0.0
            den_1 = 0.0
            for (j, c) in enumerate(constellation)
                dist = abs2(symbols[i] - c)
                prob = exp(-dist / (2 * noise_variance))
                bit_val = (j - 1) >> (bit_idx - 1) & 1
                if bit_val == 0
                    num_0 += prob
                    den_0 += 1.0
                else
                    num_1 += prob
                    den_1 += 1.0
                end
            end
            llrs[i, bit_idx] = log((num_0 / (den_0 + eps())) / (num_1 / (den_1 + eps())))
        end
    end

    return llrs
end

function differential_decode(symbols::Vector{Int}, order::Int) -> Vector{Int}
    n = length(symbols)
    decoded = zeros(Int, n)
    prev = 0

    for i in 1:n
        decoded[i] = mod(symbols[i] - prev, order)
        prev = symbols[i]
    end

    return decoded
end

function demodulate_bpsk(signal::Vector{Complex{T}}, fs::Float64; symbol_rate::Float64=1000.0, carrier_freq::Float64=0.0) where {T<:Number}
    corrected, _ = carrier_recovery_pll(signal, fs, carrier_freq=carrier_freq)
    samples_per_symbol = round(Int, fs / symbol_rate)
    recovered = timing_recovery_mueller(corrected, samples_per_symbol)
    bits = [real(s) > 0 ? 1 : 0 for s in recovered]
    return bits
end

function demodulate_qpsk(signal::Vector{Complex{T}}, fs::Float64; symbol_rate::Float64=1000.0, carrier_freq::Float64=0.0) where {T<:Number}
    corrected = phase_recovery_costas(signal, order=4)
    samples_per_symbol = round(Int, fs / symbol_rate)
    recovered = timing_recovery_mueller(corrected, samples_per_symbol)
    constellation = [1+im, -1+im, -1-im, 1-im] ./ sqrt(2)
    sym_indices = symbol_slicer(recovered, constellation)
    bits = zeros(Int, 2 * length(sym_indices))
    for i in 1:length(sym_indices)
        bits[2i-1] = (sym_indices[i] >> 1) & 1
        bits[2i] = sym_indices[i] & 1
    end
    return bits
end

function demodulate_8psk(signal::Vector{Complex{T}}, fs::Float64; symbol_rate::Float64=1000.0, carrier_freq::Float64=0.0) where {T<:Number}
    corrected = phase_recovery_costas(signal, order=8)
    samples_per_symbol = round(Int, fs / symbol_rate)
    recovered = timing_recovery_mueller(corrected, samples_per_symbol)
    constellation = [exp(im * π / 4 * k) for k in 0:7]
    sym_indices = symbol_slicer(recovered, constellation)
    bits = zeros(Int, 3 * length(sym_indices))
    for i in 1:length(sym_indices)
        bits[3i-2] = (sym_indices[i] >> 2) & 1
        bits[3i-1] = (sym_indices[i] >> 1) & 1
        bits[3i] = sym_indices[i] & 1
    end
    return bits
end

function demodulate_16qam(signal::Vector{Complex{T}}, fs::Float64; symbol_rate::Float64=1000.0, carrier_freq::Float64=0.0) where {T<:Number}
    corrected, _ = carrier_recovery_pll(signal, fs, carrier_freq=carrier_freq)
    samples_per_symbol = round(Int, fs / symbol_rate)
    recovered = timing_recovery_mueller(corrected, samples_per_symbol)
    constellation = [(2i-3) + im*(2j-3) for i in 0:3, j in 0:3][:]
    constellation ./= sqrt(mean(abs2.(constellation)))
    return symbol_slicer(recovered, constellation)
end

function demodulate_64qam(signal::Vector{Complex{T}}, fs::Float64; symbol_rate::Float64=1000.0, carrier_freq::Float64=0.0) where {T<:Number}
    corrected, _ = carrier_recovery_pll(signal, fs, carrier_freq=carrier_freq)
    samples_per_symbol = round(Int, fs / symbol_rate)
    recovered = timing_recovery_mueller(corrected, samples_per_symbol)
    constellation = [(2i-7) + im*(2j-7) for i in 0:7, j in 0:7][:]
    constellation ./= sqrt(mean(abs2.(constellation)))
    return symbol_slicer(recovered, constellation)
end

end
