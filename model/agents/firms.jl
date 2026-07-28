using Statistics, LinearAlgebra, LsqFit, StatsBase

@agent struct Firm(NoSpaceAgent)
    # Attributes
    firm_index::Int64 = 0
    brand::String = ""
    class::Int64 = 0
    electric_car::Bool = false
    prestige::Float64 = 0.0
    greenness::Float64 = 0.0
    existence_time::Int64 = 0

    # Production
    green_capital::Float64 = 0.0
    brown_capital::Float64 = 0.0
    total_capital::Float64 = 0.0
    inventory::Float64 = 0.0
    production::Float64 = 0.0
    marginal_cost::Float64 = 0.0
    price::Float64 = 0.0
    demand_price::Float64 = 0.0
    past_prices::Vector{Float64} = Float64[]
    money::Float64 = 0.0
    revenue::Float64 = 0.0
    profit::Float64 = 0.0
    profit_list::Vector{Float64} = Float64[]
    temporary_profit_list::Vector{Float64} = Float64[]
    declining_profit::Int64 = 0
    demand_update::Int64 = 0
    estimated_demand_function::Function = p -> 0.0
    target_consumer_group::Float64 = 0.0
    
    # Innovation
    innovation_try::Int = 0
    sectors::Vector{Float64} = Float64[]
    unsuccessful_innovation::Bool = false
    
    # Policy
    state_subsidy::Float64 = 0.0
    manufacturer_subsidy::Float64 = 0.0

    # Data collection variables
    yearly_production::Float64 = 0.0
    sales::Int64 = 0
    first_registration_share::Float64 = 0.0
    demand::Int64 = 0
    customer_base::Float64 = 0
    cum_registrations::Int64 = 0
    yearly_sales::Int64 = 0
    yearly_market_share::Float64 = 0.0
    market_share_electric_market::Float64 = 0.0
    yearly_profit::Float64 = 0.0
    yearly_revenue::Float64 = 0.0
    yearly_capital_cost::Float64 = 0.0
    yearly_production_cost::Float64 = 0.0
    yearly_adaptation_cost::Float64 = 0.0
    capital_cost_share::Float64 = 0.0
    production_cost_share::Float64 = 0.0
    adaptation_cost_share::Float64 = 0.0
    top_consumer_group::Float64 = 0.0
    average_consumer::Tuple{Float64, Float64} = (0.0, 0.0)
    consumer_group_dist::Vector{Float64} = [0,0,0,0]
end

function depreciate_capital(firm::Firm, model::ABM)
    firm.green_capital -= model.capital_depreciation * firm.green_capital
    firm.brown_capital -= model.capital_depreciation * firm.brown_capital
    firm.total_capital = firm.green_capital + firm.brown_capital
end

function reset_monthly_variables!(firm::Firm)
    firm.demand = 0
    firm.sales = 0
    firm.revenue = 0.0
end

function reset_yearly_variables!(firm::Firm)
    firm.yearly_sales = 0
    firm.yearly_profit = 0.0
    firm.yearly_production = 0.0
    firm.yearly_revenue = 0.0
    firm.yearly_capital_cost = 0.0
    firm.yearly_production_cost = 0.0
    firm.yearly_adaptation_cost = 0.0
end

logistic_model(p, params) = params[1] ./ (1 .+ exp.(-params[2] .* (p .- params[3])))

function fit_logistic_demand(prices, demands)
    initial_params = [maximum(demands), 1.0, mean(prices)] 
    fit = curve_fit(logistic_model, prices, demands, initial_params)
    fitted_params = fit.param

    f = p -> logistic_model(p, fitted_params)
    return f, fitted_params
end



function estimate_demand!(firm::Firm, model::ABM)

    price_range = range(
        model.demand_est_price_lower_bound * firm.price, 
        model.demand_est_price_upper_bound * firm.price; 
        length = model.high_n_price_points
    )

    total_market = collect(filter(hh -> hh.time_of_use >= hh.length_of_ownership - 3, model.households))
    target_group = filter(hh -> hh.consumer_group == firm.target_consumer_group, total_market)
    non_target_group = filter(hh -> hh.consumer_group != firm.target_consumer_group, total_market)

    target_group_sample_size = Int(floor(model.target_group_focus_weight * model.demand_pop_fraction * length(total_market)))
    remaining_groups_sample_size = Int(floor((1 - model.target_group_focus_weight) * model.demand_pop_fraction * length(total_market)))

    if target_group_sample_size > length(target_group)
        target_group_sample_size = length(target_group)
    end
    if remaining_groups_sample_size > length(non_target_group)
        remaining_groups_sample_size = length(non_target_group)
    end
    target_group_sample = sample(target_group, target_group_sample_size; replace = false)
    non_target_group_sample = sample(non_target_group, remaining_groups_sample_size; replace = false)
    
    hh_sample = vcat(target_group_sample, non_target_group_sample)
    
    prices = Float64[]
    demands = Float64[]
    
    for test_price in price_range
            
        simulated_purchases = 0
        
        for hh in hh_sample
            bought = simulate_purchase_decision(hh, test_price, firm.firm_index, firm.greenness, firm.prestige, model)
            if bought
                simulated_purchases += 1
            end
        end
        
        est_market_share = simulated_purchases / length(hh_sample)
        est_demand = est_market_share * length(total_market) * 1/4
        
        push!(prices, test_price)
        push!(demands, est_demand)
    end
    
    f, params = fit_logistic_demand(prices, demands)
    firm.estimated_demand_function = f

