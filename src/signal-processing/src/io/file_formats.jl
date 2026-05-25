module file_formats

using DelimitedFiles
using LinearAlgebra
using Statistics

export read_signal_file, read_iq_file, read_bin_file,
       read_wav_file, read_cfile, read_sigmf_data,
       write_signal_file, write_iq_file, write_bin_file,
       write_wav_file, write_cfile, FileFormatConfig,
       detect_file_format, read_sigmf_metadata,
       read_blade_rf_file, read_usrp_file

struct FileFormatConfig
    format::String
    data_type::String
    endianness::Symbol
    iq_interleaved::Bool
    scale_factor::Float64
    header_bytes::Int
    metadata::Dict{String,String}
end

function FileFormatConfig(;format::String="iq", data_type::String="float32", endianness::Symbol=:little, iq_interleaved::Bool=true, scale_factor::Float64=1.0, header_bytes::Int=0)
    return FileFormatConfig(format, data_type, endianness, iq_interleaved, scale_factor, header_bytes, Dict{String,String}())
end

function detect_file_format(filename::String) -> String
    ext = splitext(filename)[2]
    if ext == ".iq"
        return "iq"
    elseif ext == ".bin"
        return "bin"
    elseif ext in (".wav", ".WAV")
        return "wav"
    elseif ext == ".cfile"
        return "cfile"
    elseif ext == ".sigmf-data"
        return "sigmf"
    elseif ext in (".cu8", ".cu16")
        return "cu8"
    elseif ext in (".cs8", ".cs16")
        return "cs8"
    elseif ext == ".cf32"
        return "cf32"
    else
        return "raw"
    end
end

function read_signal_file(filename::String; config::FileFormatConfig=FileFormatConfig())
    format = detect_file_format(filename)
    if format == "iq"
        return read_iq_file(filename, config)
    elseif format == "bin"
        return read_bin_file(filename, config)
    elseif format == "wav"
        return read_wav_file(filename)
    elseif format == "cfile"
        return read_cfile(filename, config)
    elseif format == "sigmf"
        return read_sigmf_data(filename)
    elseif format == "cf32"
        return read_cf32_generic(filename)
    elseif format in ("cu8", "cs8", "cu16", "cs16")
        return read_iq_file(filename, config)
    else
        return read_bin_file(filename, config)
    end
end

function read_iq_file(filename::String, config::FileFormatConfig=FileFormatConfig()) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        if config.header_bytes > 0
            seek(io, config.header_bytes)
        end
        read(io)
    end

    if config.data_type == "float32"
        raw = reinterpret(Float32, data)
        if config.iq_interleaved
            n = length(raw) ÷ 2
            return Complex{Float32}.(raw[1:2:end], raw[2:2:end]) .* config.scale_factor
        else
            n = length(raw) ÷ 2
            return Complex{Float32}.(raw[1:n], raw[n+1:end]) .* config.scale_factor
        end
    elseif config.data_type == "float64"
        raw = reinterpret(Float64, data)
        if config.iq_interleaved
            n = length(raw) ÷ 2
            return Complex{Float32}.(raw[1:2:end], raw[2:2:end]) .* config.scale_factor
        else
            n = length(raw) ÷ 2
            return Complex{Float32}.(raw[1:n], raw[n+1:end]) .* config.scale_factor
        end
    elseif config.data_type == "int16"
        raw = reinterpret(Int16, data)
        if config.iq_interleaved
            n = length(raw) ÷ 2
            return Complex{Float32}.(Float32.(raw[1:2:end]), Float32.(raw[2:2:end])) ./ 32767.0f0 .* config.scale_factor
        else
            n = length(raw) ÷ 2
            return Complex{Float32}.(Float32.(raw[1:n]), Float32.(raw[n+1:end])) ./ 32767.0f0 .* config.scale_factor
        end
    elseif config.data_type == "int8"
        raw = reinterpret(Int8, data)
        n = length(raw) ÷ 2
        return Complex{Float32}.(Float32.(raw[1:2:end]), Float32.(raw[2:2:end])) ./ 127.0f0 .* config.scale_factor
    elseif config.data_type == "uint8"
        raw = reinterpret(UInt8, data)
        n = length(raw) ÷ 2
        return Complex{Float32}.(Float32.(raw[1:2:end]) ./ 255.0f0 .- 0.5f0,
                                Float32.(raw[2:2:end]) ./ 255.0f0 .- 0.5f0) .* 2.0f0 .* config.scale_factor
    else
        error("Unsupported data type: $(config.data_type)")
    end
end

function read_bin_file(filename::String, config::FileFormatConfig=FileFormatConfig()) -> Vector{Complex{Float32}}
    return read_iq_file(filename, config)
end

function read_cf32_generic(filename::String) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        read(io)
    end
    return reinterpret(Complex{Float32}, data)
end

