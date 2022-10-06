using LinearAlgebra, Ipopt, JuMP

# R = [100.0, 80.0, 50.0]
# π = [0.9, 1.2, 1.3]

# R1 = [100.0, 90.0]
# R2 = [105.0, 95.0]
# π = [1.0, 0.9]

# A = 10000.0
# A = 10.0

# γ = 0.996
# γ = 1.

# ϕ(α, R...) = sum(R) - α / prod(R)
# ϕ(α, R...) = solve_D(R, A)
# ϕ(α, R...) = prod(R)
# ϕ(α, R...) = sum(R)


# function ∇ϕ(R, α)
#     return ForwardDiff.gradient(x -> ϕ(x, α), R)
# end

# # Solve D for given reserves. Taken from the Python mockup:
# # https://github.com/curvefi/curve-contract/blob/b0bbf77f8f93c9c5f4e415bce9cd71f0cdee960e/tests/simulation.py#L30-L52
# function solve_D(R, A, tol=1e-12)
#     Dprev = 0
#     n = length(R)
#     S = sum(R)
#     D = S
#     Ann = A * n^n
#     while abs(D - Dprev) > tol
#         D_P = D
#         for x in R
#             D_P = D_P * D / (n * x)
#         end
#         Dprev = D
#         D = (Ann * S + D_P * n) * D / ((Ann - 1) * D + (n + 1) * D_P)
#     end
#     return D
# end

# function get_trade_function(R::Vector{Float64}, A)
#     n = length(R)
#     D = solve_D(R, A)
#     α = D^(n + 1) / (A * n^(2 * n))

#     function ϕ(R_...)
#         return sum(R_) - α / prod(R_)
#     end
#     return ϕ
# end

# Solves the maximum arbitrage problem for the generic Stableswap case.
function find_arb_jump(
    ϕ::Function,
    R::Vector{Float64},
    π::Vector{Float64},
    γ::Float64,
)
    println("#############################")
    println("Solution requested")
    println("R = ", R)
    println("π = ", π)

    n = length(R)
    model = Model(Ipopt.Optimizer; add_bridges=false)
    register(model, :ϕ, n, ϕ; autodiff=true)

    @variable(model, Δ[1:n] >= 0)
    @variable(model, Λ[1:n] >= 0)

    ex1 = @NLexpression(model, [i = 1:n], R[i] + Δ[i] - Λ[i] / γ)
    # ex1 = @NLexpression(model, [i = 1:n], R[i] + γ * Δ[i] - Λ[i])
    # @NLconstraint(model, ϕ(R + Δ - Λ / γ) >= ϕ(R))
    @NLconstraint(model, ϕ(ex1...) >= ϕ(R...))
    @NLconstraint(model, [i = 1:n], Δ[i] * Λ[i] == 0)
    @NLconstraint(model, [i=1:n], ex1[i] >= 0)

    @objective(model, Max, sum(π[i] * (Λ[i] - Δ[i]) for i = 1:n))
    optimize!(model)

    Δ_ = value.(Δ)
    Λ_ = value.(Λ)

    print(model)
    println("Objective value: ", objective_value(model))
    println("Δ = ", Δ_)
    println("Λ = ", Λ_)

    R_new = R + Δ_ - Λ_ / γ

    println("R                = ", R)
    println("R + Δ - Λ / γ    = ", R_new)
    println("ϕ(R)             = ", ϕ(R...))
    println("ϕ(R + Δ - Λ / γ) = ", ϕ(R_new...))

    # exit()

    return Δ_, Λ_
end

# R1 = [100.0, 150.0]
# ϕ = get_ϕ(R1, A)

# println(ϕ(R1))
# find_arb_jump(ϕ, R1, π, γ)
# find_arb(R2, π, A, γ)
