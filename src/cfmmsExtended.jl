@def add_n_coin_fields begin
    R::Vector{T}
    γ::T
    Ai::Vector{Int}
    n_coin::UInt
end

# n-coin specific cases
function n_coin_check_cast(R, γ, idx)
    length(idx) != length(R) && throw(ArgumentError("length of idx must be equal to the length of R"))

    T = eltype(R)

    if T <: Integer
        T = Float64
    end

    γ_T = convert(T, γ)
    idx_uint = convert.(UInt, idx)

    return γ_T, idx_uint, T
end

@doc raw"""
    GeometricMeanNCoin(R, γ, idx, w)

Creates an n-coin geometric mean CFMM with coins `idx[1]` and `idx[2]`,
reserves `R`, fee `γ`, and weights `w` such that `w[1] + w[2] == 1.0`.
Specifically, the invariant is
```math
\varphi(R) = R_1^{w_1}R_2^{w_2}.
```
"""
struct GeometricMeanNCoin{T} <: CFMM{T}
    @add_n_coin_fields
    w::Vector{T}
    function GeometricMeanNCoin(R, w, γ, idx)
        γ_T, idx_uint, T = n_coin_check_cast(R, γ, idx)
        n_coin = length(R)
        return new{T}(
            Vector{T}(R),
            γ_T,
            Vector{UInt}(idx_uint),
            n_coin,
            Vector{T}(w),
        )
    end
end

function ϕ(cfmm::GeometricMeanNCoin; R=nothing)
    R = isnothing(R) ? cfmm.R : R
    w = cfmm.w
    k = 1
    for i = 1:cfmm.n_coin
        k *= R[i]^w[i]
    end
    return k
end
function ∇ϕ!(R⁺, cfmm::GeometricMeanNCoin; R=nothing)
    R = isnothing(R) ? cfmm.R : R
    w = cfmm.w
    for i = 1:cfmm.n_coin
        R⁺[i] = w[i] / R[i]^(1 - w[i])
        for j = 1:cfmm.n_coin
            if i == j
                continue
            end
            R⁺[i] = R⁺[i] * R[j]^w[j]
        end
    end
    return nothing
end

# @inline geom_arb_δ(m, r1, r2, η, γ) = max((γ * m * η * r1 * r2^η)^(1 / (η + 1)) - r2, 0) / γ
# @inline geom_arb_λ(m, r1, r2, η, γ) = max(r1 - ((r2 * r1^(1 / η)) / (η * γ * m))^(η / (1 + η)), 0)

function get_trade_function(cfmm::GeometricMeanNCoin)
    function f(R_...)
        return ϕ(cfmm, R=R_)
    end
    return f
end

# Solves the maximum arbitrage problem for the n-coin geometric mean case.
# Assumes that v > 0 and w > 0.
function find_arb!(Δ::VT, Λ::VT, cfmm::GeometricMeanNCoin{T}, v::VT) where {T,VT<:AbstractVector{T}}
    R, γ, w = cfmm.R, cfmm.γ, cfmm.w

    ϕ_ = get_trade_function(cfmm)
    Δ_, Λ_ = find_arb_jump(ϕ_, R, v, γ)

    Δ .= Δ_
    Λ .= Λ_
    # η = w[1] / w[2]

    # Δ[1] = geom_arb_δ(v[2] / v[1], R[2], R[1], η, γ)
    # Δ[2] = geom_arb_δ(v[1] / v[2], R[1], R[2], 1 / η, γ)

    # Λ[1] = geom_arb_λ(v[1] / v[2], R[1], R[2], 1 / η, γ)
    # Λ[2] = geom_arb_λ(v[2] / v[1], R[2], R[1], η, γ)
    return nothing
end