end


function production(firm::Firm, model::ABM)
    firm.money += firm.revenue
    firm.yearly_production += firm.production
    firm.first_registration_share = firm.sales / sum(f.sales for f in model.firms)
   
    green_capital_cost = firm.green_capital * model.green_capital_costs
    
    firm.profit = firm.revenue - firm.marginal_cost * firm.production - model.brown_capital_costs * firm.brown_capital - green_capital_cost 
    firm.profit_list = push!(firm.profit_list, firm.profit)

    if firm.existence_time >= 20 + firm.demand_update
        push!(firm.temporary_profit_list, firm.profit)
        if firm.profit_list[end] < mean(firm.temporary_profit_list)
            firm.declining_profit += 1
        else
            firm.declining_profit = 0
        end
    end

    firm.yearly_profit += firm.profit
    firm.yearly_capital_cost += model.brown_capital_costs * firm.brown_capital * (1 + model.capital_depreciation) + green_capital_cost * (1 + model.capital_depreciation)
    firm.yearly_production_cost += firm.marginal_cost * firm.production + firm.yearly_capital_cost 

    firm.yearly_revenue += firm.revenue
    firm.yearly_sales += firm.sales

    if (abmtime(model) % 4 == 0) && firm.yearly_revenue > 0
        firm.capital_cost_share = firm.yearly_capital_cost / firm.yearly_revenue
        firm.production_cost_share = firm.yearly_production_cost / firm.yearly_revenue
    end
    
    firm.yearly_market_share = firm.yearly_sales / sum(f.yearly_sales for f in model.firms)

    if isempty(collect(f for f in model.firms if f.electric_car)) && firm.electric_car
        firm.market_share_electric_market = 0.0
    elseif firm.electric_car
        firm.market_share_electric_market = firm.sales / sum(f.sales for f in model.firms if f.electric_car)
    end

    firm.production = 0.0

    price_lower_bound = firm.price * (1 - model.narrow_price_range)
    price_upper_bound = firm.price * (1 + model.narrow_price_range)
    prices = range(price_lower_bound, price_upper_bound; length = model.small_n_price_points)

    price_range = Float64[]
    demand_range = Float64[]
    production_range = Float64[]
    supply_range = Float64[]
    profit = Float64[]

    additional_brown_capital = Float64[]
    additional_green_capital = Float64[]

    max_production_capacity = (model.alpha * firm.green_capital^(-model.rho) + (1-model.alpha) * firm.brown_capital^(-model.rho))^-(1/model.rho)


    for price in prices

        if model.green_subsidy_activated && firm.greenness >= 0.5
            if model.activate_tax
                if model.activate_tax_exemption
                    demand_price = price - firm.manufacturer_subsidy - firm.state_subsidy
                else
                    demand_price = (price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy) 
                end
            else
                demand_price = price - firm.manufacturer_subsidy - firm.state_subsidy
            end
        else
            if model.activate_tax
                if model.activate_tax_exemption && firm.greenness >= 0.5
                    demand_price = price 
                else
                    demand_price = price * (1 + model.mean_length_of_ownership * model.tax_rate)
                end
            else
                demand_price = price 
            end
        end
        
        if firm.existence_time >= 4
            expected_demand = firm.estimated_demand_function(demand_price) 
        else
            expected_demand = firm.estimated_demand_function(demand_price) * model.caution_factor
        end

        # Approximate reservation price
        if demand_price > maximum(hh.budget for hh in collect(allagents(model)) if isa(hh, Household)) || expected_demand < 0
            expected_demand = 0.0
        end
        
        push!(supply_range, expected_demand)
        push!(price_range, price)

        production = expected_demand - firm.inventory
        if production < 0
            production = 0.0
        end
        push!(production_range, production)
        push!(demand_range, expected_demand)

        delta_green_capital = production * (model.alpha + (1-model.alpha) * (firm.greenness/(1-firm.greenness))^model.rho)^(1/model.rho) - firm.green_capital
        delta_brown_capital = production * (model.alpha + (1-model.alpha) * (firm.greenness/(1-firm.greenness))^model.rho)^(1/model.rho) * (1 - firm.greenness)/firm.greenness - firm.brown_capital

        if production > max_production_capacity
            push!(additional_green_capital, delta_green_capital)
            push!(additional_brown_capital, delta_brown_capital)
        else
            push!(additional_green_capital, 0.0)
            push!(additional_brown_capital, 0.0)
        end
        
        if model.green_subsidy_activated && firm.greenness >= 0.5
            expected_profit = (price - firm.manufacturer_subsidy) * expected_demand - firm.marginal_cost * production - model.brown_capital_costs * (firm.brown_capital + delta_brown_capital) - model.green_capital_costs * (firm.green_capital + delta_green_capital) 
        else
            expected_profit = price * expected_demand - firm.marginal_cost * production - model.brown_capital_costs * (firm.brown_capital + delta_brown_capital) - model.green_capital_costs * (firm.green_capital + delta_green_capital) 
        end
        
        push!(profit, expected_profit)
    end

    

    max_profit_index = argmax(profit)
    target_profit = profit[max_profit_index]
    target_price = price_range[max_profit_index]
    target_production = production_range[max_profit_index]
    est_demand = demand_range[max_profit_index]


    if target_production <= max_production_capacity
        firm.production = target_production
        firm.inventory += firm.production
        firm.price = target_price
        push!(firm.past_prices, firm.price)
        if firm.existence_time >= 5
            price_average = mean(firm.past_prices[(firm.existence_time-4):(firm.existence_time)])
        else
            price_average = mean(firm.past_prices)
        end
        firm.adaptation_cost_share = 0.0

        if model.green_subsidy_activated && firm.greenness >= 0.5
            if model.activate_tax
                if model.activate_tax_exemption
                    firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                end
            else
                firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
            end
        else
            if model.activate_tax
                if model.activate_tax_exemption && firm.greenness >= 0.5
                    firm.demand_price = firm.price
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate)
                end
            else
                firm.demand_price = firm.price 
            end
        end
    else
        expand_capital_stock(firm, model, target_production, target_price)
    end
