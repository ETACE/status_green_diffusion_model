using Serialization, ArgParse, SkipNan, Statistics
using Plots,TensorCast, Colors

include("model/model.jl")
include("experiments/initialization.jl")
include("experiments/baseline.jl")
include("experiments/counterfactual.jl")

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


function plot_comparison(data, exp1, key1, exp2, key2, title, color1, color2, label1, label2, ribbon, yearly, stages)
	series1 = deepcopy(get_data_exp_key(data, exp1, key1))
	series2 = deepcopy(get_data_exp_key(data, exp2, key2))

	x = x_quarterly
    if yearly
        series1 = transform_into_yearly(series1)
		series2 = transform_into_yearly(series2)
        x = x_yearly
    end

	pl = plot(title="", fontfamily="Computer Modern", size=(700, 450))

	if ribbon 
		add_series_with_ribbon!(pl, x, series1, color1, label1)
		add_series_with_ribbon!(pl, x, series2, color2, label2)
	else
		plot!(pl,x,series1, color=color1,label=label1)
		plot!(pl,x,series2, color=color2,label=label2)
	end

	if stages && !yearly
        vline!(pl, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label = "")
    elseif stages && yearly
        vline!(pl, [0, 1, 2, 7], linestyle=:dash, color=STAGES_COLOR, label = "")
    end

	return pl
end

function plot_single(data,exp,key,title,color,label,ribbon, yearly, stages)
	series = deepcopy(get_data_exp_key(data, exp, key))

    x = x_quarterly
    if yearly
        series = transform_into_yearly(series)
        x = x_yearly
    end

	pl = plot(title="", fontfamily="Computer Modern", size=(700, 450))

	if ribbon 
		add_series_with_ribbon!(pl, x, series, color, label)
	else
		plot!(pl,x,series,color=color,label=label,linewidth=1)
	end

    if stages && !yearly
        vline!(pl, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label = "")
    elseif stages && yearly
        vline!(pl, [0, 1, 2, 7], linestyle=:dash, color=STAGES_COLOR, label = "")
    end

	return pl
end


function plot_by_firm(data, exp, keyset, title, labelset, colorpalette, linestyles, lim, yearly, stages)
    pl = plot(title="", fontfamily="Computer Modern", size=(700, 450))


    seen = Dict{Tuple{String,Symbol}, Bool}()
    ordered_groups = Tuple{String,Symbol}[]
    group_to_firms = Dict{Tuple{String,Symbol}, Vector{Int}}()

    for i in 1:length(keyset)
        key = (string(colorpalette[i]), linestyles[i])
        if !haskey(seen, key)
            seen[key] = true
            push!(ordered_groups, key)
            group_to_firms[key] = Int[]
        end
        push!(group_to_firms[key], i)
    end

    for (col, ls) in ordered_groups
        firm_indices = group_to_firms[(col, ls)]

        class_series_all = []
        for i in firm_indices
            s = deepcopy(get_data_exp_key(data, exp, keyset[i]))
            if yearly
                s = transform_into_yearly(s)
            end
            push!(class_series_all, s)
        end

        n_runs = length(class_series_all[1])
        n_time = length(class_series_all[1][1])

        mean_series = Float64[]
        for t in 1:n_time
            vals = Float64[]
            for r in 1:n_runs
                for firm_s in class_series_all
                    v = firm_s[r][t]
                    if !isnan(v)
                        push!(vals, v)
                    end
                end
            end
            push!(mean_series, isempty(vals) ? NaN : mean(vals))
        end

        x = yearly ? x_yearly : x_quarterly

        lbl = ""
        for i in firm_indices
            if labelset[i] != ""
                lbl = labelset[i]
                break
            end
        end

        if lim
            plot!(pl, x, mean_series, color=col, linestyle=ls, label=lbl, ylim=(0,1))
        else
            plot!(pl, x, mean_series, color=col, linestyle=ls, label=lbl)
        end
    end

    if stages && !yearly
        vline!(pl, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label="")
    elseif stages && yearly
        vline!(pl, [0, 1, 2, 7], linestyle=:dash, color=STAGES_COLOR, label="")
    end

    return pl
