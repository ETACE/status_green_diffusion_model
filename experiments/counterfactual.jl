using Statistics

include("initialization.jl")
include("data_collection.jl")

folder = "counterfactual"
simulation_time = 160
burn_in_time = baseline_properties[:burn_in_time]
no_runs = 100
run_aggregation = []

# Define experiments
experiments = Dict(
    "only_base" => Dict(:eco_base_class => 1, :eco_lux_class => 1, :eco_mid_class => 1, :eco_base_name => "Eco Base", :eco_lux_name => "Eco Base", :eco_mid_name => "Eco Base")
)