end

function expand_capital_stock(firm::Firm, model::ABM, target_production, target_price)
    additional_green_capital = target_production * (model.alpha + (1-model.alpha) * (firm.greenness/(1-firm.greenness))^model.rho)^(1/model.rho) - firm.green_capital
    additional_brown_capital = target_production * (model.alpha + (1-model.alpha) * (firm.greenness/(1-firm.greenness))^model.rho)^(1/model.rho) * (1 - firm.greenness)/firm.greenness - firm.brown_capital

    adaptation_cost = model.green_capital_adaptation_costs * additional_green_capital + model.brown_capital_adaptation_costs * additional_brown_capital
    firm.yearly_adaptation_cost += adaptation_cost

    if firm.money >= adaptation_cost
        firm.green_capital += additional_green_capital
        firm.brown_capital += additional_brown_capital
        firm.money -= adaptation_cost
        if firm.yearly_revenue > 0
            firm.adaptation_cost_share = firm.yearly_adaptation_cost / firm.yearly_revenue
        end
        firm.production = target_production
        firm.inventory += firm.production
        firm.price = target_price
        if model.green_subsidy_activated && firm.greenness >= 0.5
            if model.activate_tax
                if model.activate_tax_exemption
                    firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                end
            else
                firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
            end
        else
            if model.activate_tax
                if model.activate_tax_exemption && firm.greenness >= 0.5
                    firm.demand_price = firm.price
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate)
                end
            else
                firm.demand_price = firm.price 
            end
        end
        push!(firm.past_prices, firm.price)
        if firm.existence_time >= 5
            price_average = mean(firm.past_prices[(firm.existence_time-4):(firm.existence_time)])
        else
            price_average = mean(firm.past_prices)
        end
    elseif firm.money < adaptation_cost && firm.money > 0.0
        additional_brown_capital = firm.money / (model.green_capital_adaptation_costs * firm.greenness/(1 - firm.greenness) + model.brown_capital_adaptation_costs)
        additional_green_capital = firm.greenness/(1 - firm.greenness) * additional_brown_capital
        firm.green_capital += additional_green_capital
        firm.brown_capital += additional_brown_capital
        if firm.yearly_revenue > 0
            firm.adaptation_cost_share = firm.yearly_adaptation_cost / firm.yearly_revenue
        end
        firm.money = 0.0
        old_production = firm.production
        firm.production = (model.alpha * firm.green_capital^(-model.rho) + (1-model.alpha) * firm.brown_capital^(-model.rho))^-(1/model.rho)
        firm.inventory += firm.production
        prod_fraction = (firm.production - old_production) / (target_production - old_production + 1e-3)
        target_price_change = target_price - firm.price
        firm.price = firm.price + prod_fraction * target_price_change
        if model.green_subsidy_activated && firm.greenness >= 0.5
            if model.activate_tax
                if model.activate_tax_exemption
                    firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                end
            else
                firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
            end
        else
            if model.activate_tax
                if model.activate_tax_exemption && firm.greenness >= 0.5
                    firm.demand_price = firm.price
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate)
                end
            else
                firm.demand_price = firm.price 
            end
        end
        push!(firm.past_prices, firm.price)

        if firm.existence_time >= 5
            price_average = mean(firm.past_prices[(firm.existence_time-4):(firm.existence_time)])
        else
            price_average = mean(firm.past_prices)
        end
    else
        old_production = firm.production
        firm.production = (model.alpha * firm.green_capital^(-model.rho) + (1-model.alpha) * firm.brown_capital^(-model.rho))^-(1/model.rho)
        firm.inventory += firm.production
        prod_fraction = (firm.production - old_production) / (target_production - old_production + 1e-3)
        target_price_change = target_price - firm.price
        firm.price = firm.price + prod_fraction * target_price_change
        if model.green_subsidy_activated && firm.greenness >= 0.5
            if model.activate_tax
                if model.activate_tax_exemption
                    firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                end
            else
                firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
            end
        else
            if model.activate_tax
                if model.activate_tax_exemption && firm.greenness >= 0.5
                    firm.demand_price = firm.price
                else
                    firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate)
                end
            else
                firm.demand_price = firm.price 
            end
        end
        firm.adaptation_cost_share = 0.0
        
        push!(firm.past_prices, firm.price)
        if firm.existence_time >= 5
            price_average = mean(firm.past_prices[(firm.existence_time-4):(firm.existence_time)])
        else
            price_average = mean(firm.past_prices)
        end
    end

    firm.total_capital = firm.green_capital + firm.brown_capital
end

