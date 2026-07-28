using Statistics

include("initialization.jl")
include("data_collection.jl")

folder = "budget_distribution"
simulation_time = 160
burn_in_time = baseline_properties[:burn_in_time]
no_runs = 100
run_aggregation = []

# Define experiments
experiments = Dict(
    "more_equal" => Dict(:beta_scaling1 => 6, :beta_scaling2 => 2),
    "more_unequal" => Dict(:beta_scaling1 => 0.75, :beta_scaling2 => 4),
)