function read_wav_file(filename::String) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        read(io)
    end

    riff = String(data[1:4])
    if riff != "RIFF"
        error("Not a valid WAV file")
    end

    num_channels = reinterpret(Int16, data[23:24])[1]
    bits_per_sample = reinterpret(Int16, data[35:36])[1]
    data_start = 44

    if bits_per_sample == 16
        raw = reinterpret(Int16, data[data_start:end])
    elseif bits_per_sample == 32
        raw = reinterpret(Float32, data[data_start:end])
    else
        raw = Float32.(reinterpret(Int16, data[data_start:end]))
    end

    if num_channels >= 2
        n = length(raw) ÷ num_channels
        return Complex{Float32}.(Float32.(raw[1:num_channels:end]),
                                  Float32.(raw[2:num_channels:end]))
    else
        return Complex{Float32}.(Float32.(raw), zeros(Float32, length(raw)))
    end
end

function read_cfile(filename::String, config::FileFormatConfig=FileFormatConfig()) -> Vector{Complex{Float32}}
    return read_cf32_generic(filename)
end

function read_sigmf_data(filename::String) -> Vector{Complex{Float32}}
    meta_file = splitext(filename)[1] * ".sigmf-meta"
    metadata = Dict{String,Any}()

    if isfile(meta_file)
        metadata = read_sigmf_metadata(meta_file)
    end

    data_type = get(metadata, "core:datatype", "cf32_le")
    n_samples = get(metadata, "core:num_samples", "-1")

    if data_type == "cf32_le"
        return read_cf32_generic(filename)
    elseif data_type == "cu8"
        return read_iq_file(filename, FileFormatConfig(data_type="uint8"))
    elseif data_type == "cs8"
        return read_iq_file(filename, FileFormatConfig(data_type="int8"))
    else
        return read_cf32_generic(filename)
    end
end

function read_sigmf_metadata(filename::String) -> Dict{String,Any}
    metadata = Dict{String,Any}()
    for line in readlines(filename)
        if occursin(":", line)
            parts = split(line, ":", limit=2)
            if length(parts) == 2
                key = strip(parts[1])
                value = strip(parts[2])
                metadata[key] = value
            end
        end
    end
    return metadata
end

function read_blade_rf_file(filename::String) -> Vector{Complex{Float32}}
    data = open(filename, "r") do io
        seek(io, 0)
        read(io)
    end
    raw = reinterpret(Int16, data)
    n = length(raw) ÷ 2
    return Complex{Float32}.(Float32.(raw[1:2:end]), Float32.(raw[2:2:end])) ./ 32767.0f0
end

function read_usrp_file(filename::String) -> Vector{Complex{Float32}}
    return read_cf32_generic(filename)
end

function write_signal_file(filename::String, samples::Vector{Complex{T}}; config::FileFormatConfig=FileFormatConfig()) where {T<:AbstractFloat}
    format = detect_file_format(filename)
    if format == "iq"
        write_iq_file(filename, samples, config)
    elseif format == "bin"
        write_bin_file(filename, samples, config)
    elseif format == "wav"
        write_wav_file(filename, samples)
    elseif format == "cfile"
        write_cfile(filename, samples)
    else
        write_iq_file(filename, samples, config)
    end
end

function write_iq_file(filename::String, samples::Vector{Complex{T}}, config::FileFormatConfig=FileFormatConfig()) where {T<:AbstractFloat}
    open(filename, "w") do io
        if config.data_type == "float32"
            interleaved = zeros(Float32, 2 * length(samples))
            interleaved[1:2:end] .= real.(samples) ./ config.scale_factor
            interleaved[2:2:end] .= imag.(samples) ./ config.scale_factor
            write(io, interleaved)
        elseif config.data_type == "int16"
            interleaved = zeros(Int16, 2 * length(samples))
            interleaved[1:2:end] .= Int16.(clamp.(round.(real.(samples) ./ config.scale_factor .* 32767), -32768, 32767))
            interleaved[2:2:end] .= Int16.(clamp.(round.(imag.(samples) ./ config.scale_factor .* 32767), -32768, 32767))
            write(io, interleaved)
        else
            interleaved = reinterpret(Float32, samples)
            write(io, interleaved)
        end
    end
end

function write_bin_file(filename::String, samples::Vector{Complex{T}}, config::FileFormatConfig=FileFormatConfig()) where {T<:AbstractFloat}
    write_iq_file(filename, samples, config)
end

function write_wav_file(filename::String, samples::Vector{Complex{T}}) where {T<:AbstractFloat}
    data = Float64.(real(samples))
    max_val = max(maximum(abs.(data)), 1e-10)
    data ./= max_val

    open(filename, "w") do io
        write(io, "RIFF")
        n = length(data)
        data_size = n * 2
        write(io, Int32(36 + data_size))
        write(io, "WAVE")
        write(io, "fmt ")
        write(io, Int32(16))
        write(io, Int16(1))
        write(io, Int16(1))
        write(io, Int32(44100))
        write(io, Int32(44100 * 2))
        write(io, Int16(2))
        write(io, Int16(16))
        write(io, "data")
        write(io, Int32(data_size))
        write(io, Int16.(clamp.(round.(data .* 32767), -32768, 32767)))
    end
end

function write_cfile(filename::String, samples::Vector{Complex{T}}) where {T<:AbstractFloat}
    write_cf32_generic(filename, samples)
end

function write_cf32_generic(filename::String, samples::Vector{Complex{T}}) where {T<:AbstractFloat}
    open(filename, "w") do io
        write(io, reinterpret(Float32, samples))
    end
end

end
