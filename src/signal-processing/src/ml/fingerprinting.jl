module fingerprinting

using Statistics
using LinearAlgebra
using Random

export extract_fingerprint, compare_fingerprints,
       RFDatabase, RFProfile, add_to_database,
       identify_transmitter, FingerprintFeature,
       compute_histogram_features, compute_spectral_fingerprint,
       compute_cyclostationary_fingerprint, compute_wavelet_fingerprint

struct FingerprintFeature
    name::String
    value::Float64
    weight::Float64
end

struct RFProfile
    transmitter_id::String
    fingerprints::Vector{FingerprintFeature}
    feature_vector::Vector{Float64}
    confidence::Float64
    timestamp::Float64
    num_samples::Int
end

function RFProfile(transmitter_id::String, fingerprints::Vector{FingerprintFeature})
    fv = [f.value for f in fingerprints]
    return RFProfile(transmitter_id, fingerprints, fv, 0.0, time(), 1)
end

mutable struct RFDatabase
    profiles::Vector{RFProfile}
    num_features::Int
    distance_threshold::Float64
    feature_weights::Vector{Float64}
end

function RFDatabase(;num_features::Int=32, distance_threshold::Float64=0.1)
    return RFDatabase(RFProfile[], num_features, distance_threshold, ones(num_features) / num_features)
end

function extract_fingerprint(signal::Vector{Complex{T}}; num_features::Int=32) where {T<:Number}
    features = FingerprintFeature[]

    spectral = compute_spectral_fingerprint(signal)
    for (name, val) in spectral
        push!(features, FingerprintFeature(name, val, 1.0))
    end

    histogram = compute_histogram_features(signal)
    for (name, val) in histogram
        push!(features, FingerprintFeature(name, val, 1.0))
    end

    cyclostationary = compute_cyclostationary_fingerprint(signal)
    for (name, val) in cyclostationary
        push!(features, FingerprintFeature(name, val, 0.8))
    end

    wavelet = compute_wavelet_fingerprint(signal)
    for (name, val) in wavelet
        push!(features, FingerprintFeature(name, val, 0.6))
    end

    if length(features) > num_features
        features = features[1:num_features]
    end

    return features
end

function compute_spectral_fingerprint(signal::Vector{Complex{T}}) where {T<:Number}
    n = length(signal)
    nfft = nextpow(2, n)
    spectrum = abs.(fft(signal, nfft))
    spec_power = spectrum.^2
    half = nfft ÷ 2

    features = Dict{String,Float64}()

    if half > 1
        freqs = 1:half
        spectral_centroid = sum(freqs .* spec_power[1:half]) / (sum(spec_power[1:half]) + eps())
        features["spectral_centroid"] = spectral_centroid / half

        spectral_spread = sum((freqs .- spectral_centroid).^2 .* spec_power[1:half]) / (sum(spec_power[1:half]) + eps())
        features["spectral_spread"] = spectral_spread / half

        spectral_skew = sum((freqs .- spectral_centroid).^3 .* spec_power[1:half]) /
                        ((sum(spec_power[1:half]) + eps()) * spectral_spread^1.5 + eps())
        features["spectral_skewness"] = spectral_skew

        spectral_kurt = sum((freqs .- spectral_centroid).^4 .* spec_power[1:half]) /
                        ((sum(spec_power[1:half]) + eps()) * spectral_spread^2 + eps()) - 3
        features["spectral_kurtosis"] = spectral_kurt
    end

    features["peak_to_avg"] = maximum(spec_power) / (mean(spec_power) + eps())
    features["spectral_flatness"] = exp(mean(log.(spec_power .+ eps()))) / (mean(spec_power) + eps())
    features["bandwidth_90"] = sum(spec_power .> 0.1 * maximum(spec_power)) / nfft

    return features
end

function compute_histogram_features(signal::Vector{Complex{T}}; num_bins::Int=20) where {T<:Number}
    real_part = real(signal)
    imag_part = imag(signal)
    amplitude = abs.(signal)
    phase = angle.(signal)

    features = Dict{String,Float64}()

    amp_hist = fit_histogram(amplitude, num_bins)
    phase_hist = fit_histogram(phase, num_bins)

    features["amplitude_hist_entropy"] = histogram_entropy(amp_hist)
    features["phase_hist_entropy"] = histogram_entropy(phase_hist)
    features["amplitude_mean"] = mean(amplitude)
    features["amplitude_var"] = var(amplitude)
    features["amplitude_skew"] = skewness(amplitude)
    features["amplitude_kurt"] = kurtosis(amplitude)
    features["iq_correlation"] = cor(real_part, imag_part)

    return features