end

function plot_by_consumption_group(data, exp, keyset, title, labelset, colorpalette, stages)
    pl = plot(title="", fontfamily="Computer Modern", size=(700, 450))
	
	for i in 1:4
		series = deepcopy(get_data_exp_key(data,exp,keyset[i]))
		mean_series = []
        if length(series[1]) > 1
            for j in 1:length(series[1])
                list = Float64[]
                for k in eachindex(series)
                    append!(list,[series[k][j]])
                end
                push!(mean_series,mean(skipnan(list)))
            end
        else
            mean_series = series
        end

		plot!(pl, x_quarterly, mean_series,color=colorpalette[i],label=labelset[i])

	end

    if stages
        vline!(pl, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label = "")
    end
	
	return pl
end

function extract_attributes(data,exp,keyset)
    attribute_list = []
	
	for i in 1:no_firms
		series = deepcopy(get_data_exp_key(data,exp,keyset[i]))
		mean_series = []
		if length(series[1]) > 1
            for j in 1:length(series[1])
                list = Float64[]
                for k in eachindex(series)
                    append!(list,[series[k][j]])
                end
                push!(mean_series,mean(skipnan(list)))
            end
        else
            mean_series = series
        end
		
        push!(attribute_list, mean_series)		
	end

	return attribute_list
end

function transform_into_yearly(series)
    k = []

    for i in 1:floor((length(series[1])/4))
        push!(k, Int.(i*4))
    end

    for j in eachindex(series)
        keepat!(series[j], k)
    end

    return series
end

# Load experiment data
results_base = load_dataset("baseline")
results_counterfactual = load_dataset("counterfactual")

experiments_base = Dict("baseline" => Dict())
experiments_counterfactual = Dict(
    "only_base" => Dict(:eco_base_class => 1, :eco_lux_class => 1, :eco_mid_class => 1, :eco_base_name => "Eco Base", :eco_lux_name => "Eco Base", :eco_mid_name => "Eco Base")
)

data_base = merge_data(results_base, experiments_base)
data_counterfactual = merge_data(results_counterfactual, experiments_counterfactual)

data = mergewith(vcat, data_base, data_counterfactual)

name = "counterfactual"
mkpath("plots/$name/")



### BASELINE PLOTS ###
colorpalette = ["royalblue","darkorange","seagreen","fuchsia", "red","turquoise", "gold", "purple"]
colorpalette_cons = ["royalblue","darkorange","seagreen","fuchsia"]
labelset_cons = ["Consumer Group 1", "Consumer Group 2","Consumer Group 3","Consumer Group 4"]
brands = baseline_properties[:brand_names]
firm_classes = baseline_properties[:firm_classes] 
number_classes = length(unique(firm_classes))
colorpalette_classes = colorpalette[1:number_classes]
class_linestyles = [:solid, :dash, :dot, :dashdot, :dashdotdot]
colorpalette_grey = ["#E6E6E6","#BFBFBF","#BFBFBF","#BFBFBF","#8C8C8C","#8C8C8C","#595959","#000000","mediumaquamarine","deeppink","darkorange"]

combustion_color = "#595959"

colorpalette_firms = []
labelset_firms_class = []
linestyle_firms = []
seen_classes = Set()

for i in 1:baseline_properties[:n_firms]
    class = firm_classes[i]
    push!(colorpalette_firms, combustion_color)
    push!(linestyle_firms, class_linestyles[class])
    if !(class in seen_classes)
        push!(labelset_firms_class, "Vehicle class $class")
        push!(seen_classes, class)
    else
        push!(labelset_firms_class, "")
    end
end

append!(colorpalette_firms, ["mediumaquamarine", "deeppink", "darkorange"])
append!(linestyle_firms, [:solid, :solid, :solid])
append!(labelset_firms_class, ["Eco Base", "Eco Lux", "Eco Mid"])
no_firms = baseline_properties[:n_firms] + 3
labelset_firms_ind = append!(brands, ["Eco Base", "Eco Lux", "Eco Mid"])