function payments(firm::Firm, model::ABM)
    firm.money -= model.green_capital_costs * firm.green_capital + model.brown_capital_costs * firm.brown_capital
    firm.money -= firm.marginal_cost * firm.production
end


function innovation_decision(firm::Firm, model::ABM)
    if ((mean(firm.temporary_profit_list) < 0.0) || firm.unsuccessful_innovation) && firm.money > 0.0 && firm.brand != "Eco base" && firm.brand != "Eco lux" && firm.brand != "Eco mass"

        firm.innovation_try += 1

        current_attributes = (firm.greenness, firm.prestige)
        innovation_attributes = attribute_selection(firm, model, true)

        # Consider competitors performance
        if model.enable_imitation
            competitors = [f for f in model.firms if f.id != firm.id]
            sector_width = 2pi / model.no_sectors

            lower_bound_greenness = clamp(firm.greenness - model.greenness_neighborhood * firm.innovation_try, 0.0, 1.0)
            upper_bound_greenness = clamp(firm.greenness + model.greenness_neighborhood * firm.innovation_try, 0.0, 1.0)

            radius_greenness = (upper_bound_greenness - lower_bound_greenness) / 2

            lower_bound_prestige = clamp(firm.prestige - model.prestige_neighborhood * firm.innovation_try, 0.0, 1.0)
            upper_bound_prestige = clamp(firm.prestige + model.prestige_neighborhood * firm.innovation_try, 0.0, 1.0)

            radius_prestige = (upper_bound_prestige - lower_bound_prestige) / 2
                

            for f in competitors
                dx = f.greenness - current_attributes[1]
                dy = f.prestige - current_attributes[2]

                theta = atan(dy, dx)
                if theta < 0.0
                    theta += 2 * pi 
                end

                k = Int(floor(mod(theta, 2 * pi) / sector_width)) + 1
                chosen_sector = clamp(k, 1, model.no_sectors)

                theta = (chosen_sector - 1) * sector_width + rand() * sector_width

                dx = cos(theta)
                dy = sin(theta)

                if radius_greenness > 0.05 && radius_prestige > 0.05
                    new_greenness = clamp(firm.greenness + rand(Uniform(0.05,radius_greenness)) * dx, 0.0, 1.0)
                    new_prestige = clamp(firm.prestige + rand(Uniform(0.05,radius_prestige)) * dy, 0.0, 1.0)
                else
                    new_greenness = clamp(firm.greenness + 0.05 * dx, 0.0, 1.0)
                    new_prestige = clamp(firm.prestige + 0.05 * dy, 0.0, 1.0)
                end

                push!(innovation_attributes, (new_greenness, new_prestige))

            end
        end

        innovation_profits = []
        sector_updates = []

        # Explore new attribute combinations
        for i in innovation_attributes
            greenness = i[1]
            prestige = i[2]

            if greenness < 0.5 && prestige < 0.5
                target_consumer_group = 1
            elseif greenness >= 0.5 && prestige < 0.5
                target_consumer_group = 2
            elseif greenness >= 0.5 && prestige >= 0.5
                target_consumer_group = 3
            elseif greenness < 0.5 && prestige >= 0.5
                target_consumer_group = 4
            end
        
            price_range = range(model.demand_est_price_lower_bound * firm.price, model.demand_est_price_upper_bound * firm.price; length = model.high_n_price_points)

            profit = Float64[]  

            total_market = collect(filter(hh -> hh.time_of_use >= hh.length_of_ownership - 3, model.households))
            target_group = filter(hh -> hh.consumer_group == target_consumer_group, total_market)
            non_target_group = filter(hh -> hh.consumer_group != target_consumer_group, total_market)

            
            target_group_sample_size = Int(floor(model.target_group_focus_weight * model.demand_pop_fraction * length(total_market)))
            remaining_groups_sample_size = Int(floor((1 - model.target_group_focus_weight) * model.demand_pop_fraction * length(total_market)))

            if target_group_sample_size > length(target_group)
                target_group_sample_size = length(target_group)
            end
            if remaining_groups_sample_size > length(non_target_group)
                remaining_groups_sample_size = length(non_target_group)
            end
            target_group_sample = sample(target_group, target_group_sample_size; replace = false)
            non_target_group_sample = sample(non_target_group, remaining_groups_sample_size; replace = false)
            
            hh_sample = vcat(target_group_sample, non_target_group_sample)
            
            for test_price in price_range
                    
                simulated_purchases = 0

                if model.green_subsidy_activated && greenness >= 0.5
                    if model.activate_tax
                        if model.activate_tax_exemption
                            demand_price = test_price - firm.manufacturer_subsidy - firm.state_subsidy
                        else
                            demand_price = test_price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                        end
                    else
                        demand_price = test_price - firm.manufacturer_subsidy - firm.state_subsidy
                    end
                else
                    if model.activate_tax
                        if model.activate_tax_exemption && firm.greenness >= 0.5
                            demand_price = test_price
                        else
                            demand_price = test_price * (1 + model.mean_length_of_ownership * model.tax_rate)
                        end
                    else
                        demand_price = test_price 
                    end 
                end
                
                for hh in hh_sample
                    bought = simulate_purchase_decision(hh, demand_price, firm.firm_index, greenness, prestige, model)
                    if bought
                        simulated_purchases += 1
                    end
                end
                
                est_market_share = simulated_purchases / length(hh_sample)
                est_demand = est_market_share * length(total_market) * 1/4
                        
                production = est_demand 
                green_capital_target = production * (model.alpha + (1-model.alpha) * (greenness/(1-greenness))^model.rho)^(-1/model.rho)
                brown_capital_target = production * (model.alpha + (1-model.alpha) * (greenness/(1-greenness))^model.rho)^(-1/model.rho) * (1-greenness)/greenness
                additional_green_capital = green_capital_target - firm.green_capital
                additional_brown_capital = brown_capital_target - firm.brown_capital

                transformation_cost, adaptation_cost, green_capital, brown_capital = calculate_capital_adjustment(firm, model, additional_green_capital, additional_brown_capital, green_capital_target, brown_capital_target)
                prestige_change_cost = model.prestige_update_cost_param * (prestige - firm.prestige)^2

                if model.green_subsidy_activated && greenness >= 0.5
                    expected_profit = (test_price - firm.manufacturer_subsidy) * production - firm.marginal_cost * production - model.green_capital_costs * green_capital - model.brown_capital_costs * brown_capital 
                else
                    expected_profit = test_price * production - firm.marginal_cost * production - model.green_capital_costs * green_capital - model.brown_capital_costs * brown_capital 
                end
                
                
                push!(profit, expected_profit)
            end

            max_profit_index = argmax(profit)
            push!(innovation_profits, profit[max_profit_index])
    
            # Update sector
            dx = i[1] - current_attributes[1]
            dy = i[2] - current_attributes[2]
            theta = atan(dy, dx)
            if theta < 0.0
                theta += 2 * pi 
            end

            angle = theta

            baseline_profit = mean(firm.temporary_profit_list)
            weight = max(0.0, profit[max_profit_index] - baseline_profit)

            sector_width = 2*pi / model.no_sectors 
            k = Int(floor(mod(angle, 2 * pi) / sector_width)) + 1
            index = clamp(k, 1, model.no_sectors)

            push!(sector_updates, (index, weight))
        end


        for (index, weight) in sector_updates
            firm.sectors[index] *= model.sector_decay
        end
            
        grouped = Dict{Int, Vector{Float64}}()
        for (idx, wgt) in sector_updates
            if haskey(grouped, idx)
                push!(grouped[idx], wgt)
            else
                grouped[idx] = [wgt]
            end
        end

        for (index, weights) in grouped
            mean_weights = mean(weights)
            if sum(firm.sectors) == 0.0
                firm.sectors[index] += mean_weights
            else
                firm.sectors[index] += (1 - model.sector_decay) * mean_weights
            end
            
        end

        sector_sum = sum(firm.sectors)
        if sector_sum > 0.0
            firm.sectors ./= sector_sum
            firm.sectors .*= 100.0  
        else
            fill!(firm.sectors, 100.0 / model.no_sectors)
        end
        
        # Select innovation candidates from sectors
        innovation_attributes = attribute_selection(firm, model, false)

        innovation_profits = []
        innovation_total_cost = []
        innovation_prices = []
        innovation_production = []
        innovation_brown_capital = []
        innovation_green_capital = []

        for i in innovation_attributes
            greenness = i[1]
            prestige = i[2]
        
            price_range = range(model.demand_est_price_lower_bound * firm.price, model.demand_est_price_upper_bound * firm.price; length = model.high_n_price_points)

            profit = Float64[]
            total_cost = Float64[]
            prices = []
            target_production = []
            brown_capital_list = []
            green_capital_list = []


            if greenness < 0.5 && prestige < 0.5
                target_consumer_group = 1
            elseif greenness >= 0.5 && prestige < 0.5
                target_consumer_group = 2
            elseif greenness >= 0.5 && prestige >= 0.5
                target_consumer_group = 3
            elseif greenness < 0.5 && prestige >= 0.5
                target_consumer_group = 4
            end

            total_market = collect(filter(hh -> hh.time_of_use >= hh.length_of_ownership - 3, model.households))
            target_group = filter(hh -> hh.consumer_group == target_consumer_group, total_market)
            non_target_group = filter(hh -> hh.consumer_group != target_consumer_group, total_market)

            
            target_group_sample_size = Int(floor(model.target_group_focus_weight * model.demand_pop_fraction * length(total_market)))
            remaining_groups_sample_size = Int(floor((1 - model.target_group_focus_weight) * model.demand_pop_fraction * length(total_market)))

            if target_group_sample_size > length(target_group)
                target_group_sample_size = length(target_group)
            end
            if remaining_groups_sample_size > length(non_target_group)
                remaining_groups_sample_size = length(non_target_group)
            end
            target_group_sample = sample(target_group, target_group_sample_size; replace = false)
            non_target_group_sample = sample(non_target_group, remaining_groups_sample_size; replace = false)
            
            hh_sample = vcat(target_group_sample, non_target_group_sample)
            
            for test_price in price_range
                    
                simulated_purchases = 0

                if model.green_subsidy_activated && greenness >= 0.5
                    if model.activate_tax
                        if model.activate_tax_exemption
                            demand_price = test_price - firm.manufacturer_subsidy - firm.state_subsidy
                        else
                            demand_price = test_price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                        end
                    else
                        demand_price = test_price - firm.manufacturer_subsidy - firm.state_subsidy
                    end
                else
                    if model.activate_tax
                        if model.activate_tax_exemption && firm.greenness >= 0.5
                            demand_price = test_price
                        else
                            demand_price = test_price * (1 + model.mean_length_of_ownership * model.tax_rate)
                        end
                    else
                        demand_price = test_price 
                    end  
                end
                
                for hh in hh_sample
                    bought = simulate_purchase_decision(hh, demand_price, firm.firm_index, greenness, prestige, model)
                    if bought
                        simulated_purchases += 1
                    end
                end
                
                est_market_share = simulated_purchases / length(hh_sample)
                est_demand = est_market_share * length(total_market) * 1/4
                
                production = est_demand 
                green_capital_target = production * (model.alpha + (1-model.alpha) * (greenness/(1-greenness))^model.rho)^(-1/model.rho)
                brown_capital_target = production * (model.alpha + (1-model.alpha) * (greenness/(1-greenness))^model.rho)^(-1/model.rho) * (1-greenness)/greenness
                additional_green_capital = green_capital_target - firm.green_capital
                additional_brown_capital = brown_capital_target - firm.brown_capital

                transformation_cost, adaptation_cost, green_capital, brown_capital = calculate_capital_adjustment(firm, model, additional_green_capital, additional_brown_capital, green_capital_target, brown_capital_target)
                prestige_change_cost = model.prestige_update_cost_param * (prestige - firm.prestige)^2

                if model.green_subsidy_activated && greenness >= 0.5
                    expected_profit = (test_price - firm.manufacturer_subsidy) * production - firm.marginal_cost * production - model.green_capital_costs * green_capital - model.brown_capital_costs * brown_capital
                else
                    expected_profit = test_price * production - firm.marginal_cost * production - model.green_capital_costs * green_capital - model.brown_capital_costs * brown_capital 
                end
                
                
                push!(total_cost, transformation_cost + adaptation_cost + prestige_change_cost)
                push!(profit, expected_profit)
                push!(prices, test_price)
                push!(target_production, production)
                push!(brown_capital_list, brown_capital)
                push!(green_capital_list, green_capital)
            end

            max_profit_index = argmax(profit)
            push!(innovation_profits, profit[max_profit_index])
            push!(innovation_total_cost, total_cost[max_profit_index])
            push!(innovation_prices, prices[max_profit_index])
            push!(innovation_production, target_production[max_profit_index])
            push!(innovation_brown_capital, brown_capital_list[max_profit_index])
            push!(innovation_green_capital, green_capital_list[max_profit_index])

        end

        for i in reverse(eachindex(innovation_profits))
            if (innovation_total_cost[i] > firm.money) || (innovation_profits[i] < 0)
                deleteat!(innovation_profits, i)
                deleteat!(innovation_total_cost, i)
                deleteat!(innovation_prices, i)
                deleteat!(innovation_production, i)
                deleteat!(innovation_brown_capital, i)
                deleteat!(innovation_green_capital, i)
                deleteat!(innovation_attributes, i)
            end
        end     

        if !isempty(innovation_profits) 
            max_profit_innovation = argmax(innovation_profits)
            total_cost = innovation_total_cost[max_profit_innovation]
            price = innovation_prices[max_profit_innovation]
            production_target = innovation_production[max_profit_innovation]
            green_capital = innovation_green_capital[max_profit_innovation]
            brown_capital = innovation_brown_capital[max_profit_innovation]
            new_greenness = innovation_attributes[max_profit_innovation][1]
            new_prestige = innovation_attributes[max_profit_innovation][2]

            println("Firm $(firm.brand) innovates. Old values: Price $(firm.price), Greenness $(firm.greenness), Prestige $(firm.prestige)")
            println("New values: Price $(price), Greenness $(new_greenness), Prestige $(new_prestige), Cost $(total_cost)")

            firm.money -= total_cost
            firm.inventory = production_target
            firm.price = price
            push!(firm.past_prices, firm.price)
            firm.green_capital = green_capital
            firm.brown_capital = brown_capital
            firm.total_capital = firm.green_capital + firm.brown_capital
            firm.greenness = new_greenness
            if new_greenness > 0.5
                firm.electric_car = true
            else
                firm.electric_car = false
            end
            firm.prestige = new_prestige

            if firm.existence_time >= 5
                price_average = mean(firm.past_prices[(firm.existence_time-4):(firm.existence_time)])
            else
                price_average = mean(firm.past_prices)
            end
            firm.innovation_try = 0
            firm.unsuccessful_innovation = false

            if new_greenness < 0.5 && new_prestige < 0.5
                firm.target_consumer_group = 1
            elseif new_greenness >= 0.5 && new_prestige < 0.5
                firm.target_consumer_group = 2
            elseif new_greenness >= 0.5 && new_prestige >= 0.5
                firm.target_consumer_group = 3
            elseif new_greenness < 0.5 && new_prestige >= 0.5
                firm.target_consumer_group = 4
            end

            if model.green_subsidy_activated && firm.greenness >= 0.5
                if model.activate_tax
                    if model.activate_tax_exemption
                        firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
                    else
                        firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate) - firm.manufacturer_subsidy - firm.state_subsidy
                    end
                else
                    firm.demand_price = firm.price - firm.manufacturer_subsidy - firm.state_subsidy
                end
            else
                if model.activate_tax
                    if model.activate_tax_exemption && firm.greenness >= 0.5
                        firm.demand_price = firm.price
                    else
                        firm.demand_price = firm.price * (1 + model.mean_length_of_ownership * model.tax_rate)
                    end
                else
                    firm.demand_price = firm.price
                end
            end
        else
            firm.unsuccessful_innovation = true
        end
        
    end

    firm.temporary_profit_list = []
