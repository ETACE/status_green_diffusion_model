using Statistics

include("initialization.jl")
include("data_collection.jl")

folder = "policy"
simulation_time = 160
burn_in_time = baseline_properties[:burn_in_time]
no_runs = 100
run_aggregation = []

# Define experiments
experiments = Dict(
    "no_policy" => Dict(:enable_green_subsidy => false, :enable_tax_exemption => false)
)