number_eco_base = no_firms - 2
number_eco_lux = no_firms - 1
number_eco_mid = no_firms

### Macro Plots ###
pl = plot_comparison(data, "baseline", "market_penetration", "only_base", "market_penetration", "Market Penetration","royalblue", "darkorange", "Baseline","Only Base", true, false, true)
savefig(pl,"plots/$name/market_penetration_base.pdf")

pl = plot_comparison(data, "baseline", "hh_index", "only_base", "hh_index", "Herfindahl-Hirschman-Index","royalblue", "darkorange", "Baseline","Only Base", true, true, true)
savefig(pl,"plots/$name/hh_index_base.pdf")

pl = plot_comparison(data, "baseline", "average_weighted_price", "only_base", "average_weighted_price", "Average weighted price","royalblue", "darkorange", "Baseline","Only Base", true, true, true)
savefig(pl,"plots/$name/average_weighted_price_base.pdf")

pl = plot_comparison(data, "baseline", "concentration_rate_three", "only_base", "concentration_rate_three", "Concentration Rate (Top 3 Firms)","royalblue", "darkorange", "Baseline","Only Base", true, false, true)
savefig(pl,"plots/$name/concentration_rate_three_base.pdf")

pl = plot_comparison(data, "baseline", "ev_share_sales", "only_base", "ev_share_sales", "EV share","royalblue", "darkorange", "Baseline","Only Base", true, false, true)
savefig(pl,"plots/$name/ev_share_sales_base.pdf")


### Production Side ###
keyset_raw = ["firm_1_first_registration_share", "firm_2_first_registration_share", "firm_3_first_registration_share", "firm_4_first_registration_share", 
		"firm_5_first_registration_share","firm_6_first_registration_share","firm_7_first_registration_share", "firm_8_first_registration_share", 
		"firm_9_first_registration_share", "firm_10_first_registration_share", "firm_11_first_registration_share"]
keyset = keyset_raw[1:no_firms]

pl = plot_by_firm(data, "only_base", keyset, "First Registration Share by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/first_registration_share_by_firm.pdf")

