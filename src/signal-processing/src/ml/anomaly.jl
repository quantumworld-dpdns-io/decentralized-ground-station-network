module anomaly

using Statistics
using LinearAlgebra
using Random

export IsolationForest, AnomalyDetector, AutoencoderAnomaly,
       OneClassSVM, detect_anomalies, train_isolation_forest,
       i_forest_score, fit_autoencoder, reconstruct_error,
       one_class_svm_score, IsolationTreeNode

struct IsolationTreeNode
    left::Union{IsolationTreeNode, Nothing}
    right::Union{IsolationTreeNode, Nothing}
    split_feature::Int
    split_value::Float64
    size::Int
    height::Int
    is_leaf::Bool
end

function IsolationTreeNode(is_leaf::Bool=false, size::Int=0, height::Int=0)
    return IsolationTreeNode(nothing, nothing, 0, 0.0, size, height, is_leaf)
end

mutable struct IsolationForest
    trees::Vector{IsolationTreeNode}
    num_trees::Int
    sample_size::Int
    max_depth::Int
    rng::AbstractRNG
    trained::Bool
end

function IsolationForest(;num_trees::Int=100, sample_size::Int=256, max_depth::Int=0, seed::Int=42)
    if max_depth <= 0
        max_depth = Int(ceil(log2(sample_size)))
    end
    return IsolationForest(IsolationTreeNode[], num_trees, sample_size, max_depth, MersenneTwister(seed), false)
end

function train_isolation_forest(data::Matrix{Float64}, forest::IsolationForest) -> IsolationForest
    n, _ = size(data)
    forest.trees = IsolationTreeNode[]

    for i in 1:forest.num_trees
        indices = rand(forest.rng, 1:n, min(forest.sample_size, n))
        sample = data[indices, :]
        tree = build_isolation_tree(sample, 0, forest.max_depth)
        push!(forest.trees, tree)
    end

    forest.trained = true
    return forest
end

function build_isolation_tree(data::Matrix{Float64}, current_depth::Int, max_depth::Int) -> IsolationTreeNode
    n, m = size(data)

    if current_depth >= max_depth || n <= 1
        return IsolationTreeNode(true, n, current_depth)
    end

    q = rand(1:m)
    min_val = minimum(data[:, q])
    max_val = maximum(data[:, q])

    if max_val - min_val < eps()
        return IsolationTreeNode(true, n, current_depth)
    end

    split_val = rand() * (max_val - min_val) + min_val

    left_mask = data[:, q] .< split_val
    right_mask = .!left_mask

    left_data = data[left_mask, :]
    right_data = data[right_mask, :]

    left_node = build_isolation_tree(left_data, current_depth + 1, max_depth)
    right_node = build_isolation_tree(right_data, current_depth + 1, max_depth)

    return IsolationTreeNode(left_node, right_node, q, split_val, n, current_depth, false)
end

function path_length(tree::IsolationTreeNode, sample::Vector{Float64}, current_depth::Int) -> Float64
    if tree.is_leaf
        if tree.size <= 1
            return Float64(current_depth)
        end
        return Float64(current_depth) + c_factor(tree.size)
    end

    if sample[tree.split_feature] < tree.split_value
        return path_length(tree.left, sample, current_depth + 1)
    else
        return path_length(tree.right, sample, current_depth + 1)
    end
end

function c_factor(n::Int) -> Float64
    if n <= 1
        return 0.0
    end
    H = log(n - 1) + 0.5772156649
    return 2 * H - 2 * (n - 1) / n
end

function i_forest_score(forest::IsolationForest, sample::Vector{Float64}) -> Float64
    if !forest.trained
        error("Isolation forest not trained")
    end

    avg_path = mean([path_length(tree, sample, 0) for tree in forest.trees])
    c = c_factor(forest.sample_size)
    return 2.0^(-avg_path / c)
end

function detect_anomalies(forest::IsolationForest, data::Matrix{Float64}; threshold::Float64=0.5)
    n = size(data, 1)
    scores = zeros(Float64, n)
    anomalies = Bool[]

    for i in 1:n
        scores[i] = i_forest_score(forest, data[i, :])
        push!(anomalies, scores[i] > threshold)
    end

    return anomalies, scores
end

mutable struct AutoencoderAnomaly
    input_dim::Int
    hidden_dim::Int
    latent_dim::Int
    encoder_weights::Matrix{Float64}
    encoder_bias::Vector{Float64}
    decoder_weights::Matrix{Float64}
    decoder_bias::Vector{Float64}
    trained::Bool
    threshold::Float64
end

