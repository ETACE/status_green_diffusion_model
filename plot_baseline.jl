using Serialization, ArgParse, SkipNan, Statistics
using Plots,TensorCast, Colors

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


function load_data(folder, experiments, plot_it_arg=nothing)

	# load data
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

	data = Dict()
	plot_it = size(results[1][:model_data],1)

	for (exp_name, props) in experiments
		data[exp_name] = []
		for i in eachindex(results)
			if results[i][:exp_name] == exp_name
				append!(data[exp_name], [results[i][:model_data][burn_in_time+1:plot_it,:]])
			end
		end
	end

	return data
end


function get_data_exp_key(data, exp, key)
	data_exp_key=[]
	for i in 1:length(data[exp])
		append!(data_exp_key, [data[exp][i][!,key]])
	end
	return data_exp_key
end

function get_mean_upper_lower(data, conf_level=0.25)
    @cast data_t[i][j] := data[j][i]

	mean_data = []
	upper =[]
	lower = []

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

function plot_single(data,exp,key,title,color,label,ribbon, yearly, stages)
	series = deepcopy(get_data_exp_key(data, exp, key))

    x = x_quarterly
    if yearly
        series = transform_into_yearly(series)
        x = x_yearly
    end

	pl = plot(title="", size=(700, 450))

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
    pl = plot(title="", size=(800, 450))

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
    pl = plot(title="", size=(900, 450))
	
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

include("model/model.jl")
include("experiments/initialization.jl")
include("experiments/baseline.jl") 
name = "baseline"

n_quarterly = simulation_time - burn_in_time
x_quarterly = 0:(n_quarterly)
n_yearly = Int(floor(n_quarterly/4))
x_yearly = 0:(n_yearly-1)

data = load_data(folder, experiments)

mkpath("plots/$name")


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

number_eco_lux = 0
number_eco_mid = 0

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

pl = plot_single(data, "baseline", "market_penetration", "Market Penetration","royalblue","Baseline",true, false, true)
savefig(pl,"plots/$name/market_penetration.pdf")

pl = plot_single(data, "baseline", "hh_index", "Herfindahl-Hirschman-Index","royalblue","Baseline",true, true, true)
savefig(pl,"plots/$name/hh_index.pdf")

pl = plot_single(data, "baseline", "average_weighted_price", "Average weighted price", "royalblue", "Baseline", true, true, true)
savefig(pl,"plots/$name/average_weighted_price.pdf")

pl = plot_single(data, "baseline", "concentration_rate_three", "Concentration Rate (Top 3 Firms)","seagreen","Baseline",true, false, true)
savefig(pl,"plots/$name/concentration_rate_three.pdf")

series = deepcopy(get_data_exp_key(data, "baseline", "ev_share_sales"))
x = x_quarterly
pl = plot(title="", fontfamily="Computer Modern", size=(700, 450), ylim=(-0.02,0.32))
add_series_with_ribbon!(pl, x, series, "royalblue", "Baseline")
vline!(pl, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label = "")
	
savefig(pl,"plots/$name/ev_share_sales.pdf")

### Production Side ###

keyset_raw = ["firm_1_first_registration_share", "firm_2_first_registration_share", "firm_3_first_registration_share", "firm_4_first_registration_share", 
		"firm_5_first_registration_share","firm_6_first_registration_share","firm_7_first_registration_share", "firm_8_first_registration_share", 
		"firm_9_first_registration_share", "firm_10_first_registration_share", "firm_11_first_registration_share"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "First Registration Share by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/first_registration_share_by_firm.pdf")

