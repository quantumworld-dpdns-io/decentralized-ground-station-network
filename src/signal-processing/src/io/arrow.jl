module arrow_io

using LinearAlgebra
using Statistics

export write_arrow_file, read_arrow_file, write_results,
       ArrowConfig, ArrowTable, ArrowColumn

struct ArrowConfig
    compression::String
    chunk_size::Int
    include_metadata::Bool
    schema_version::String
end

function ArrowConfig(;
    compression::String="zstd",
    chunk_size::Int=65536,
    include_metadata::Bool=true,
    schema_version::String="1.0.0",
)
    return ArrowConfig(compression, chunk_size, include_metadata, schema_version)
end

struct ArrowColumn
    name::String
    data::Vector{Float64}
    dtype::String
    metadata::Dict{String,String}
end

function ArrowColumn(name::String, data::Vector{T}) where {T<:Number}
    return ArrowColumn(name, Float64.(data), "float64", Dict{String,String}())
end

struct ArrowTable
    columns::Vector{ArrowColumn}
    metadata::Dict{String,String}
    num_rows::Int
end

function ArrowTable(columns::Vector{ArrowColumn}; metadata::Dict{String,String}=Dict{String,String}())
    num_rows = isempty(columns) ? 0 : length(columns[1].data)
    return ArrowTable(columns, metadata, num_rows)
end

function serialize_table(table::ArrowTable) -> Vector{UInt8}
    io = IOBuffer()
    write(io, "ARROW1")
    write(io, zero(UInt32))

    metadata_bytes = serialize_metadata(table)
    write(io, UInt64(length(metadata_bytes)))
    write(io, metadata_bytes)

    for col in table.columns
        col_bytes = serialize_column(col)
        write(io, UInt64(length(col_bytes)))
        write(io, col_bytes)
    end

    return take!(io)
end

function deserialize_table(data::Vector{UInt8}) -> ArrowTable
    io = IOBuffer(data)
    magic = String(read!(io, Vector{UInt8}(undef, 6)))
    if magic != "ARROW1"
        error("Invalid Arrow magic bytes: $magic")
    end
    _ = read(io, UInt32)
    meta_len = read(io, UInt64)
    metadata_bytes = read!(io, Vector{UInt8}(undef, meta_len))
    metadata = deserialize_metadata(metadata_bytes)

    columns = ArrowColumn[]
    while position(io) < length(data)
        col_len = read(io, UInt64)
        if position(io) + col_len > length(data)
            break
        end
        col_bytes = read!(io, Vector{UInt8}(undef, col_len))
        push!(columns, deserialize_column(col_bytes))
    end

    return ArrowTable(columns, metadata=metadata)
end

function serialize_column(col::ArrowColumn) -> Vector{UInt8}
    io = IOBuffer()
    name_bytes = Vector{UInt8}(col.name)
    write(io, UInt32(length(name_bytes)))
    write(io, name_bytes)
    dtype_bytes = Vector{UInt8}(col.dtype)
    write(io, UInt32(length(dtype_bytes)))
    write(io, dtype_bytes)
    write(io, UInt64(length(col.data)))
    write(io, col.data)
    return take!(io)
end

function deserialize_column(data::Vector{UInt8}) -> ArrowColumn
    io = IOBuffer(data)
    name_len = read(io, UInt32)
    name = String(read!(io, Vector{UInt8}(undef, name_len)))
    dtype_len = read(io, UInt32)
    dtype = String(read!(io, Vector{UInt8}(undef, dtype_len)))
    data_len = read(io, UInt64)
    raw_data = read!(io, Vector{Float64}(undef, data_len))
    return ArrowColumn(name, raw_data, dtype)
end

function serialize_metadata(table::ArrowTable) -> Vector{UInt8}
    io = IOBuffer()
    write(io, UInt32(length(table.metadata)))
    for (k, v) in table.metadata
        k_bytes = Vector{UInt8}(k)
        v_bytes = Vector{UInt8}(v)
        write(io, UInt32(length(k_bytes)))
        write(io, k_bytes)
        write(io, UInt32(length(v_bytes)))
        write(io, v_bytes)
    end
    write(io, UInt32(length(table.columns)))
    return take!(io)
end

function deserialize_metadata(data::Vector{UInt8}) -> Dict{String,String}
    io = IOBuffer(data)
    result = Dict{String,String}()
    meta_count = read(io, UInt32)
    for _ in 1:meta_count
        k_len = read(io, UInt32)
        k = String(read!(io, Vector{UInt8}(undef, k_len)))
        v_len = read(io, UInt32)
        v = String(read!(io, Vector{UInt8}(undef, v_len)))
        result[k] = v
    end
    return result
end

function write_arrow_file(filename::String, table::ArrowTable)
    data = serialize_table(table)
    open(filename, "w") do io
        write(io, data)
    end
    return length(data)
end

function read_arrow_file(filename::String) -> ArrowTable
    data = open(filename, "r") do io
        read(io)
    end
    return deserialize_table(data)
end

function write_results(
    filename::String,
    results::Dict{String,Any};
    config::ArrowConfig=ArrowConfig(),
)
    columns = ArrowColumn[]
    for (key, value) in results
        if value isa Vector
            push!(columns, ArrowColumn(key, Float64.(value)))
        elseif value isa Number
            push!(columns, ArrowColumn(key, [Float64(value)]))
        end
    end

    metadata = Dict{String,String}(
        "schema_version" => config.schema_version,
        "compression" => config.compression,
        "created_at" => string(time()),
    )

    table = ArrowTable(columns, metadata=metadata)
    write_arrow_file(filename, table)
end

function convert_to_arrow(results::Dict{String,Any}) -> ArrowTable
    columns = ArrowColumn[]
    for (key, value) in results
        if value isa Vector
            push!(columns, ArrowColumn(key, Float64.(value)))
        elseif value isa Number
            push!(columns, ArrowColumn(key, [Float64(value)]))
        end
    end
    return ArrowTable(columns)
end

end
