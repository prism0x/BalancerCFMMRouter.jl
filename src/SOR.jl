using ArgParse
using JSON
using CFMMRouter
using LinearAlgebra

function main(args)

    # initialize the settings (the description is for the help screen)
    s = ArgParseSettings(description="An Balancer SOR like interface to CFMMRouter.jl")

    @add_arg_table! s begin
        "--pools", "-p"
        help = "JSON file that contains pool information"
        required = true
        "--tokenIn", "-i"
        help = "Address of the input token."
        required = true
        "--tokenOut", "-o"
        help = "Address of the output token."
        required = true
        "--quantity", "-q"
        help = "Swap quantity."
        required = true
        "--type", "-t"
        help = "Swap type."
        required = true

    end

    parsed_args = parse_args(s) # the result is a Dict{String,Any}
    println("Parsed args:")
    for (key, val) in parsed_args
        println("  $key  =>  $(repr(val))")
    end

    poolsContent = read(open(parsed_args["pools"], "r"), String)
    poolsData = JSON.parse(poolsContent)
    # println(poolsData[1])

    poolArray = []
    @assert isa(poolsData, Array{Any}) # Check that JSON data is an array of pools

    tokenIndices = getTokenIndices(poolsData)
    n_tokens = length(tokenIndices)
    println(tokenIndices)

    pools = Vector{CFMM{Float64}}()
    for p in poolsData
        pool = createPool(p, tokenIndices)
        push!(pools, pool)
    end

    # Build a routing problem with unit price vector
    prices = ones(n_tokens)
    router = Router(
        LinearNonnegative(prices),
        pools,
        2,
    )

    ## Optimize!
    route!(router)

    ## Print results
    Ψ = round.(Int, netflows(router))
    println("Net trade: $Ψ")
    println("Profit: $(dot(prices, Ψ))")

end

function getTokenIndices(poolsData)
    # Returns Dict(tokenAddress => tokenIndex)

    tokenIndices = Dict{String, Int}()
    currentIdx = 1

    for poolData in poolsData
        for tokenData in poolData["tokens"]
            if !haskey(tokenIndices, tokenData["address"])
                tokenIndices[tokenData["address"]] = currentIdx
                currentIdx += 1
            end
        end
    end

    return tokenIndices
end

function createPool(poolData, tokenIndices) :: CFMM{Float64}
    poolType = poolData["poolType"]

    for tokenData in poolData["tokens"]
        if parse(Float64, tokenData["priceRate"]) != 1
            println("Tokens with price rate != 1 are not supported yet")
        end
    end


    if poolType == "Weighted"
        if length(poolData["tokens"]) > 2
            throw(ErrorException("Weighted pools with more than two tokens are not supported yet"))
        end

        weights = Vector{Float64}()
        balances = Vector{Float64}()
        indices = Vector{Int}()

        for tokenData in poolData["tokens"]
            push!(weights, parse(Float64, tokenData["weight"]))
            push!(balances, parse(Float64, tokenData["balance"]))
            push!(indices, tokenIndices[tokenData["address"]])
        end

        # println(indices, weights, balances)
        swapFee = parse(Float64, poolData["swapFee"])
        return GeometricMeanTwoCoin(balances, weights, 1 - swapFee, indices)

    elseif poolType == "MetaStable"
        throw(ErrorException("Pool type not implemented yet"))
    else
        throw(ErrorException("Unknown pool type: " + poolType))
    end

end

main(ARGS)