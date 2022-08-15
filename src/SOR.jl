using ArgParse
using JSON

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
    pools = JSON.parse(poolsContent)
    println(poolsContent)

end

main(ARGS)