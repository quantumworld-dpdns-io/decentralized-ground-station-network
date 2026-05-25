module sdr

using DelimitedFiles
using LinearAlgebra
using Statistics

export read_iq_samples, read_cu8_file, read_cs8_file,
       read_cf32_file, read_cu16_file, read_hackrf_file,
       read_rtlsdr_file, read_sigmf_metadata,
       write_iq_samples, write_cf32_file, SDRConfig

struct SDRConfig
    center_freq::Float64
    sample_rate::Float64
    gain::Float64
    bandwidth::Float64
    antenna::String
    file_format::String
    endianness::Symbol
end

function SDRConfig(;
    center_freq::Float64=2.4e9,
    sample_rate::Float64=2.5e6,
    gain::Float64=40.0,
    bandwidth::Float64=2.5e6,
    antenna::String="RX",
    file_format::String="cf32",
    endianness::Symbol=:little,
)
    return SDRConfig(center_freq, sample_rate, gain, bandwidth, antenna, file_format, endianness)
end

function read_iq_samples(
    filename::String;
    format::String="cf32",
    n_samples::Int=-1,
    offset::Int=0,
) -> Vector{Complex{Float32}}
    if format == "cf32"
        return read_cf32_file(filename, n_samples, offset)
    elseif format == "cs8"
        return read_cs8_file(filename, n_samples, offset)
    elseif format == "cu8"
        return read_cu8_file(filename, n_samples, offset)
    elseif format == "cu16"
        return read_cu16_file(filename, n_samples, offset)
    else
        error("Unsupported format: $format")
    end
end

function read_cf32_file(
    filename::String,
    n_samples::Int=-1,
    offset::Int=0,
) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        seek(io, offset * 8)
        if n_samples > 0
            read!(io, Vector{Complex{Float32}}(undef, n_samples))
        else
            data_vec = read(io)
            length(data_vec) ÷ 8 > 0 ? reinterpret(Complex{Float32}, data_vec) : Complex{Float32}[]
        end
    end
    return data
end

function read_cs8_file(
    filename::String,
    n_samples::Int=-1,
    offset::Int=0,
) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        seek(io, offset * 2)
        if n_samples > 0
            raw = read!(io, Vector{Int8}(undef, n_samples * 2))
        else
            raw = read(io)
        end
        i_vals = Float32.(raw[1:2:end]) / 127.0f0
        q_vals = Float32.(raw[2:2:end]) / 127.0f0
        complex.(i_vals, q_vals)
    end
    return data
end

function read_cu8_file(
    filename::String,
    n_samples::Int=-1,
    offset::Int=0,
) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        seek(io, offset * 2)
        if n_samples > 0
            raw = read!(io, Vector{UInt8}(undef, n_samples * 2))
        else
            raw = read(io)
        end
        i_vals = Float32.(raw[1:2:end]) / 255.0f0 .- 0.5f0
        q_vals = Float32.(raw[2:2:end]) / 255.0f0 .- 0.5f0
        complex.(i_vals, q_vals)
    end
    return data .* 2.0f0
end

function read_cu16_file(
    filename::String,
    n_samples::Int=-1,
    offset::Int=0,
) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        seek(io, offset * 4)
        if n_samples > 0
            raw = read!(io, Vector{UInt16}(undef, n_samples * 2))
        else
            raw = read(io)
        end
        i_vals = Float32.(raw[1:2:end]) / 65535.0f0 .- 0.5f0
        q_vals = Float32.(raw[2:2:end]) / 65535.0f0 .- 0.5f0
        complex.(i_vals, q_vals)
    end
    return data .* 2.0f0
end

function read_hackrf_file(
    filename::String;
    n_samples::Int=-1,
) -> Vector{Complex{Float32}}
    return read_cs8_file(filename, n_samples)
end

function read_rtlsdr_file(
    filename::String;
    n_samples::Int=-1,
) -> Vector{Complex{Float32}}
    return read_cu8_file(filename, n_samples)
end

function read_sigmf_metadata(filename::String) -> Dict{String,Any}
    metadata = Dict{String,Any}()

    base = splitext(filename)[1]
    meta_file = base * ".sigmf-meta"
    data_file = base * ".sigmf-data"

    if isfile(meta_file)
        for line in readlines(meta_file)
            if occursin(":", line)
                parts = split(line, ":", limit=2)
                if length(parts) == 2
                    key = strip(parts[1])
                    value = strip(parts[2])
                    metadata[key] = value
                end
            end
        end
    end

    if !haskey(metadata, "core:datatype")
        metadata["core:datatype"] = "cf32_le"
    end
    if !haskey(metadata, "core:sample_rate")
        metadata["core:sample_rate"] = "1000000"
    end

    metadata["file_path"] = data_file
    return metadata
end

function write_iq_samples(
    filename::String,
    samples::Vector{Complex{T}};
    format::String="cf32",
) where {T<:AbstractFloat}
    if format == "cf32"
        write_cf32_file(filename, samples)
    elseif format == "cs8"
        write_cs8_file(filename, samples)
    else
        error("Unsupported output format: $format")
    end
end

function write_cf32_file(filename::String, samples::Vector{Complex{T}}) where {T<:AbstractFloat}
    open(filename, "w") do io
        write(io, reinterpret(Float32, samples))
    end
end

function write_cs8_file(filename::String, samples::Vector{Complex{T}}) where {T<:AbstractFloat}
    i_vals = Int8.(clamp.(round.(real.(samples) .* 127), -128, 127))
    q_vals = Int8.(clamp.(round.(imag.(samples) .* 127), -128, 127))
    raw = zeros(Int8, 2 * length(samples))
    raw[1:2:end] .= i_vals
    raw[2:2:end] .= q_vals
    open(filename, "w") do io
        write(io, raw)
    end
end

function estimate_sample_rate(samples::Vector{Complex{Float32}}) -> Float64
    n = length(samples)
    if n < 2
        return 0.0
    end
    zero_crossings = 0
    for i in 2:n
        if real(samples[i-1]) * real(samples[i]) < 0
            zero_crossings += 1
        end
    end
    return zero_crossings / (n / 2)
end

end