end


function attribute_selection(firm::Firm, model::ABM, exploration)
    innovation_attributes = []

    lower_bound_greenness = clamp(firm.greenness - model.greenness_neighborhood * firm.innovation_try, 0.0, 1.0)
    upper_bound_greenness = clamp(firm.greenness + model.greenness_neighborhood * firm.innovation_try, 0.0, 1.0)

    radius_greenness = (upper_bound_greenness - lower_bound_greenness) / 2

    lower_bound_prestige = clamp(firm.prestige - model.prestige_neighborhood * firm.innovation_try, 0.0, 1.0)
    upper_bound_prestige = clamp(firm.prestige + model.prestige_neighborhood * firm.innovation_try, 0.0, 1.0)

    radius_prestige = (upper_bound_prestige - lower_bound_prestige) / 2

    if exploration
        for _ in 1:model.n_attribute_combinations
            
            new_greenness = rand(Uniform(lower_bound_greenness, upper_bound_greenness))
            new_prestige = rand(Uniform(lower_bound_prestige, upper_bound_prestige))

            new_greenness = clamp(new_greenness, 0.0, 1.0)
            new_prestige = clamp(new_prestige, 0.0, 1.0)

            push!(innovation_attributes, (new_greenness, new_prestige))
        end
    else
        probs = softmax(firm.sectors, model.sector_selection_prob)
        sector_width = 2pi / model.no_sectors

        for _ in 1:model.n_attribute_combinations
            chosen_sector = sample(1:model.no_sectors, Weights(probs))
            theta = (chosen_sector - 1) * sector_width + rand() * sector_width

            dx = cos(theta)
            dy = sin(theta)

            if radius_greenness > 0.05 && radius_prestige > 0.05
                new_greenness = clamp(firm.greenness + rand(Uniform(0.05,radius_greenness)) * dx, 0.0, 1.0)
                new_prestige = clamp(firm.prestige + rand(Uniform(0.05,radius_prestige)) * dy, 0.0, 1.0)
                push!(innovation_attributes, (new_greenness, new_prestige))
            else
                new_greenness = clamp(firm.greenness + 0.05 * dx, 0.0, 1.0)
                    new_prestige = clamp(firm.prestige + 0.05 * dy, 0.0, 1.0)
                push!(innovation_attributes, (new_greenness, new_prestige))
            end
        end

    end

    return innovation_attributes
