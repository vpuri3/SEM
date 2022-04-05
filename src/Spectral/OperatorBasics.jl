#
""" Common Operator Interface """

#TODO - get rank of operator
#function LinearAlgebra.rank()

# operator application
function (A::AbstractOperator{Ta,N})(u::AbstractArray) where{Ta,N}
  # replace arg with u::AbstractField{Tb,N}
  if issquare(A)
    mul!(similar(u),A,u)
  else
    ArgumentError("Operator application not defined for $A")
  end
end

Base.:*(A::AbstractOperator{Ta,N}, u::AbstractField{Tu,N}) where{Ta,Tu,N} = A(u)

# fusing operators
function Base.:*(A::AbstractOperator, B::AbstractOperator)
  @error "Fusing operation not defined for $A * $B. Try lazy composition with ∘"
end

# caching
function init_cache(A::AbstractOperator,u)
  @error "Caching behaviour not defined for $A"
end

function set_cache(A::AbstractOperator, cache)
  @set! A.cache = cache
  @set! A.isfresh = false
  return A
end

Base.size(t::AbstractOperator, d) where {T,N} = d::Integer <= 2 ? size(t)[d] : 1

"""
check LazyArrays.jl, LinearOperators/CompositeLinearOperators

for lazy/eager misc operations
"""

""" lazy misc operations """
struct CompositeLinearOperator{T,N} <: AbstractOperator{T,N}
end

""" eager fusing misc operations with AbstractOperators"""
struct CompositeLinearOperator{T,N} <: AbstractOperator{T,N}
end

# lazy

## TODO +, - operations on AbstractOperators
#LinearAlgebra.:rmul!(A::DiagonalOp,b::Number) = rmul!(A.diag,b)
#LinearAlgebra.:lmul!(a::Number,B::DiagonalOp) = lmul!(a,B.diag)

#for op in (
#           :+ , :- , :* , :/ , :\ ,
#          )
#  @eval Base.$op(u::AbstractOperator , v::Number) = $op(u.array, v)
#  @eval Base.$op(u::Number, v::AbstractOperator ) = $op(u, v.array)
#end

""" Identity Operator with the notion of size """
struct Identity{N,Tn} <: AbstractOperator{Bool, N}
  n::Tn # tuple of sizes
  #
  function Identity(n...)
    N = length(n)
    new{N,typeof(n)}(n)
  end
end
function Base.size(Id::Identity)
  n = prod(Id.n)
  (n,n)
end
Base.adjoint(Id::Identity) = Id
#
LinearAlgebra.mul!(v, ::Identity, u) = copy!(v, u)
LinearAlgebra.ldiv!(v, ::Identity, u) = copy!(v, u)
LinearAlgebra.ldiv!(id::Identity, u) = u

# fusing
Base.:*(::Identity{N,Tn}, A::AbstractOperator{T,N}) where{N,Tn,T} = A
Base.:*(A::AbstractOperator{T,N}, ::Identity{N,Tn}) where{N,Tn,T} = A

"""
ToArrayOp
use RecursiveArrayTools.jl: ArrayPartition, ComponentArrays.jl instead
"""
struct ToArrayOp{N,Tn} <: AbstractOperator{Bool,N}
  n::Tn # tuple of sizes
  #
  function ToArrayOp(n...)
    N = length(n)
    new{N,typeof(n)}(n)
  end
end
Base.size(C::ToArrayOp) = (C.n,C.n)

(C::ToArrayOp)(u) = fill(u, (1,))
(C::Adjoint{Bool, ToArrayOp})(u) = first(u)
LinearAlgebra.mul!(v, C::ToArrayOp, u) = copy!(first(v),u)
LinearAlgebra.ldiv!(v, C::ToArrayOp, u) = first(u)

""" Lazy Composition """
struct ComposeOperator{T,N,Ti,To,Tc} <: AbstractOperator{T,N}
  inner::Ti
  outer::To
  #
  cache::Tc
  isfresh::Bool
  #
  function ComposeOperator(inner::AbstractOperator{Ti,N},
                           outer::AbstractOperator{To,N},
                           cache = nothing,
                           isfresh::Bool = cache === nothing
                          ) where{Ti,To,N}
    @assert size(outer, 1) == size(inner, 2)
    T = promote_type(Ti, To)
    isfresh = cache === nothing
    new{T,N,typeof(inner),typeof(outer),typeof(cache)}(inner, outer, cache, isfresh)
  end
end

function Base.:∘(outer::AbstractOperator,
                 inner::AbstractOperator)
  ComposeOperator(inner,outer)
end

Base.size(A::ComposeOperator) = (size(A.outer, 1), size(A.inner, 2))
Base.adjoint(A::ComposeOperator) = A.inner' ∘ A.outer'
Base.inv(A::ComposeOperator) = inv(A.inner) ∘ inv(A.outer)

function init_cache(A::ComposeOperator, u)
  cache = A.inner(u)
  return cache
end

function (A::ComposeOperator)(u)
  if A.isfresh
    cache = init_cache(A, x)
    A = set_cache(A, cache)
    return outer(cache)
  end
  mul!(cache, inner, u)
  outer(cache)
end

function LinearAlgebra.mul!(y, A::ComposeOperator, x)
  if A.isfresh
    cache = init_cache(A, x)
    A = set_cache(A, cache)
    return mul!(y, outer, cache)
  end

  mul!(cache, inner, x)
  mul!(y, outer, cache)
end

function LinearAlgebra.ldiv!(A::ComposeOperator, x)
  @unpack inner, outer = A

  ldiv!(inner, x)
  ldiv!(outer, x)
end

function LinearAlgebra.ldiv!(y, A::ComposeOperator, x)
  @unpack inner, outer = A

  ldiv!(y, inner, x)
  ldiv!(outer, y)
end

""" InverseOperator """
struct InverseOperator{T,N,Ta} <: AbstractOperator{T,N}
  A::Ta
  #
  function InverseOperator(A::AbstractOperator{T,N}) where{T,N}
    @assert issquare(A)
    LinearAlgebra.checksquare(A)
    new{T,N,typeof(A)}(A)
  end
end

Base.inv(A::AbstractOperator) = InverseOperator(A)
Base.size(A::InverseOperator) = size(A.A)
Base.adjoint(A::InverseOperator) = inv(A.A')
LinearAlgebra.ldiv!(y, A::InverseOperator, x) = mul!(y, A.A, x)
LinearAlgebra.mul!(y, A::InverseOperator, x) = ldiv!(y, A.A, x)
#
