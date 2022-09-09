using ArgParse
using JSON
# using CFMMRouter
include("CFMMRouterExtended.jl")
# using LinearAlgebra

# println(pathof(CFMMRouter))
# exit()
# include("objective.jl")

@enum swapType begin
    SwapExactIn = 1
    SwapExactOut = 2
end

struct TokenData
    index::UInt
    decimals::UInt
end

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

    if parsed_args["type"] == "SwapExactIn"
        type = SwapExactIn
    elseif parsed_args["type"] == "SwapExactOut"
        type = SwapExactOut
    else
        throw(ErrorException("Unknown swap type: " * parsed_args["type"]))
    end

    try
        quantity = parse(BigInt, parsed_args["quantity"])
    catch
        throw(ErrorException("Token amount not formatted properly: " * parsed_args["quantity"]))
    end

    sorRoute(
        poolsContent,
        parsed_args["tokenIn"],
        parsed_args["tokenOut"],
        parse(BigInt, parsed_args["quantity"]),
        type
    )
end

function sorRoute(poolsContent::String, tokenIn::String, tokenOut::String, quantity::BigInt, type::swapType)

    if type != SwapExactIn
        throw(ErrorException("Only SwapExactIn is supported yet."))
    end

    poolsData = JSON.parse(poolsContent)

    poolArray = []
    @assert isa(poolsData, Array{Any}) # Check that JSON data is an array of pools

    tokenDataDict = getTokenDataDict(poolsData)
    n_tokens = length(tokenDataDict)

    pools = Vector{CFMM{Float64}}()
    for p in poolsData
        pool = createPool(p, tokenDataDict)
        push!(pools, pool)
    end

    tokenInData = tokenDataDict[tokenIn]
    tokenOutData = tokenDataDict[tokenOut]

    inputBasket = zeros(Float64, n_tokens)
    inputBasket[tokenInData.index] = quantity / 10^(tokenInData.decimals)

    obj = SwapObjective(tokenOutData.index, inputBasket)
    # Build a routing problem with unit price vector
    router = Router(
        # LinearNonnegative(prices),
        # BasketLiquidation(tokenOutData.index, inputBasket),
        obj,
        pools,
        n_tokens,
    )

    ## Optimize!
    route!(router)
    println("ASDASDASD ", router)

    # ## Print results
    # Ψ = round.(Int, netflows(router))
    # println("Net trade: $Ψ")
    # println("Profit: $(dot(prices, Ψ))")

    Ψ = netflows(router)
    println("Input Basket: $inputBasket")
    println("Net trade: $Ψ")
    println("Amount recieved: $(Ψ[tokenOutData.index])")

end

function getTokenDataDict(poolsData)
    # Returns Dict(tokenAddress => tokenIndex)

    tokenDataDict = Dict{String,TokenData}()
    currentIdx = 1

    for poolData in poolsData
        for token in poolData["tokens"]
            if !haskey(tokenDataDict, token["address"])
                tokenDataDict[token["address"]] = TokenData(currentIdx, token["decimals"])
                currentIdx += 1
            end
        end
    end

    return tokenDataDict
end

function createPool(poolData, tokenDataDict)::CFMM{Float64}
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
            push!(indices, tokenDataDict[tokenData["address"]].index)
        end

        # println(indices, weights, balances)
        swapFee = parse(Float64, poolData["swapFee"])
        return GeometricMeanNCoin(balances, weights, 1 - swapFee, indices)

    elseif poolType == "MetaStable"
        throw(ErrorException("Pool type not implemented yet"))
    else
        throw(ErrorException("Unknown pool type: " + poolType))
    end

end

main(ARGS)