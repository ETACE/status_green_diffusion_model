using Statistics

include("initialization.jl")
include("data_collection_small.jl")

folder = "budget_distribution_large"
simulation_time = 160
burn_in_time = baseline_properties[:burn_in_time]
no_runs = 100
run_aggregation = []

# Define experiments
experiments = Dict(
    "gini_0" => Dict(:beta_scaling1 => 10000, :beta_scaling2 => 10),
    "gini_1" => Dict(:beta_scaling1 => 6, :beta_scaling2 => 2),
    "gini_2" => Dict(:beta_scaling1 => 5, :beta_scaling2 => 10),
    "gini_4" => Dict(:beta_scaling1 => 1.25, :beta_scaling2 => 4.5),
    "gini_5" => Dict(:beta_scaling1 => 0.75, :beta_scaling2 => 4),
    "gini_6" => Dict(:beta_scaling1 => 0.46, :beta_scaling2 => 3)
)
