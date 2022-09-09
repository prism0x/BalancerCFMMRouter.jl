@doc raw"""
    SwapObjective(i, Δin)

Liquidation objective for the routing problem,
```math
    \Psi_i - \mathbf{I}(\Psi_{-i} + Δ^\mathrm{in}_{-i} = 0, ~ \Psi_i \geq 0),
```
where `i` is the desired output token and `Δin` is the basket of tokens to be liquidated.
"""
struct SwapObjective{T} <: Objective
    i::Int
    Δin::Vector{T}

    function SwapObjective(i::Integer, Δin::Vector{T}) where {T <: AbstractFloat}
        !(i > 0 && i <= length(Δin)) && throw(ArgumentError("Invalid index i"))
        return new{T}(
            i,
            Δin,
        )
    end
end
SwapObjective(i::Integer, Δin::Vector{T}) where {T <: Real} = SwapObjective(i, Float64.(Δin))

function f(obj::SwapObjective{T}, v) where {T}
    if v[obj.i] >= 1.0
        return sum(i->(i == obj.i ? 0.0 : obj.Δin[i]*v[i]), 1:length(v))
    end
    return convert(T, Inf)
end

function grad!(g, obj::SwapObjective{T}, v) where {T}
    if v[obj.i] >= 1.0
        g .= obj.Δin
        g[obj.i] = zero(T)
    else
        g .= convert(T, Inf)
    end
    return nothing
end

@inline function lower_limit(o::SwapObjective{T}) where {T}
    ret = Vector{T}(undef, length(o.Δin))
    fill!(ret, eps())
    ret[o.i] = one(T) + eps()
    println("Lower_bound ", ret)
    return ret
end

@inline upper_limit(o::SwapObjective{T}) where {T} = convert(T, Inf) .+ zero(o.Δin)

# @inline function upper_limit(o::SwapObjective{T}) where {T}
#     ret = o.Δin
#     ret[o.i] = convert(T, Inf)
#     return ret
# end