module classifier

using Statistics
using LinearAlgebra
using Random

export train_classifier, predict_modulation, extract_all_features,
       SignalClassifier, ModulationClass, FeatureExtractor,
       train_test_split, evaluate_classifier, FeatureVector

struct ModulationClass
    name::String
    id::Int
end

const MODULATION_CLASSES = [
    ModulationClass("BPSK", 1),
    ModulationClass("QPSK", 2),
    ModulationClass("8PSK", 3),
    ModulationClass("16QAM", 4),
    ModulationClass("64QAM", 5),
    ModulationClass("4ASK", 6),
    ModulationClass("8ASK", 7),
    ModulationClass("2FSK", 8),
    ModulationClass("4FSK", 9),
    ModulationClass("16APSK", 10),
    ModulationClass("32APSK", 11),
    ModulationClass("OQPSK", 12),
    ModulationClass("MSK", 13),
    ModulationClass("GMSK", 14),
    ModulationClass("AM-DSB", 15),
    ModulationClass("AM-SSB", 16),
    ModulationClass("FM", 17),
    ModulationClass("CW", 18),
    ModulationClass("OFDM", 19),
    ModulationClass("LFM", 20),
]

struct FeatureVector
    features::Vector{Float64}
    names::Vector{String}
    label::Int
end

struct FeatureExtractor
    num_cumulants::Int
    num_spectral_features::Int
    num_statistical_features::Int
    num_wavelet_features::Int
    include_high_order::Bool
end

function FeatureExtractor(;
    num_cumulants::Int=6,
    num_spectral_features::Int=8,
    num_statistical_features::Int=10,
    num_wavelet_features::Int=4,
    include_high_order::Bool=true,
)
    return FeatureExtractor(num_cumulants, num_spectral_features,
                           num_spectral_features, num_statistical_features,
                           num_wavelet_features, include_high_order)
end

mutable struct SignalClassifier
    weights::Matrix{Float64}
    bias::Vector{Float64}
    classes::Vector{ModulationClass}
    feature_extractor::FeatureExtractor
    regularization::Float64
    learning_rate::Float64
    num_iterations::Int
    trained::Bool
end

function SignalClassifier(;
    classes::Vector{ModulationClass}=MODULATION_CLASSES,
    feature_extractor::FeatureExtractor=FeatureExtractor(),
    regularization::Float64=0.01,
    learning_rate::Float64=0.01,
    num_iterations::Int=1000,
)
    num_features = compute_feature_count(feature_extractor)
    num_classes = length(classes)
    return SignalClassifier(
        randn(num_features, num_classes) * 0.01,
        zeros(num_classes),
        classes, feature_extractor, regularization,
        learning_rate, num_iterations, false,
    )
end

function compute_feature_count(extractor::FeatureExtractor) -> Int
    return extractor.num_cumulants +
           extractor.num_spectral_features +
           extractor.num_statistical_features +
           extractor.num_wavelet_features
end

function extract_all_features(
    signal::Vector{Complex{T}},
    extractor::FeatureExtractor=FeatureExtractor(),
) where {T<:Number}
    n = length(signal)
    features = Float64[]
    names = String[]

    cumulants = extract_cumulants(signal, extractor.num_cumulants)
    append!(features, cumulants)
    for i in 1:extractor.num_cumulants
        push!(names, "cumulant_$i")
    end

    spectral = extract_spectral_features(signal, extractor.num_spectral_features)
    append!(features, spectral)
    for i in 1:extractor.num_spectral_features
        push!(names, "spectral_$i")
    end

    statistical = extract_statistical_features(signal, extractor.num_statistical_features)
    append!(features, statistical)
    for i in 1:extractor.num_statistical_features
        push!(names, "statistical_$i")
    end

    wavelet = extract_wavelet_features(signal, extractor.num_wavelet_features)
    append!(features, wavelet)
    for i in 1:extractor.num_wavelet_features
        push!(names, "wavelet_$i")
    end

    return FeatureVector(features, names, 0)
end