function AutoencoderAnomaly(;input_dim::Int=10, hidden_dim::Int=8, latent_dim::Int=4, threshold::Float64=0.1)
    encoder_w = randn(hidden_dim, input_dim) * 0.01
    encoder_b = zeros(hidden_dim)
    decoder_w = randn(input_dim, latent_dim) * 0.01
    decoder_b = zeros(input_dim)
    return AutoencoderAnomaly(input_dim, hidden_dim, latent_dim,
                               encoder_w, encoder_b, decoder_w, decoder_b, false, threshold)
end

function fit_autoencoder(model::AutoencoderAnomaly, data::Matrix{Float64}; epochs::Int=100, lr::Float64=0.01)
    n, _ = size(data)
    encoder_w = copy(model.encoder_weights)
    encoder_b = copy(model.encoder_bias)
    decoder_w = copy(model.decoder_weights)
    decoder_b = copy(model.decoder_bias)

    for epoch in 1:epochs
        total_loss = 0.0
        for i in 1:n
            x = data[i, :]
            hidden = relu.(encoder_w * x .+ encoder_b)
            latent = model.latent_dim < model.hidden_dim ? relu.(hidden[1:model.latent_dim]) : hidden[1:min(model.latent_dim, length(hidden))]
            recon = decoder_w * latent .+ decoder_b
            loss = sum((x - recon).^2)
            total_loss += loss

            grad = 2 * (recon - x)
            decoder_w .-= lr * grad * latent'
            decoder_b .-= lr * grad
        end
    end

    model.encoder_weights = encoder_w
    model.encoder_bias = encoder_b
    model.decoder_weights = decoder_w
    model.decoder_bias = decoder_b
    model.trained = true

    return model
end

function reconstruct_error(model::AutoencoderAnomaly, sample::Vector{Float64}) -> Float64
    if !model.trained
        return Inf
    end
    hidden = relu.(model.encoder_weights * sample .+ model.encoder_bias)
    latent = hidden[1:min(model.latent_dim, length(hidden))]
    recon = model.decoder_weights * latent .+ model.decoder_bias
    return sum((sample - recon).^2)
end

function detect_anomalies(model::AutoencoderAnomaly, data::Matrix{Float64}) -> Tuple{Vector{Bool}, Vector{Float64}}
    n = size(data, 1)
    errors = zeros(Float64, n)
    anomalies = Bool[]

    for i in 1:n
        errors[i] = reconstruct_error(model, data[i, :])
        push!(anomalies, errors[i] > model.threshold)
    end

    return anomalies, errors
end

mutable struct OneClassSVM
    nu::Float64
    gamma::Float64
    support_vectors::Matrix{Float64}
    alphas::Vector{Float64}
    rho::Float64
    trained::Bool
end

function OneClassSVM(;nu::Float64=0.1, gamma::Float64=0.1)
    return OneClassSVM(nu, gamma, zeros(0, 0), zeros(0), 0.0, false)
end

function rbf_kernel(x::Vector{Float64}, y::Vector{Float64}, gamma::Float64) -> Float64
    return exp(-gamma * sum(abs2.(x - y)))
end

function one_class_svm_score(model::OneClassSVM, sample::Vector{Float64}) -> Float64
    if !model.trained
        return 0.0
    end
    n_sv = size(model.support_vectors, 1)
    score = 0.0
    for i in 1:n_sv
        score += model.alphas[i] * rbf_kernel(sample, model.support_vectors[i, :], model.gamma)
    end
    return score - model.rho
end

function train_one_class_svm(model::OneClassSVM, data::Matrix{Float64})
    n, _ = size(data)
    K = zeros(n, n)
    for i in 1:n
        for j in 1:n
            K[i, j] = rbf_kernel(data[i, :], data[j, :], model.gamma)
        end
    end

    q = -ones(n)
    P = copy(K)
    G = vcat(eye(n), -eye(n))
    h = vcat(ones(n) / (model.nu * n), zeros(n))
    A = ones(1, n)
    b = [1.0]

    model.support_vectors = copy(data)
    model.alphas = ones(n) / n
    model.rho = mean(K * model.alphas)
    model.trained = true

    return model
end

function detect_anomalies(model::OneClassSVM, data::Matrix{Float64}; threshold::Float64=0.0)
    n = size(data, 1)
    scores = zeros(Float64, n)
    anomalies = Bool[]

    for i in 1:n
        scores[i] = one_class_svm_score(model, data[i, :])
        push!(anomalies, scores[i] < threshold)
    end

    return anomalies, scores
end

function relu(x::Float64) -> Float64
    return max(0.0, x)
end

function relu(x::Vector{Float64}) -> Vector{Float64}
    return max.(0.0, x)
end

function eye(n::Int) -> Matrix{Float64}
    return Matrix{Float64}(I, n, n)
end

end
