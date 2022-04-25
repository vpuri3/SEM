#
module Spectral

using Reexport

@reexport using LinearAlgebra
@reexport using LinearSolve
@reexport using UnPack: @unpack
@reexport using Setfield: @set!
@reexport using SciMLBase

import Base.ReshapedArray
import SciMLBase: AbstractDiffEqOperator
import Lazy: @forward

import SparseArrays: sparse
import NNlib: gather, scatter
import FastGaussQuadrature: gausslobatto, gausslegendre, gausschebyshev
import FFTW: plan_rfft, plan_irfft

# AbstractVector subtypes
import Base: summary, show, similar, zero, one
import Base: size, getindex, setindex!, IndexStyle
import Base.Broadcast: BroadcastStyle

# overload maths
import Base: +, -, *, /, \, adjoint, ∘, inv
import LinearAlgebra: mul!, ldiv!, lmul!, rmul!

""" Scalar function field in D-Dimensional space """
abstract type AbstractField{T,D} <: AbstractVector{T} end
""" Operators acting on fields in D-Dimensional space """
abstract type AbstractOperator{T,D} <: AbstractDiffEqOperator{T} end
""" D-Dimensional physical domain """
abstract type AbstractDomain{T,D} end
""" Function space in D-Dimensional space """
abstract type AbstractSpace{T,D} end
""" Boundary condition on domain in D-Dimensional space """
abstract type AbstractBonudaryCondition{T,D} end


""" Scalar function field in D-Dimensional space over spectral basis """
abstract type AbstractSpectralField{T,D} <: AbstractField{T,D} end
""" Operators acting on fields in D-Dimensional space over a spectral basis"""
abstract type AbstractSpectralOperator{T,D} <: AbstractOperator{T,D} end
""" Spectral function space in D-Dimensional space """
abstract type AbstractSpectralSpace{T,D} <: AbstractSpace{T,D} end

AbstractSupertypes{T,D} = Union{
                                AbstractField{T,D},
                                AbstractOperator{T,D},
                                AbstractSpace{T,D},
                                AbstractDomain{T,D},
                                AbstractBonudaryCondition{T,D}
                               }

Base.eltype(::AbstractSupertypes{T,D}) where{T,D} = T
dims(::AbstractSupertypes{T,D}) where{T,D} = D

include("utils.jl")
include("Field.jl")
include("OperatorBasics.jl")
include("Operators.jl")
include("Domain.jl")
include("Space.jl")
include("DeformSpace.jl")

include("NDgrid.jl")
include("LagrangeMats.jl")
#include("LagrangePoly.jl")
#include("Fourier.jl")

export 
       # fields
       Field,

       # operator conveniences
       IdentityOp, NullOp, AffineOp, ComposeOp, InverseOp, # overload op(u,p,t)

       # Concrete operators
       MatrixOp, DiagonalOp, TensorProductOp2D,

       # Domains
       Interval, BoxDomain,

       # spaces
       GaussLobattoLegendre2D, GaussLegendre2D, GaussChebychev2D

end # module