keyset_raw = ["firm_1_brown_capital", "firm_2_brown_capital", "firm_3_brown_capital", "firm_4_brown_capital", "firm_5_brown_capital",
		"firm_6_brown_capital","firm_7_brown_capital", "firm_8_brown_capital", "firm_9_brown_capital", "firm_10_brown_capital", "firm_11_brown_capital"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Brown Capital by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/brown_capital_by_firm.pdf")

keyset_raw = ["firm_1_green_capital", "firm_2_green_capital", "firm_3_green_capital", "firm_4_green_capital", "firm_5_green_capital",
"firm_6_green_capital","firm_7_green_capital", "firm_8_green_capital", "firm_9_green_capital", "firm_10_green_capital", "firm_11_green_capital"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Green Capital by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/green_capital_by_firm.pdf")

keyset_raw = ["firm_1_total_capital", "firm_2_total_capital", "firm_3_total_capital", "firm_4_total_capital", "firm_5_total_capital","firm_6_total_capital","firm_7_total_capital", "firm_8_total_capital", "firm_9_total_capital", "firm_10_total_capital", "firm_11_total_capital"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Total Capital by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/total_capital_by_firm.pdf")

keyset_raw = ["firm_1_yearly_production", "firm_2_yearly_production", "firm_3_yearly_production", "firm_4_yearly_production", "firm_5_yearly_production","firm_6_yearly_production","firm_7_yearly_production", "firm_8_yearly_production", "firm_9_yearly_production", "firm_10_yearly_production", "firm_11_yearly_production"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, " Yearly Production by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_production_by_firm.pdf")

keyset_raw = ["firm_1_price", "firm_2_price", "firm_3_price", "firm_4_price", "firm_5_price","firm_6_price","firm_7_price", "firm_8_price", "firm_9_price", "firm_10_price", "firm_11_price"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Price by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/price_by_firm.pdf")

keyset_raw = ["firm_1_demand_price", "firm_2_demand_price", "firm_3_demand_price", "firm_4_demand_price", "firm_5_demand_price","firm_6_demand_price","firm_7_demand_price", "firm_8_demand_price", "firm_9_demand_price", "firm_10_demand_price", "firm_11_demand_price"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Demand Price by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/demand_price_by_firm.pdf")

keyset_raw = ["firm_1_money", "firm_2_money", "firm_3_money", "firm_4_money", "firm_5_money","firm_6_money","firm_7_money", "firm_8_money", "firm_9_money", "firm_10_money", "firm_11_money"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Money by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/money_by_firm.pdf")

keyset_raw = ["firm_1_inventory", "firm_2_inventory", "firm_3_inventory", "firm_4_inventory", "firm_5_inventory","firm_6_inventory","firm_7_inventory", "firm_8_inventory", "firm_9_inventory", "firm_10_inventory", "firm_11_inventory"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Inventory by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/inventory_by_firm.pdf")

keyset_raw = ["firm_1_market_share_electric_market", "firm_2_market_share_electric_market", "firm_3_market_share_electric_market", "firm_4_market_share_electric_market", "firm_5_market_share_electric_market", "firm_6_market_share_electric_market", "firm_7_market_share_electric_market", "firm_8_market_share_electric_market", "firm_9_market_share_electric_market", "firm_10_market_share_electric_market", "firm_11_market_share_electric_market"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Market Share Electric by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/market_share_electric_by_firm.pdf")

keyset_raw = ["firm_1_yearly_profit", "firm_2_yearly_profit", "firm_3_yearly_profit", "firm_4_yearly_profit", "firm_5_yearly_profit","firm_6_yearly_profit","firm_7_yearly_profit", "firm_8_yearly_profit", "firm_9_yearly_profit", "firm_10_yearly_profit", "firm_11_yearly_profit"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Profit by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_profit_by_firm.pdf")

keyset_raw = ["firm_1_yearly_revenue", "firm_2_yearly_revenue", "firm_3_yearly_revenue", "firm_4_yearly_revenue", "firm_5_yearly_revenue","firm_6_yearly_revenue","firm_7_yearly_revenue", "firm_8_yearly_revenue", "firm_9_yearly_revenue", "firm_10_yearly_revenue", "firm_11_yearly_revenue"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Revenue by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_revenue_by_firm.pdf")

keyset_raw = ["firm_1_sales", "firm_2_sales", "firm_3_sales", "firm_4_sales", "firm_5_sales","firm_6_sales","firm_7_sales", "firm_8_sales", "firm_9_sales", "firm_10_sales", "firm_11_sales"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Sales by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/sales_by_firm.pdf")

keyset_raw = ["firm_1_demand", "firm_2_demand", "firm_3_demand", "firm_4_demand", "firm_5_demand","firm_6_demand","firm_7_demand", "firm_8_demand", "firm_9_demand", "firm_10_demand", "firm_11_demand"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Demand by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/demand_by_firm.pdf")

keyset_raw = ["firm_1_yearly_market_share", "firm_2_yearly_market_share", "firm_3_yearly_market_share", "firm_4_yearly_market_share", "firm_5_yearly_market_share","firm_6_yearly_market_share","firm_7_yearly_market_share", "firm_8_yearly_market_share", "firm_9_yearly_market_share", "firm_10_yearly_market_share", "firm_11_yearly_market_share"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Market Share by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_market_share_by_firm.pdf")

keyset_raw = ["firm_1_top_consumer_group", "firm_2_top_consumer_group", "firm_3_top_consumer_group", "firm_4_top_consumer_group", "firm_5_top_consumer_group","firm_6_top_consumer_group","firm_7_top_consumer_group", "firm_8_top_consumer_group", "firm_9_top_consumer_group", "firm_10_top_consumer_group", "firm_11_top_consumer_group"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Top Consumer Group by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/top_consumer_group_by_firm.pdf")

for i in 1:no_firms
	keyy = Symbol("firm_$(i)_consumer_group_dist")
	seriess = deepcopy(get_data_exp_key(data, "only_base", keyy))

	brand = labelset_firms_ind[i]

	pll = plot(title="", fontfamily="Computer Modern")
	xx = x_quarterly
	mean_series = [Float64[] for _ in 1:4]

	T = length(seriess[1])
	R = length(seriess)

	for t in 1:T
		sums = zeros(4)
		counts = zeros(4)

		for r in 1:R
			vals = seriess[r][t]

			for j in 1:4
				v = vals[j]
				if !isnan(v)
					sums[j] += v
					counts[j] += 1
				end
			end
		end

		for j in 1:4
			if counts[j] > 0
				push!(mean_series[j], sums[j] / counts[j])
			else
				push!(mean_series[j], NaN)
			end
		end
	end

	for j in 1:4
		plot!(pll, xx, mean_series[j],
			color=colorpalette_cons[j],
			label=labelset_cons[j],
			linewidth=1)
	end

	vline!(pll, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label = "")

	savefig(pll,"plots/$name/consumer_group_dist_firm_$(i).pdf")
end


pll_all = plot(;
    xlabel       = "Budget",
    ylabel       = "Environmental Preference",
    xlims        = (-0.05, 1.05),
    ylims        = (-0.05, 1.05),
    legend       = :outertopright
)

seen_labels = Set{String}()

for i in 1:no_firms
    keyy = Symbol("firm_$(i)_average_consumer")
    seriess = deepcopy(get_data_exp_key(data, "only_base", keyy))

    mean_greenness = Float64[]
    mean_budget    = Float64[]

    T = length(seriess[1])
    R = length(seriess)

    for t in 1:T
        sum_g = 0.0; sum_b = 0.0
        count_g = 0; count_b = 0

        for r in 1:R
            tup = seriess[r][t]
            g = tup[1]; b = tup[2]
            if !isnan(g); sum_g += g; count_g += 1; end
            if !isnan(b); sum_b += b; count_b += 1; end
        end

        push!(mean_greenness, count_g > 0 ? sum_g / count_g : NaN)
        push!(mean_budget,    count_b > 0 ? sum_b / count_b : NaN)
    end

    lbl = labelset_firms_class[i]
    display_label = lbl in seen_labels ? "" : lbl
    push!(seen_labels, lbl)

    scatter!(pll_all, mean_budget, mean_greenness;
        color             = colorpalette_grey[i],
        markersize        = 2,
        markerstrokewidth = 0,
        label             = display_label)
end

vline!(pll_all, [0.5], linestyle=:dash, color=STAGES_COLOR, label="")
hline!(pll_all, [0.5], linestyle=:dash, color=STAGES_COLOR, label="")

savefig(pll_all, "plots/$name/average_consumer_all_firms_base.pdf")

keyset_raw = ["customer_base_firm1", "customer_base_firm2", "customer_base_firm3", "customer_base_firm4", "customer_base_firm5","customer_base_firm6","customer_base_firm7","customer_base_firm8", "customer_base_firm9", "customer_base_firm10", "customer_base_firm11"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Customer Base by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/customer_base_by_firm.pdf")

keyset_raw = ["firm_1_cum_registrations", "firm_2_cum_registrations", "firm_3_cum_registrations", "firm_4_cum_registrations", "firm_5_cum_registrations","firm_6_cum_registrations","firm_7_cum_registrations","firm_8_cum_registrations", "firm_9_cum_registrations", "firm_10_cum_registrations", "firm_11_cum_registrations"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "only_base", keyset, "Cumulative Registrations by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/cum_registrations_by_firm.pdf")

keyset1_raw = ["firm_1_greenness", "firm_2_greenness", "firm_3_greenness", "firm_4_greenness", "firm_5_greenness","firm_6_greenness","firm_7_greenness","firm_8_greenness", "firm_9_greenness", "firm_10_greenness", "firm_11_greenness"]
keyset1 = keyset1_raw[1:no_firms]

keyset3_raw = ["firm_1_prestige", "firm_2_prestige", "firm_3_prestige", "firm_4_prestige", "firm_5_prestige","firm_6_prestige","firm_7_prestige","firm_8_prestige", "firm_9_prestige", "firm_10_prestige", "firm_11_prestige"]
keyset3 = keyset3_raw[1:no_firms]

attribute_list_greenness = extract_attributes(data,"only_base",keyset1)
attribute_list_prestige = extract_attributes(data,"only_base",keyset3)

pl = plot(; xlabel="Prestige", ylabel="Greenness", xlims=(-0.1,1.1), ylims=(-0.1,1.1),
	title="")

for i in 1:no_firms
	scatter!(attribute_list_prestige[i], attribute_list_greenness[i];
			color=colorpalette_grey[i],
			markersize=3,
			markerstrokewidth=0,
			label=labelset_firms_class[i], legend = :outertopright)
end

vline!(pl, [0.5], linestyle=:dash, color=STAGES_COLOR, label = "")
hline!(pl, [0.5], linestyle=:dash, color=STAGES_COLOR, label = "")

savefig(pl,"plots/$name/attribute_by_firm_innovation.pdf")


### Consumption Side ###

pl = plot_comparison(data,"baseline","green_prestige_ratio","only_base", "green_prestige_ratio", "Average Green/Prestige Consumption","royalblue","darkorange", "Baseline","Only Base", true,false,true)
savefig(pl,"plots/$name/green_prestige_ratio.pdf")

keyset = ["share_owners_group1", "share_owners_group2", "share_owners_group3", "share_owners_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Car owner share by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/owner_share_group.pdf")

keyset = ["owned_product_greenness_group1", "owned_product_greenness_group2", "owned_product_greenness_group3", "owned_product_greenness_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Owned Product Greenness by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/owned_product_greenness_group.pdf")

keyset = ["owned_product_prestige_group1", "owned_product_prestige_group2", "owned_product_prestige_group3", "owned_product_prestige_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Owned Product prestige by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/owned_product_prestige_group.pdf")

keyset = ["total_utility_group1", "total_utility_group2", "total_utility_group3", "total_utility_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Total Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/total_utility_group.pdf")

keyset = ["green_status_group1", "green_status_group2", "green_status_group3", "green_status_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average Green Status by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/green_status_group.pdf")

keyset = ["green_distinction_group1", "green_distinction_group2", "green_distinction_group3", "green_distinction_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average Green Distinction Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/green_distinction_group.pdf")

keyset = ["green_imitation_group1", "green_imitation_group2", "green_imitation_group3", "green_imitation_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average Green Imitation Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/green_imitation_group.pdf")

keyset = ["prestige_status_group1", "prestige_status_group2", "prestige_status_group3", "prestige_status_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average prestige Status by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/prestige_status_group.pdf")

keyset = ["prestige_distinction_group1", "prestige_distinction_group2", "prestige_distinction_group3", "prestige_distinction_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average prestige Distinction Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/prestige_distinction_group.pdf")

keyset = ["prestige_imitation_group1", "prestige_imitation_group2", "prestige_imitation_group3", "prestige_imitation_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average prestige Imitation Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/prestige_imitation_group.pdf")

keyset = ["status_group1", "status_group2", "status_group3", "status_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average Status by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/status_group.pdf")

keyset = ["identity_utility_group1", "identity_utility_group2", "identity_utility_group3", "identity_utility_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average Identity Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/identity_utility_group.pdf")

keyset = ["utility_remaining_budget_group1", "utility_remaining_budget_group2", "utility_remaining_budget_group3", "utility_remaining_budget_group4"]
pl = plot_by_consumption_group(data, "only_base", keyset, "Average Utility of Remaining Budget by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/utility_remaining_budget_group.pdf")

