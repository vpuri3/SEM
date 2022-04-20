#
""" Scalar function field in D-dimensional space over a spectral basis"""
struct Field{T,D,Tarr <: AbstractArray{T,D}} <: AbstractSpectralField{T,D}
    array::Tarr
end

# display
function Base.summary(io::IO, u::Field{T,D,Tarr}) where{T,D,Tarr}
    println(io, "$(D)D scalar field of type $T")
    Base.show(io, typeof(u))
end
function Base.show(io::IO, ::MIME"text/plain", u::Field{T,D,Tarr}) where{T,D,Tarr}
    iocontext = IOContext(io, :compact => true, :limit => true)
    Base.summary(iocontext, u)
    Base.show(iocontext, MIME"text/plain"(), u.array)
    println()
end

# vector indexing
Base.IndexStyle(::Field) = IndexLinear()
Base.getindex(u::Field, i::Int) = getindex(u.array, i)
Base.setindex!(u::Field, v, i::Int) = setindex!(u.array, v, i)
Base.size(u::Field) = (length(u.array),)

# allocation
Base.similar(u::Field, ::Type{T} = eltype(u), dims::Dims = size(u.array)) where{T} = Field(similar(u.array, T, dims))
Base.zero(u::Field, dims::Dims) = zero(u) # ignore dims since <: AbstractVector

# broadcast
Base.Broadcast.BroadcastStyle(::Type{<:Field}) = Broadcast.ArrayStyle{Field}()
function Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{Field}},
                      ::Type{ElType}) where ElType
  u = find_fld(bc)
  Field(similar(Array{ElType}, axes(u.array)))
end

find_fld(bc::Base.Broadcast.Broadcasted) = find_fld(bc.args)
find_fld(args::Tuple) = find_fld(find_fld(args[1]), Base.tail(args))
find_fld(x) = x
find_fld(::Tuple{}) = nothing
find_fld(a::Field, rest) = a
find_fld(::Any, rest) = find_fld(rest)

#=
for op in (
           :+ , :- , :* , :/, :\,
          )
    @eval function Base.$op(u::Field{Ta,Da,TarrU},
                            v::Field{Tb,Db,TarrV}
                           ) where{Ta,Tb,Da,Db,TarrU,TarrV}
        @assert Da == Db
        $op(u,v)
    end
end
=#

#