keyset_raw = ["firm_1_brown_capital", "firm_2_brown_capital", "firm_3_brown_capital", "firm_4_brown_capital", "firm_5_brown_capital",
		"firm_6_brown_capital","firm_7_brown_capital", "firm_8_brown_capital", "firm_9_brown_capital", "firm_10_brown_capital", "firm_11_brown_capital"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Brown Capital by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/brown_capital_by_firm.pdf")

keyset_raw = ["firm_1_green_capital", "firm_2_green_capital", "firm_3_green_capital", "firm_4_green_capital", "firm_5_green_capital",
"firm_6_green_capital","firm_7_green_capital", "firm_8_green_capital", "firm_9_green_capital", "firm_10_green_capital", "firm_11_green_capital"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Green Capital by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/green_capital_by_firm.pdf")

keyset_raw = ["firm_1_total_capital", "firm_2_total_capital", "firm_3_total_capital", "firm_4_total_capital", "firm_5_total_capital","firm_6_total_capital","firm_7_total_capital", "firm_8_total_capital", "firm_9_total_capital", "firm_10_total_capital", "firm_11_total_capital"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Total Capital by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/total_capital_by_firm.pdf")

keyset_raw = ["firm_1_yearly_production", "firm_2_yearly_production", "firm_3_yearly_production", "firm_4_yearly_production", "firm_5_yearly_production","firm_6_yearly_production","firm_7_yearly_production", "firm_8_yearly_production", "firm_9_yearly_production", "firm_10_yearly_production", "firm_11_yearly_production"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, " Yearly Production by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_production_by_firm.pdf")

keyset_raw = ["firm_1_price", "firm_2_price", "firm_3_price", "firm_4_price", "firm_5_price","firm_6_price","firm_7_price", "firm_8_price", "firm_9_price", "firm_10_price", "firm_11_price"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Price by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/price_by_firm.pdf")


keyset_raw = ["firm_1_demand_price", "firm_2_demand_price", "firm_3_demand_price", "firm_4_demand_price", "firm_5_demand_price","firm_6_demand_price","firm_7_demand_price", "firm_8_demand_price", "firm_9_demand_price", "firm_10_demand_price", "firm_11_demand_price"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Demand Price by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/demand_price_by_firm.pdf")

keyset_raw = ["firm_1_money", "firm_2_money", "firm_3_money", "firm_4_money", "firm_5_money","firm_6_money","firm_7_money", "firm_8_money", "firm_9_money", "firm_10_money", "firm_11_money"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Money by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/money_by_firm.pdf")

keyset_raw = ["firm_1_greenness", "firm_2_greenness", "firm_3_greenness", "firm_4_greenness", "firm_5_greenness","firm_6_greenness","firm_7_greenness", "firm_8_greenness", "firm_9_greenness", "firm_10_greenness", "firm_11_greenness"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Greenness by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/greenness_by_firm.pdf")

keyset_raw = ["firm_1_prestige", "firm_2_prestige", "firm_3_prestige", "firm_4_prestige", "firm_5_prestige","firm_6_prestige","firm_7_prestige", "firm_8_prestige", "firm_9_prestige", "firm_10_prestige", "firm_11_prestige"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Prestige by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/prestige_by_firm.pdf")

keyset_raw = ["firm_1_inventory", "firm_2_inventory", "firm_3_inventory", "firm_4_inventory", "firm_5_inventory","firm_6_inventory","firm_7_inventory", "firm_8_inventory", "firm_9_inventory", "firm_10_inventory", "firm_11_inventory"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Inventory by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/inventory_by_firm.pdf")

keyset_raw = ["firm_1_market_share_electric_market", "firm_2_market_share_electric_market", "firm_3_market_share_electric_market", "firm_4_market_share_electric_market", "firm_5_market_share_electric_market", "firm_6_market_share_electric_market", "firm_7_market_share_electric_market", "firm_8_market_share_electric_market", "firm_9_market_share_electric_market", "firm_10_market_share_electric_market", "firm_11_market_share_electric_market"]
keyset = keyset_raw[9:no_firms]
labelset_electric = ["Eco Base", "Eco Lux", "Eco Mid"]
color_electric = ["mediumaquamarine", "deeppink", "darkorange"]
linestyle_electric = [:solid, :solid, :solid]
pl = plot_by_firm(data, "baseline", keyset, "Market Share Electric by Firms", labelset_electric, color_electric, linestyle_electric, false, false, true)
savefig(pl,"plots/$name/market_share_electric_by_firm.pdf")

keyset_raw = ["firm_1_yearly_profit", "firm_2_yearly_profit", "firm_3_yearly_profit", "firm_4_yearly_profit", "firm_5_yearly_profit","firm_6_yearly_profit","firm_7_yearly_profit", "firm_8_yearly_profit", "firm_9_yearly_profit", "firm_10_yearly_profit", "firm_11_yearly_profit"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Profit by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_profit_by_firm.pdf")

keyset_raw = ["firm_1_yearly_revenue", "firm_2_yearly_revenue", "firm_3_yearly_revenue", "firm_4_yearly_revenue", "firm_5_yearly_revenue","firm_6_yearly_revenue","firm_7_yearly_revenue", "firm_8_yearly_revenue", "firm_9_yearly_revenue", "firm_10_yearly_revenue", "firm_11_yearly_revenue"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "revenue by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_revenue_by_firm.pdf")

keyset_raw = ["firm_1_sales", "firm_2_sales", "firm_3_sales", "firm_4_sales", "firm_5_sales","firm_6_sales","firm_7_sales", "firm_8_sales", "firm_9_sales", "firm_10_sales", "firm_11_sales"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Sales by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/sales_by_firm.pdf")

keyset_raw = ["firm_1_demand", "firm_2_demand", "firm_3_demand", "firm_4_demand", "firm_5_demand","firm_6_demand","firm_7_demand", "firm_8_demand", "firm_9_demand", "firm_10_demand", "firm_11_demand"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Demand by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/demand_by_firm.pdf")

keyset_raw = ["firm_1_yearly_market_share", "firm_2_yearly_market_share", "firm_3_yearly_market_share", "firm_4_yearly_market_share", "firm_5_yearly_market_share","firm_6_yearly_market_share","firm_7_yearly_market_share", "firm_8_yearly_market_share", "firm_9_yearly_market_share", "firm_10_yearly_market_share", "firm_11_yearly_market_share"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Market Share by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/yearly_market_share_by_firm.pdf")

keyset_raw = ["firm_1_top_consumer_group", "firm_2_top_consumer_group", "firm_3_top_consumer_group", "firm_4_top_consumer_group", "firm_5_top_consumer_group","firm_6_top_consumer_group","firm_7_top_consumer_group", "firm_8_top_consumer_group", "firm_9_top_consumer_group", "firm_10_top_consumer_group", "firm_11_top_consumer_group"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Top Consumer Group by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
savefig(pl,"plots/$name/top_consumer_group_by_firm.pdf")

for i in 1:no_firms
	keyy = Symbol("firm_$(i)_consumer_group_dist")
	seriess = deepcopy(get_data_exp_key(data, "baseline", keyy))

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
    fontfamily   = "Computer Modern",
    legend       = :outertopright
)

seen_labels = Set{String}()

for i in 1:no_firms
    keyy = Symbol("firm_$(i)_average_consumer")
    seriess = deepcopy(get_data_exp_key(data, "baseline", keyy))

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

    keep = [!(b == 0.0 && g == 0.0) for (b, g) in zip(mean_budget, mean_greenness)]
    plot_budget    = mean_budget[keep]
    plot_greenness = mean_greenness[keep]

    scatter!(pll_all, plot_budget, plot_greenness;
        color             = colorpalette_grey[i],
        markersize        = 2,
        markerstrokewidth = 0,
        label             = display_label)
end

vline!(pll_all, [0.5], linestyle=:dash, color=STAGES_COLOR, label="")
hline!(pll_all, [0.5], linestyle=:dash, color=STAGES_COLOR, label="")

savefig(pll_all, "plots/$name/average_consumer_all_firms.pdf")

keyset_raw = ["firm_1_capital_cost_share", "firm_2_capital_cost_share", "firm_3_capital_cost_share", "firm_4_capital_cost_share", "firm_5_capital_cost_share","firm_6_capital_cost_share","firm_7_capital_cost_share", "firm_8_capital_cost_share", "firm_9_capital_cost_share", "firm_10_capital_cost_share", "firm_11_capital_cost_share"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Capital Cost Share by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/capital_cost_share_by_firm.pdf")

keyset_raw = ["firm_1_production_cost_share", "firm_2_production_cost_share", "firm_3_production_cost_share", "firm_4_production_cost_share", "firm_5_production_cost_share","firm_6_production_cost_share","firm_7_production_cost_share", "firm_8_production_cost_share", "firm_9_production_cost_share", "firm_10_production_cost_share", "firm_11_production_cost_share"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Production Cost Share by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, true, true)
savefig(pl,"plots/$name/production_cost_share_by_firm.pdf")

keyset_raw = ["customer_base_firm1", "customer_base_firm2", "customer_base_firm3", "customer_base_firm4", "customer_base_firm5","customer_base_firm6","customer_base_firm7","customer_base_firm8", "customer_base_firm9", "customer_base_firm10", "customer_base_firm11"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Customer Base by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/customer_base_by_firm.pdf")

keyset_raw = ["firm_1_cum_registrations", "firm_2_cum_registrations", "firm_3_cum_registrations", "firm_4_cum_registrations", "firm_5_cum_registrations","firm_6_cum_registrations","firm_7_cum_registrations","firm_8_cum_registrations", "firm_9_cum_registrations", "firm_10_cum_registrations", "firm_11_cum_registrations"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Cumulative Registrations by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/cum_registrations_by_firm.pdf")


key1 = Symbol("customer_base_firm$(number_eco_base)")
pl = plot_single(data, "baseline", key1, "Customer Base Eco Base", "darkorange", "Eco Base", true, false, true)
savefig(pl, "plots/$name/customer_base_eco_base.pdf")

key2 = Symbol("customer_base_firm$(number_eco_lux)")
pl = plot_single(data, "baseline", key2, "Customer Base Eco Lux", "royalblue", "Eco Lux", true, false, true)
savefig(pl, "plots/$name/customer_base_eco_lux.pdf")

key3 = Symbol("customer_base_firm$(number_eco_mid)")
pl = plot_single(data, "baseline", key3, "Customer Base Eco Mid", "black", "Eco Mid", true, false, true)
savefig(pl, "plots/$name/customer_base_eco_mid.pdf")

pl = plot(title = "", fontfamily = "Computer Modern", size=(700, 450))
series_base = deepcopy(get_data_exp_key(data, "baseline", Symbol("firm_$(number_eco_base)_cum_registrations")))
mean_base, upper_base, lower_base = get_mean_upper_lower(series_base)
plot!(pl, x_quarterly, mean_base, color="mediumaquamarine", label="Eco Base", ribbon=(lower_base, upper_base), fillalpha=0.2)
series_lux = deepcopy(get_data_exp_key(data, "baseline", Symbol("firm_$(number_eco_lux)_cum_registrations")))
mean_lux, upper_lux, lower_lux = get_mean_upper_lower(series_lux)
plot!(pl, x_quarterly, mean_lux, color="deeppink", label="Eco Lux", ribbon=(lower_lux, upper_lux), fillalpha=0.2)
series_mass = deepcopy(get_data_exp_key(data, "baseline", Symbol("firm_$(number_eco_mid)_cum_registrations")))
mean_mass, upper_mass, lower_mass = get_mean_upper_lower(series_mass)
plot!(pl, x_quarterly, mean_mass, color="darkorange", label="Eco Mid", ribbon=(lower_mass, upper_mass), fillalpha=0.2)
vline!(pl, [0, 4, 8, 28], linestyle=:dash, color=STAGES_COLOR, label = "")
savefig(pl, "plots/$name/cum_registrations_evs_with_ribbon.pdf")


keyset_raw = ["status_utility_firm1_customers", "status_utility_firm2_customers", "status_utility_firm3_customers", "status_utility_firm4_customers", "status_utility_firm5_customers","status_utility_firm6_customers","status_utility_firm7_customers","status_utility_firm8_customers", "status_utility_firm9_customers", "status_utility_firm10_customers", "status_utility_firm11_customers"]
keyset = keyset_raw[1:no_firms]
pl = plot_by_firm(data, "baseline", keyset, "Status Utility by Firms", labelset_firms_class, colorpalette_firms, linestyle_firms, false, false, true)
plot!(pl, legend=:outertopright)
savefig(pl,"plots/$name/status_utility_by_firm.pdf")

keyset1_raw = ["firm_1_greenness", "firm_2_greenness", "firm_3_greenness", "firm_4_greenness", "firm_5_greenness","firm_6_greenness","firm_7_greenness","firm_8_greenness", "firm_9_greenness", "firm_10_greenness", "firm_11_greenness"]
keyset1 = keyset1_raw[1:no_firms]

keyset3_raw = ["firm_1_prestige", "firm_2_prestige", "firm_3_prestige", "firm_4_prestige", "firm_5_prestige","firm_6_prestige","firm_7_prestige","firm_8_prestige", "firm_9_prestige", "firm_10_prestige", "firm_11_prestige"]
keyset3 = keyset3_raw[1:no_firms]

attribute_list_greenness = extract_attributes(data,"baseline",keyset1)
attribute_list_prestige = extract_attributes(data,"baseline",keyset3)

pl = plot(; xlabel="Prestige", ylabel="Greenness", xlims=(-0.1,1.1), ylims=(-0.1,1.1),
	title="", fontfamily="Computer Modern")

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

attribute_list_greenness = []
attribute_list_prestige = []

for i in 1:no_firms
	series = deepcopy(get_data_exp_key(data,"baseline",keyset1_raw[i]))
	mean_series = []
	list = Float64[]
	
	if i == number_eco_base || i == number_eco_lux || i == number_eco_mid
		series = deepcopy(get_data_exp_key(data,"baseline",keyset1_raw[i]))
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
		
		push!(attribute_list_greenness, mean_series)	
	else
		for k in eachindex(series)
			append!(list,[series[k][1]])
		end

		push!(mean_series,mean(skipnan(list)))
		push!(attribute_list_greenness, mean_series)	
	end
		
end
for i in 1:no_firms
	series = deepcopy(get_data_exp_key(data,"baseline",keyset3_raw[i]))
	mean_series = []
	
	list = Float64[]
	
	if i == number_eco_base || i == number_eco_lux || i == number_eco_mid
		series = deepcopy(get_data_exp_key(data,"baseline",keyset3_raw[i]))
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
		
		push!(attribute_list_prestige, mean_series)	

	else
		for k in eachindex(series)
			append!(list,[series[k][1]])
		end

		push!(mean_series,mean(skipnan(list)))
		push!(attribute_list_prestige, mean_series)	
	end
end

pl = plot(; xlabel="Prestige", ylabel="Greenness", xlims=(-0.1,1.1), ylims=(-0.1,1.1),
	title="", fontfamily="Computer Modern")


for i in 1:no_firms
	scatter!(attribute_list_prestige[i], attribute_list_greenness[i];
			color=colorpalette_grey[i],
			markersize=3,
			markerstrokewidth=0,
			label=labelset_firms_class[i], legend = :outertopright)
end

vline!(pl, [0.5], linestyle=:dash, color=STAGES_COLOR, label = "")
hline!(pl, [0.5], linestyle=:dash, color=STAGES_COLOR, label = "")

savefig(pl,"plots/$name/attribute_by_firm_initial_all.pdf")

attribute_list_greenness = []
attribute_list_prestige = []

no_firms_initial = no_firms - 2

for i in 1:no_firms_initial
	series = deepcopy(get_data_exp_key(data,"baseline",keyset1_raw[i]))
	mean_series = []
	list = Float64[]

	for k in eachindex(series)
		append!(list,[series[k][1]])
	end

	push!(mean_series,mean(skipnan(list)))
	push!(attribute_list_greenness, mean_series)	
		
end
for i in 1:no_firms_initial
	series = deepcopy(get_data_exp_key(data,"baseline",keyset3_raw[i]))
	mean_series = []
	
	list = Float64[]

	for k in eachindex(series)
		append!(list,[series[k][1]])
	end

	push!(mean_series,mean(skipnan(list)))
	push!(attribute_list_prestige, mean_series)	
		
end

pl = plot(; xlabel="Prestige", ylabel="Greenness", xlims=(-0.1,1.1), ylims=(-0.1,1.1),
	title="", fontfamily="Computer Modern", size = (500,500))

for i in 1:no_firms_initial-1
	scatter!(attribute_list_prestige[i], attribute_list_greenness[i];
			color=colorpalette_grey[i],
			markersize=3,
			markerstrokewidth=0,
			label=labelset_firms_class[i])
end

vline!(pl, [0.5], linestyle=:dash, color=STAGES_COLOR, label = "")
hline!(pl, [0.5], linestyle=:dash, color=STAGES_COLOR, label = "")

savefig(pl,"plots/$name/attribute_by_firm_initial.pdf")


### Consumption Side ###

pl = plot_single(data,"baseline","households_willing_to_buy","Households Willing to Buy","royalblue","Baseline",true, false, true)
savefig(pl,"plots/$name/households_willing_to_buy.pdf")

pl = plot_single(data,"baseline","green_prestige_ratio","Average Green/Prestige Consumption","royalblue","Baseline",true,false,true)
savefig(pl,"plots/$name/green_prestige_ratio.pdf")

keyset = ["consumption_group1", "consumption_group2", "consumption_group3", "consumption_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Consumption by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/consumption_group.pdf")

keyset = ["share_owners_group1", "share_owners_group2", "share_owners_group3", "share_owners_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Car owner share by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/owner_share_group.pdf")

keyset = ["owned_product_greenness_group1", "owned_product_greenness_group2", "owned_product_greenness_group3", "owned_product_greenness_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Owned Product Greenness by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/owned_product_greenness_group.pdf")

keyset = ["owned_product_prestige_group1", "owned_product_prestige_group2", "owned_product_prestige_group3", "owned_product_prestige_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Owned Product prestige by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/owned_product_prestige_group.pdf")

keyset = ["total_utility_group1", "total_utility_group2", "total_utility_group3", "total_utility_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Total Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/total_utility_group.pdf")

keyset = ["green_status_group1", "green_status_group2", "green_status_group3", "green_status_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average Green Status by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/green_status_group.pdf")

keyset = ["green_distinction_group1", "green_distinction_group2", "green_distinction_group3", "green_distinction_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average Green Distinction Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/green_distinction_group.pdf")

keyset = ["green_imitation_group1", "green_imitation_group2", "green_imitation_group3", "green_imitation_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average Green Imitation Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/green_imitation_group.pdf")

keyset = ["prestige_status_group1", "prestige_status_group2", "prestige_status_group3", "prestige_status_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average prestige Status by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/prestige_status_group.pdf")

keyset = ["prestige_distinction_group1", "prestige_distinction_group2", "prestige_distinction_group3", "prestige_distinction_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average prestige Distinction Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/prestige_distinction_group.pdf")

keyset = ["prestige_imitation_group1", "prestige_imitation_group2", "prestige_imitation_group3", "prestige_imitation_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average prestige Imitation Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/prestige_imitation_group.pdf")

keyset = ["status_group1", "status_group2", "status_group3", "status_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average Status by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/status_group.pdf")

keyset = ["identity_utility_group1", "identity_utility_group2", "identity_utility_group3", "identity_utility_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average Identity Utility by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/identity_utility_group.pdf")

keyset = ["utility_remaining_budget_group1", "utility_remaining_budget_group2", "utility_remaining_budget_group3", "utility_remaining_budget_group4"]
pl = plot_by_consumption_group(data, "baseline", keyset, "Average Utility of Remaining Budget by Groups", labelset_cons, colorpalette_cons, true)
savefig(pl,"plots/$name/utility_remaining_budget_group.pdf")


