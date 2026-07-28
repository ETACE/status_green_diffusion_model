using Statistics

include("initialization.jl")
include("data_collection.jl")

folder = "market_structure"
simulation_time = 160
burn_in_time = baseline_properties[:burn_in_time]
no_runs = 100
run_aggregation = []

# Define experiments
experiments = Dict(
    "low_prestige" => Dict(:firm_classes => [1, 1, 1, 2, 2, 2, 3, 4]),
    "high_prestige" => Dict(:firm_classes => [2, 3, 4, 4, 4, 5, 5, 5]),
)