end

function calculate_capital_adjustment(firm::Firm, model::ABM, additional_green_capital, additional_brown_capital, green_capital_target, brown_capital_target)

    if additional_green_capital > 0 && additional_brown_capital > 0
        adaptation_cost = model.green_capital_adaptation_costs * additional_green_capital + model.brown_capital_adaptation_costs * additional_brown_capital
        transformation_cost = 0
        green_capital = green_capital_target
        brown_capital = brown_capital_target
    elseif additional_green_capital > 0 && additional_brown_capital < 0
        if additional_green_capital >= abs(additional_brown_capital)
            transformed_capital = abs(additional_brown_capital)
            transformation_cost = model.transformation_cost_param * transformed_capital
            invested_capital = additional_green_capital - abs(additional_brown_capital)
            adaptation_cost = model.green_capital_adaptation_costs * invested_capital
            green_capital = green_capital_target
            brown_capital = brown_capital_target
        else
            transformed_capital = additional_green_capital
            transformation_cost = model.transformation_cost_param * transformed_capital
            adaptation_cost = 0
            green_capital = green_capital_target
            brown_capital = brown_capital_target + abs(additional_brown_capital) - additional_green_capital
        end
    elseif additional_green_capital < 0 && additional_brown_capital > 0
        if additional_brown_capital >= abs(additional_green_capital)
            transformed_capital = abs(additional_green_capital)
            transformation_cost = model.transformation_cost_param * transformed_capital
            invested_capital = additional_brown_capital - abs(additional_green_capital)
            adaptation_cost = model.brown_capital_adaptation_costs * invested_capital
            green_capital = green_capital_target
            brown_capital = brown_capital_target
        else
            transformed_capital = additional_brown_capital
            transformation_cost = model.transformation_cost_param * transformed_capital
            adaptation_cost = 0
            green_capital = green_capital_target + abs(additional_green_capital) - additional_brown_capital
            brown_capital = brown_capital_target
        end
    else
        transformation_cost = 0
        adaptation_cost = 0
        green_capital = firm.green_capital
        brown_capital = firm.brown_capital
    end

    return transformation_cost, adaptation_cost, green_capital, brown_capital