function extract_cumulants(signal::Vector{Complex{T}}, num::Int) where {T<:Number}
    n = length(signal)
    normalized = signal / (std(signal) + eps())
    cumulants = Float64[]

    m20 = mean(normalized.^2)
    m21 = mean(abs2.(normalized))
    m40 = mean(normalized.^4)
    m41 = mean(normalized.^2 .* conj(normalized).^2)
    m42 = mean(abs2.(normalized).^2)
    m60 = mean(normalized.^6)
    m61 = mean(normalized.^4 .* conj(normalized).^2)
    m63 = mean(abs2.(normalized).^3)

    c20 = m20
    c21 = m21
    c40 = m40 - 3 * m20^2
    c41 = m41 - abs(m20)^2 - 2 * m21^2
    c42 = m42 - abs(m20)^2 - 2 * m21^2
    c60 = m60 - 15 * m40 * m20 + 30 * m20^3
    c63 = m63 - 9 * m42 * m21 - 6 * m41 * m21 + 18 * m20 * conj(m20) * m21 + 12 * m21^3

    all_cumulants = [abs(c20), abs(c21), abs(c40), abs(c41), abs(c42), abs(c60), abs(c63)]
    for i in 1:min(num, length(all_cumulants))
        push!(cumulants, all_cumulants[i])
    end

    return cumulants
end

function extract_spectral_features(signal::Vector{Complex{T}}, num::Int) where {T<:Number}
    n = length(signal)
    features = Float64[]

    spectrum = abs.(fft(signal))
    spec_power = spectrum.^2
    half_n = n ÷ 2

    if half_n > 1
        spectral_centroid = sum((1:half_n) .* spec_power[1:half_n]) / (sum(spec_power[1:half_n]) + eps())
        push!(features, spectral_centroid / half_n)

        spectral_spread = sum(((1:half_n) .- spectral_centroid).^2 .* spec_power[1:half_n]) / (sum(spec_power[1:half_n]) + eps())
        push!(features, spectral_spread / half_n)

        spectral_skewness = sum(((1:half_n) .- spectral_centroid).^3 .* spec_power[1:half_n]) /
                           ((sum(spec_power[1:half_n]) + eps()) * spectral_spread^1.5 + eps())
        push!(features, spectral_skewness)

        spectral_kurtosis = sum(((1:half_n) .- spectral_centroid).^4 .* spec_power[1:half_n]) /
                           ((sum(spec_power[1:half_n]) + eps()) * spectral_spread^2 + eps()) - 3
        push!(features, spectral_kurtosis)
    end

    peak_power = maximum(spec_power)
    avg_power = mean(spec_power)
    push!(features, peak_power / (avg_power + eps()))

    bandwidth_99 = sum(spec_power .> 0.01 * peak_power) / n
    push!(features, bandwidth_99)

    spectral_rolloff = 0.0
    cum_power = 0.0
    total_power = sum(spec_power)
    for i in 1:n
        cum_power += spec_power[i]
        if cum_power >= 0.95 * total_power
            spectral_rolloff = i / n
            break
        end
    end
    push!(features, spectral_rolloff)

    push!(features, sum(spec_power[1:half_n]) / (sum(spec_power[half_n+1:end]) + eps()))

    for _ in length(features)+1:num
        push!(features, 0.0)
    end

    return features[1:min(num, length(features))]
end

function extract_statistical_features(signal::Vector{Complex{T}}, num::Int) where {T<:Number}
    n = length(signal)
    features = Float64[]
    real_part = real(signal)
    imag_part = imag(signal)
    amplitude = abs.(signal)
    phase = angle.(signal)
    phase_diff = [0.0; diff(phase)]
    instant_freq = [0.0; diff(unwrap_phase(phase))]

    stats_dict = Dict(
        "mean_amplitude" => mean(amplitude),
        "std_amplitude" => std(amplitude),
        "var_amplitude" => var(amplitude),
        "mean_phase" => mean(phase),
        "std_phase" => std(phase),
        "mean_freq" => mean(instant_freq),
        "std_freq" => std(instant_freq),
        "kurtosis_real" => kurtosis(real_part),
        "skewness_real" => skewness(real_part),
        "kurtosis_imag" => kurtosis(imag_part),
        "skewness_imag" => skewness(imag_part),
        "envelope_mean" => mean(amplitude.^2),
        "envelope_var" => var(amplitude.^2),
        "amplitude_crest" => maximum(amplitude) / (mean(amplitude) + eps()),
        "phase_deviation" => std(phase_diff),
        "zero_crossing_rate" => sum(abs.(diff(sign.(real_part)))) / (2 * n),
    )

    values = collect(values(stats_dict))
    for i in 1:min(num, length(values))
        push!(features, values[i])
    end

    return features
end

function extract_wavelet_features(signal::Vector{Complex{T}}, num::Int) where {T<:Number}
    n = length(signal)
    features = Float64[]

    real_part = real(signal)
    levels = min(num, Int(floor(log2(n))))

    approx = copy(real_part)
    for level in 1:levels
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

        push!(features, mean(abs.(detail)))
        push!(features, std(detail))
        approx = new_approx
    end

    push!(features, mean(abs.(approx)))
    push!(features, std(approx))

    return features
