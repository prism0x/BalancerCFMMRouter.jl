# include("CFMMRouter.jl")

using CFMMRouter
using Documenter
using LinearAlgebra, SparseArrays, StaticArrays
using LBFGSB
using Printf

CFMMRouterDir = dirname(pathof(CFMMRouter))

include(CFMMRouterDir * "/utils.jl")
include(CFMMRouterDir * "/cfmms.jl")
include(CFMMRouterDir * "/objectives.jl")
include("objectivesExtended.jl")
include(CFMMRouterDir * "/router.jl")