end

function top_consumer_group(firm::Firm, model::ABM)
    counts = [0,0,0,0]
    total_consumers = 0
    greenness = []
    budget = []
    for hh in model.households
        if hh.supplier == firm.firm_index
            g = hh.consumer_group
            if 1 <= g <= 4
                counts[g] += 1
            end
            total_consumers += 1
        end

        if hh.supplier == firm.firm_index && hh.time_of_use == 0
            push!(greenness, hh.env_preference)
            push!(budget, hh.normed_budget)
        end
    end
    relative_counts = counts ./ total_consumers
    firm.top_consumer_group = Int(argmax(relative_counts))
    firm.consumer_group_dist = counts
    firm.customer_base = sum(counts)
    if isempty(greenness)
        firm.average_consumer = (NaN, NaN)
    else
        firm.average_consumer = (mean(greenness), mean(budget))
    end    
end

function softmax(scores, beta)
    exps = exp.(beta .* scores)
    return exps ./ sum(exps)
end


function firm_entry(model::ABM, brand, class, seed_capital)
    average_price = mean(f.price for f in model.firms)
    newfirm = add_agent!(Firm, model)
    newfirm.firm_index = length(model.firms) + 1
    newfirm.brand = brand
    newfirm.class = class
    model.firm_by_index[newfirm.firm_index] = newfirm.id

    row = model.mean_greenness[model.mean_greenness.Class .== class, :]
    mu = row.Electric[1]
    greenness = clamp(mu, model.epsilon, 1.0 - model.epsilon)

    prestige = rand(Uniform((class-1) * 0.2, class * 0.2 - 0.1))
    
    price_range = range(model.demand_est_price_lower_bound * average_price, model.demand_est_price_upper_bound * average_price; length = model.high_n_price_points)

    profit = []
    prices = []
    production_range = []

    if greenness < 0.5 && prestige < 0.5
        newfirm.target_consumer_group = 1
    elseif greenness >= 0.5 && prestige < 0.5
        newfirm.target_consumer_group = 2
    elseif greenness >= 0.5 && prestige >= 0.5
        newfirm.target_consumer_group = 3
    elseif greenness < 0.5 && prestige >= 0.5
        newfirm.target_consumer_group = 4
    end

    total_market = collect(filter(hh -> hh.time_of_use >= hh.length_of_ownership - 3, model.households))
    target_group = filter(hh -> hh.consumer_group == newfirm.target_consumer_group, total_market)
    non_target_group = filter(hh -> hh.consumer_group != newfirm.target_consumer_group, total_market)
    
    target_group_sample_size = Int(floor(model.target_group_focus_weight * model.demand_pop_fraction * length(total_market)))
    remaining_groups_sample_size = Int(floor((1 - model.target_group_focus_weight) * model.demand_pop_fraction * length(total_market)))

    if target_group_sample_size > length(target_group)
        target_group_sample_size = length(target_group)
    end
    if remaining_groups_sample_size > length(non_target_group)
        remaining_groups_sample_size = length(non_target_group)
    end
    target_group_sample = sample(target_group, target_group_sample_size; replace = false)
    non_target_group_sample = sample(non_target_group, remaining_groups_sample_size; replace = false)
    
    hh_sample = vcat(target_group_sample, non_target_group_sample)
    
    for test_price in price_range
            
        simulated_purchases = 0

        if model.green_subsidy_activated && greenness >= 0.5
            if model.activate_tax
                if model.activate_tax_exemption
                    demand_price = test_price - newfirm.manufacturer_subsidy - newfirm.state_subsidy
                else
                    demand_price = test_price * (1 + model.tax_rate) - newfirm.manufacturer_subsidy - newfirm.state_subsidy
                end
            else
                demand_price = test_price - newfirm.manufacturer_subsidy - newfirm.state_subsidy
            end
        else
            if model.activate_tax
                if model.activate_tax_exemption && greenness >= 0.5
                    demand_price = test_price
                else
                    demand_price = test_price * (1 + model.tax_rate)
                end
            else
                demand_price = test_price 
            end
        end
        
        for hh in hh_sample
            bought = simulate_purchase_decision(hh, demand_price, newfirm.firm_index, greenness, prestige, model)
            if bought
                simulated_purchases += 1
            end
        end
        
        est_market_share = simulated_purchases / length(hh_sample)
        est_demand = est_market_share * length(total_market) * 1/4 * model.caution_factor
        
        marginal_cost = model.marginal_cost * (1 + prestige)^model.prestige_cost_exponent
        production = est_demand 
        green_capital = production * (model.alpha + (1-model.alpha) * (greenness/(1-greenness))^model.rho)^(-1/model.rho)
        brown_capital = production * (model.alpha + (1-model.alpha) * (greenness/(1-greenness))^model.rho)^(-1/model.rho) * (1-greenness)/greenness

        if model.green_subsidy_activated && greenness >= 0.5
            expected_profit = (test_price - newfirm.manufacturer_subsidy) * production - marginal_cost * production - model.green_capital_costs * green_capital - model.brown_capital_costs * brown_capital 
        else
            expected_profit = test_price * production - marginal_cost * production - model.green_capital_costs * green_capital - model.brown_capital_costs * brown_capital 
        end

        push!(production_range, production)
        push!(profit, expected_profit)
        push!(prices, test_price)
    end

    max_profit_index = argmax(profit)
    target_price = prices[max_profit_index]
    target_production = production_range[max_profit_index]

    newfirm.money = seed_capital
    newfirm.greenness = greenness
    newfirm.prestige = prestige
    
    expand_capital_stock(newfirm, model, target_production, target_price)
    
    if greenness > 0.5
        newfirm.electric_car = true
    end
    
    newfirm.total_capital = newfirm.green_capital + newfirm.brown_capital
    newfirm.marginal_cost = model.marginal_cost * (1 + prestige)^model.prestige_cost_exponent
    newfirm.sectors = zeros(model.no_sectors)
    newfirm.demand_update = rand(0:3)

    estimate_demand!(newfirm, model)

    push!(model.firms, newfirm)
    model.n_firms += 1
    

    for hh in model.households
        push!(hh.supplier_idx, newfirm.firm_index)
    end
end