end

function compute_cyclostationary_fingerprint(signal::Vector{Complex{T}}) where {T<:Number}
    n = length(signal)
    features = Dict{String,Float64}()
    nfft = 256
    step = nfft ÷ 2
    nframes = max(1, (n - nfft) ÷ step + 1)

    cyclic_spectrum = zeros(Float64, nfft)
    for i in 0:(nframes - 1)
        start_idx = i * step + 1
        end_idx = min(start_idx + nfft - 1, n)
        if end_idx - start_idx + 1 >= nfft
            segment = signal[start_idx:end_idx]
            spec = abs2.(fft(segment))
            cyclic_spectrum .+= spec
        end
    end
    cyclic_spectrum ./= nframes

    features["cyclic_peak"] = maximum(cyclic_spectrum)
    features["cyclic_mean"] = mean(cyclic_spectrum)
    features["cyclic_variance"] = var(cyclic_spectrum)

    return features
end

function compute_wavelet_fingerprint(signal::Vector{Complex{T}}; levels::Int=4) where {T<:Number}
    n = length(signal)
    features = Dict{String,Float64}()
    real_part = real(signal)

    approx = copy(real_part)
    for level in 1:min(levels, Int(floor(log2(n))))
        n_curr = length(approx)
        if n_curr < 2
            break
        end
        half = n_curr ÷ 2
        detail = zeros(half)
        new_approx = zeros(half)
        for i in 1:half
            idx = 2*i - 1
            if idx + 1 <= n_curr
                new_approx[i] = (approx[idx] + approx[idx+1]) / sqrt(2)
                detail[i] = (approx[idx] - approx[idx+1]) / sqrt(2)
            end
        end
        features["wavelet_level_$(level)_mean"] = mean(abs.(detail))
        features["wavelet_level_$(level)_var"] = var(detail)
        approx = new_approx
    end

    features["wavelet_approx_mean"] = mean(abs.(approx))
    features["wavelet_approx_var"] = var(approx)

    return features
end

function fit_histogram(data::Vector{Float64}, num_bins::Int) -> Vector{Float64}
    min_val = minimum(data)
    max_val = maximum(data)
    if max_val - min_val < eps()
        return ones(num_bins) / num_bins
    end
    bin_width = (max_val - min_val) / num_bins
    hist = zeros(Float64, num_bins)
    for v in data
        bin_idx = min(max(1, Int(floor((v - min_val) / bin_width)) + 1), num_bins)
        hist[bin_idx] += 1
    end
    return hist / (sum(hist) + eps())
end

function histogram_entropy(hist::Vector{Float64}) -> Float64
    h = -sum(p * log(p + eps()) for p in hist)
    return h / log(length(hist) + eps())
end

function compare_fingerprints(fp1::Vector{FingerprintFeature}, fp2::Vector{FingerprintFeature}) -> Float64
    n = min(length(fp1), length(fp2))
    if n == 0
        return 1.0
    end

    total_weight = 0.0
    weighted_diff = 0.0

    for i in 1:n
        w = (fp1[i].weight + fp2[i].weight) / 2
        diff = abs(fp1[i].value - fp2[i].value) / (max(abs(fp1[i].value), abs(fp2[i].value), 1e-10))
        weighted_diff += w * diff
        total_weight += w
    end

    return weighted_diff / total_weight
end

function add_to_database(db::RFDatabase, profile::RFProfile)
    push!(db.profiles, profile)
end

function identify_transmitter(db::RFDatabase, fingerprints::Vector{FingerprintFeature}) -> Tuple{String, Float64}
    if isempty(db.profiles)
        return "unknown", 1.0
    end

    best_match = ""
    best_distance = Inf

    for profile in db.profiles
        dist = compare_fingerprints(fingerprints, profile.fingerprints)
        if dist < best_distance
            best_distance = dist
            best_match = profile.transmitter_id
        end
    end

    confidence = max(0.0, 1.0 - best_distance / db.distance_threshold)
    return best_match, confidence
end

function identify_transmitters(db::RFDatabase, signal::Vector{Complex{Float32}}) -> Tuple{String, Float64}
    fp = extract_fingerprint(signal)
    return identify_transmitter(db, fp)
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
