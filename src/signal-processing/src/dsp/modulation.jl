module modulation

using DSP
using Statistics
using LinearAlgebra

export classify_modulation, demodulate_ask, demodulate_fsk, demodulate_psk,
       demodulate_qam, demodulate_apsk, modulate_ask, modulate_fsk,
       modulate_psk, modulate_qam, calculate_evm, calculate_mer,
       estimate_symbol_rate, estimate_carrier_frequency, timing_recovery,
       modulate_apsk, modulate_gmsk, modulate_ofdm, modulate_oqpsk,
       demodulate_gmsk, demodulate_ofdm, demodulate_oqpsk,
       generate_ofdm_symbol, add_cyclic_prefix, remove_cyclic_prefix,
       psk_constellation, qam_constellation, apsk_constellation

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
struct GMSK <: ModulationScheme
    bt::Float64
end
struct OQPSK <: ModulationScheme end
struct OFDM <: ModulationScheme
    num_subcarriers::Int
    cyclic_prefix_length::Int
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

function modulate_apsk(symbols::Vector{Int}, carrier_freq::Float64, fs::Float64;
                       amplitude::Float64=1.0, symbol_rate::Float64=1000.0,
                       order::Int=16, ring_ratios::Vector{Float64}=[1.0, 2.0])
    Ts = 1 / symbol_rate
    t = 0:(1/fs):(length(symbols) * Ts - 1/fs)
    signal = zeros(Float64, length(t))

    constellation = apsk_constellation(order, ring_ratios)

    for (i, sym) in enumerate(symbols)
        sym_idx = mod1(sym + 1, length(constellation))
        sym_val = constellation[sym_idx]
        start_idx = round(Int, (i-1) * Ts * fs) + 1
        end_idx = min(round(Int, i * Ts * fs), length(t))
        idx_range = start_idx:end_idx
        I = real(sym_val)
        Q = imag(sym_val)
        signal[idx_range] .= amplitude * (I .* cos.(2π * carrier_freq * t[idx_range]) .-
                                           Q .* sin.(2π * carrier_freq * t[idx_range]))
    end

    return signal
end

function modulate_gmsk(bits::Vector{Int}, carrier_freq::Float64, fs::Float64;
                       symbol_rate::Float64=1000.0, bt::Float64=0.5)
    Ts = 1 / symbol_rate
    n = length(bits)
    t = 0:(1/fs):(n * Ts - 1/fs)
    samples_per_symbol = round(Int, Ts * fs)
    total_samples = n * samples_per_symbol

    nrz = zeros(Float64, total_samples)
    for i in 1:n
        idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        if maximum(idx) <= total_samples
            nrz[idx] .= 2 * bits[i] - 1
        end
    end

    bt_norm = bt / Ts
    sigma = sqrt(log(2)) / (2π * bt_norm)
    t_gauss = -3 * Ts:1/fs:3 * Ts
    gauss_filter = exp.(-t_gauss.^2 / (2 * sigma^2))
    gauss_filter = gauss_filter / sum(gauss_filter)

    filtered = DSP.filt(gauss_filter, [1.0], nrz)
    phase = 2π * cumsum(filtered) / samples_per_symbol
    phase = mod.(phase, 2π)

    signal = cos.(2π * carrier_freq * t .+ phase)
    return signal
end

function modulate_oqpsk(bits::Vector{Int}, carrier_freq::Float64, fs::Float64;
                        amplitude::Float64=1.0, symbol_rate::Float64=1000.0)
    Ts = 1 / symbol_rate
    samples_per_symbol = round(Int, Ts * fs)
    n_symbols = length(bits) ÷ 2
    total_samples = n_symbols * samples_per_symbol
    t = (0:total_samples-1) / fs

    I_bits = bits[1:2:end]
    Q_bits = bits[2:2:end]

    I_signal = zeros(Float64, total_samples)
    Q_signal = zeros(Float64, total_samples)

    for i in 1:min(n_symbols, length(I_bits), length(Q_bits))
        i_idx = ((i-1) * samples_per_symbol + 1):(i * samples_per_symbol)
        q_start = round(Int, (i - 1) * samples_per_symbol + samples_per_symbol / 2) + 1
        q_end = min(q_start + samples_per_symbol - 1, total_samples)

        if maximum(i_idx) <= total_samples
            I_signal[i_idx] .= (2 * I_bits[i] - 1) * amplitude
        end
        if q_start <= total_samples && q_end <= total_samples
            Q_signal[q_start:q_end] .= (2 * Q_bits[i] - 1) * amplitude
        end
    end

    signal = I_signal .* cos.(2π * carrier_freq * t) .- Q_signal .* sin.(2π * carrier_freq * t)
    return signal
end

function generate_ofdm_symbol(data::Vector{Complex{Float64}}, num_subcarriers::Int)
    if length(data) > num_subcarriers
        data = data[1:num_subcarriers]
    elseif length(data) < num_subcarriers
        data = vcat(data, zeros(Complex{Float64}, num_subcarriers - length(data)))
    end
    symbol = ifft(data) * sqrt(num_subcarriers)
    return symbol
end

function add_cyclic_prefix(symbol::Vector{Complex{Float64}}, cp_length::Int)
    return vcat(symbol[end-cp_length+1:end], symbol)
end

function remove_cyclic_prefix(symbol::Vector{Complex{Float64}}, cp_length::Int)
    return symbol[cp_length+1:end]
end

function modulate_ofdm(data_symbols::Vector{Complex{Float64}}, fs::Float64;
                       num_subcarriers::Int=64, cyclic_prefix_length::Int=16,
                       num_symbols::Int=1)
    samples_per_symbol = num_subcarriers + cyclic_prefix_length
    total_samples = samples_per_symbol * num_symbols
    signal = zeros(Float64, total_samples)

    for sym_idx in 1:num_symbols
        start_idx = (sym_idx - 1) * num_subcarriers + 1
        end_idx = min(start_idx + num_subcarriers - 1, length(data_symbols))
        sym_data = data_symbols[start_idx:end_idx]
        ofdm_sym = generate_ofdm_symbol(sym_data, num_subcarriers)
        cp_sym = add_cyclic_prefix(ofdm_sym, cyclic_prefix_length)
        sig_start = (sym_idx - 1) * samples_per_symbol + 1
        sig_end = sig_start + length(cp_sym) - 1
        if sig_end <= total_samples
            signal[sig_start:sig_end] = real(cp_sym)
        end
    end

    return signal
end

function psk_constellation(order::Int) -> Vector{Complex{Float64}}
    return [exp(im * 2π * k / order) for k in 0:order-1]
end

function qam_constellation(order::Int) -> Vector{Complex{Float64}}
    sqrt_order = Int(sqrt(order))
    if sqrt_order^2 != order
        error("QAM order must be a perfect square")
    end
    constellation = Complex{Float64}[]
    for i in 0:sqrt_order-1
        for j in 0:sqrt_order-1
            push!(constellation, (2i - sqrt_order + 1) + im * (2j - sqrt_order + 1))
        end
    end
    return constellation
end

function apsk_constellation(order::Int, ring_ratios::Vector{Float64}) -> Vector{Complex{Float64}}
    num_rings = length(ring_ratios)
    points_per_ring = order ÷ num_rings
    constellation = Complex{Float64}[]
    for (ring, ratio) in enumerate(ring_ratios)
        for p in 0:points_per_ring-1
            phase = 2π * p / points_per_ring + π / points_per_ring * (ring - 1)
            push!(constellation, ratio * exp(im * phase))
        end
    end
    return constellation
end

end