end

function unwrap_phase(phase::Vector{T}) where {T<:Number}
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

function train_sgd!(classifier::SignalClassifier, X::Matrix{Float64}, y::Vector{Int})
    n_samples, _ = size(X)
    n_classes = length(classifier.classes)

    Y = zeros(Float64, n_samples, n_classes)
    for i in 1:n_samples
        Y[i, y[i]] = 1.0
    end

    for iter in 1:classifier.num_iterations
        idx = rand(1:n_samples)
        x_i = X[idx, :]
        y_i = Y[idx, :]

        scores = x_i' * classifier.weights + classifier.bias'
        exp_scores = exp.(scores .- maximum(scores))
        probs = exp_scores / sum(exp_scores)

        gradient = x_i * (probs' - y_i')'
        classifier.weights .-= classifier.learning_rate * (gradient / n_samples + classifier.regularization * classifier.weights)
        classifier.bias .-= classifier.learning_rate * (probs - y_i)' / n_samples
    end

    classifier.trained = true
end

function train_classifier(
    classifier::SignalClassifier,
    signals::Vector{Vector{Complex{Float32}}},
    labels::Vector{Int},
) -> SignalClassifier
    n = length(signals)
    num_features = compute_feature_count(classifier.feature_extractor)
    X = zeros(Float64, n, num_features)
    y = labels

    for (i, signal) in enumerate(signals)
        fv = extract_all_features(signal, classifier.feature_extractor)
        X[i, :] = fv.features
    end

    X_norm = normalize_features(X)
    train_sgd!(classifier, X_norm, y)

    return classifier
end

function predict_modulation(
    classifier::SignalClassifier,
    signal::Vector{Complex{T}},
) -> Tuple{String, Int, Vector{Float64}} where {T<:Number}
    if !classifier.trained
        return "unknown", 0, Float64[]
    end

    fv = extract_all_features(signal, classifier.feature_extractor)
    x = normalize_features(reshape(fv.features, 1, length(fv.features)))

    scores = x * classifier.weights + classifier.bias'
    exp_scores = exp.(scores .- maximum(scores))
    probs = vec(exp_scores / sum(exp_scores))

    max_idx = argmax(probs)
    predicted_class = classifier.classes[max_idx]

    return predicted_class.name, predicted_class.id, probs
end

function evaluate_classifier(
    classifier::SignalClassifier,
    test_signals::Vector{Vector{Complex{Float32}}},
    test_labels::Vector{Int},
) -> Dict{String,Any}
    n = length(test_signals)
    correct = 0
    confusion_matrix = zeros(Int, length(classifier.classes), length(classifier.classes))

    for i in 1:n
        pred_name, pred_id, _ = predict_modulation(classifier, test_signals[i])
        true_label = test_labels[i]
        pred_label = pred_id

        if pred_label == true_label
            correct += 1
        end

        if pred_label > 0 && pred_label <= size(confusion_matrix, 1) &&
           true_label > 0 && true_label <= size(confusion_matrix, 2)
            confusion_matrix[pred_label, true_label] += 1
        end
    end

    accuracy = correct / n

    return Dict(
        "accuracy" => accuracy,
        "correct" => correct,
        "total" => n,
        "confusion_matrix" => confusion_matrix,
        "error_rate" => 1 - accuracy,
    )
end

function train_test_split(
    signals::Vector{Vector{Complex{Float32}}},
    labels::Vector{Int};
    test_ratio::Float64=0.2,
    shuffle::Bool=true,
) -> Tuple{Vector{Vector{Complex{Float32}}}, Vector{Int}, Vector{Vector{Complex{Float32}}}, Vector{Int}}
    n = length(signals)
    indices = shuffle ? shuffle(1:n) : 1:n
    n_test = max(1, round(Int, n * test_ratio))
    n_train = n - n_test

    train_idx = indices[1:n_train]
    test_idx = indices[n_train+1:end]

    train_signals = [signals[i] for i in train_idx]
    train_labels = [labels[i] for i in train_idx]
    test_signals = [signals[i] for i in test_idx]
    test_labels = [labels[i] for i in test_idx]

    return train_signals, train_labels, test_signals, test_labels
end

function normalize_features(X::Matrix{Float64}) -> Matrix{Float64}
    n, p = size(X)
    X_norm = copy(X)
    for j in 1:p
        mean_val = mean(X[:, j])
        std_val = std(X[:, j])
        if std_val > eps()
            X_norm[:, j] = (X[:, j] .- mean_val) ./ std_val
        else
            X_norm[:, j] .= 0.0
        end
    end
    return X_norm
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
