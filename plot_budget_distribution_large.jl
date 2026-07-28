using Serialization, ArgParse, SkipNan, Statistics
using Plots,TensorCast, Colors

include("model/model.jl")
include("experiments/initialization.jl")
include("experiments/baseline.jl")
include("experiments/budget_distribution_large.jl")

# ===============================================
const GRID_COLOR   = "#F2F2F2"
const STAGES_COLOR = "#BFBFBF" 

Plots.default(
    grid       = true,
    gridcolor  = GRID_COLOR,
    gridalpha  = 1.0,
    gridstyle  = :solid,
    foreground_color_grid = GRID_COLOR,
    fontfamily = "Computer Modern",
)
# ================================================


# Define length of x-axis
n_quarterly = simulation_time - burn_in_time
x_quarterly = 0:(n_quarterly)

n_yearly = Int(floor(n_quarterly/4))
x_yearly = 0:(n_yearly-1)

#load data from conducted experiment 
function load_dataset(folder)
	folder_data = "data/$folder"

	results = []
	chunk = 0
	while isfile("$folder_data/data-$(chunk+=1).dat")
		append!(results, deserialize("$folder_data/data-$chunk.dat"))
	end

	if length(results) == 0
		println("ERROR: No data found in $folder_data")
		exit(1)
	end

	return results
end

function merge_data(results, experiments; burn_in_months = burn_in_time)
    data = Dict{String, Vector{DataFrame}}()

    for (exp_name, _) in experiments
        data[exp_name] = Vector{DataFrame}()

        for r in results
            if r[:exp_name] == exp_name
                plot_it = size(r[:model_data], 1)
                if plot_it <= burn_in_months
                    @warn "Run hat nur $plot_it Zeilen, aber burn_in_months=$burn_in_months — Run wird übersprungen"
                    continue
                end
                df = r[:model_data][burn_in_months + 1:plot_it, :]
                push!(data[exp_name], df)
            end
        end
    end

    return data
end

function get_data_exp_key(data, exp, key)
	data_exp_key=[]
	#for each run of one experiment get all the data of a specific key

	for i in 1:length(data[exp])
		append!(data_exp_key, [data[exp][i][!,key]])
	end
	return data_exp_key
end

function get_mean_upper_lower(data, conf_level=0.25)
	#transpose data 
    @cast data_t[i][j] := data[j][i]

	mean_data = []
	upper =[]
	lower = []

	#take the mean over all rows 
	for i in 1:length(data_t)
		vals = skipnan(data_t[i])

		if !isempty(vals)
			m = mean(vals)
			push!(mean_data, m)

			q_high = quantile(vals, 1-conf_level/2)
			q_low = quantile(vals, conf_level/2)

			push!(upper, q_high - m)
			push!(lower, m - q_low)
		
		else
			push!(mean_data, NaN)
			push!(upper, NaN)
			push!(lower, NaN)
		end
	end

	return mean_data, upper, lower
end

function add_series_with_ribbon!(pl, x, series, color, label)
	mean_data, upper, lower = get_mean_upper_lower(series)
	plot!(pl,x, mean_data, color=color, label=label, linewidth=1, ribbon = (lower, upper))
	return pl
end

# Load experiment data
results_base = load_dataset("baseline")
results_dist = load_dataset("budget_distribution_large")

experiments_base = Dict("baseline" => Dict())
experiments_dist = Dict(
    "gini_0" => Dict(:beta_scaling1 => 10000, :beta_scaling2 => 10),
    "gini_1" => Dict(:beta_scaling1 => 6, :beta_scaling2 => 2),
    "gini_2" => Dict(:beta_scaling1 => 5, :beta_scaling2 => 10),
    "gini_4" => Dict(:beta_scaling1 => 1.25, :beta_scaling2 => 4.5),
    "gini_5" => Dict(:beta_scaling1 => 0.75, :beta_scaling2 => 4),
    "gini_6" => Dict(:beta_scaling1 => 0.46, :beta_scaling2 => 3)
)

data_base = merge_data(results_base, experiments_base)
data_dist = merge_data(results_dist, experiments_dist)

data = mergewith(vcat, data_base, data_dist)

name = "budget_distribution_large"
mkpath("plots/$name/")

pl = plot(title = "", size=(700, 450))

means = Float64[]
lower_errors = Float64[]
upper_errors = Float64[]
gini_values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]

experiments = ["gini_1", "gini_2", "baseline", "gini_4", "gini_5", "gini_6"]

for exp in experiments
    series = deepcopy(get_data_exp_key(data, exp, "ev_share_sales"))

    mean_data, upper, lower = get_mean_upper_lower(series)
    final_mean = mean_data[end]
    push!(means, final_mean)

    push!(lower_errors, lower[end])
    push!(upper_errors, upper[end])
end

plot!(pl,
    gini_values,
    means,
    yerror=(lower_errors, upper_errors),
    seriestype=:scatter,
    color="lightgrey",
    markerstrokewidth=0,
    label="")

plot!(pl,
    gini_values,
    means,
    linecolor="royalblue",
    markercolor="royalblue",
    label="EV share",
    marker=:circle,
    markersize=5,
    markerstrokewidth=0,
    linewidth=2)


savefig(pl, "plots/$name/ev_share_dist.pdf")



pl = plot(title = "", fontfamily = "Computer Modern", size=(700, 450))

means = Float64[]
lower_errors = Float64[]
upper_errors = Float64[]
gini_values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6]

experiments = ["gini_1", "gini_2", "baseline", "gini_4", "gini_5", "gini_6"]

empty!(means)
empty!(lower_errors)
empty!(upper_errors)


for exp in experiments
    series = deepcopy(get_data_exp_key(data, exp, "market_penetration"))

    mean_data, upper, lower = get_mean_upper_lower(series)
    final_mean = mean_data[end]
    push!(means, final_mean)

    push!(lower_errors, lower[end])
    push!(upper_errors, upper[end])
end

plot!(pl,
    gini_values,
    means,
    yerror=(lower_errors, upper_errors),
    seriestype=:scatter,
    color="lightgrey",
    markerstrokewidth=0,
    label=""
)

plot!(pl,
    gini_values,
    means,
    linecolor="royalblue",
    markercolor="royalblue",
    label="Market penetration",
    marker=:circle,
    markersize=5,
    markerstrokewidth=0,
    linewidth=2
)

savefig(pl, "plots/$name/market_penetration_dist.pdf")