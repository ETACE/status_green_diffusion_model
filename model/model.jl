using Agents, DataStructures, Random

include("agents/households.jl")
include("agents/firms.jl")

function household_scheduler(model::ABM)
    return shuffle(abmrng(model), model.households)
end

function households(f, model::ABM)
    for hh in household_scheduler(model)
        f(hh, model)
    end
end

function firm_scheduler(model::ABM)
    return shuffle(abmrng(model), model.firms)
end

function firms(f, model::ABM)
    for firm in firm_scheduler(model)
        f(firm, model)
    end
end

function model_day!(model)
    if abmtime(model) % 10 == 0
        println(abmtime(model))
    end

    push!(model.average_green_consumption, mean(map(hh -> hh.owned_product_greenness, model.households)))
    push!(model.average_prestige_consumption, mean(map(hh -> hh.owned_product_prestige, model.households)))

    model.av_prestige_cons_rich = mean(map(hh -> hh.owned_product_prestige, filter(hh -> hh.normed_budget >= 0.5, model.households)))
    model.av_prestige_cons_poor = mean(map(hh -> hh.owned_product_prestige, filter(hh -> hh.normed_budget < 0.5, model.households)))
    model.av_green_cons_green = mean(map(hh -> hh.owned_product_greenness, filter(hh -> hh.env_preference >= 0.5, model.households)))
    model.av_green_cons_non_green = mean(map(hh -> hh.owned_product_greenness, filter(hh -> hh.env_preference < 0.5, model.households)))

    # Policy
    # Environmental bonus
    if abmtime(model) == model.subsidy_start_period && model.enable_green_subsidy
        model.green_subsidy_activated = true
        println("Green subsidy policy activated.")
    end

    if abmtime(model) == model.subsidy_start_period + 16 && model.enable_green_subsidy
        firms(model) do firm, model
            if firm.price / mean(map(f -> f.price, model.firms)) < 40 / 36.340
                firm.state_subsidy = 3.659
                firm.manufacturer_subsidy = 1.929
            else            
                firm.state_subsidy = 3.210
                firm.manufacturer_subsidy = 1.605
            end
        end
    end

    if abmtime(model) == model.subsidy_start_period + 28 && model.enable_green_subsidy
        firms(model) do firm, model
            if firm.price / mean(map(f -> f.price, model.firms)) < 40 / 44.630
                firm.state_subsidy = 2.357
                firm.manufacturer_subsidy = 1.178
            else            
                firm.state_subsidy = 1.574
                firm.manufacturer_subsidy = 0.787
            end
        end
    end

    if abmtime(model) >= model.subsidy_start_period + 32 && model.enable_green_subsidy
        firms(model) do firm, model
            if firm.price / mean(map(f -> f.price, model.firms)) < 40 / 43.530
                firm.state_subsidy = 0.0
                firm.manufacturer_subsidy = 0.0
            else            
                firm.state_subsidy = 0.0
                firm.manufacturer_subsidy = 0.0
            end
        end
    end

    # Tax exemption
    if abmtime(model) == model.tax_exemption_start_period && model.enable_tax_exemption
        model.activate_tax_exemption = true
        println("Tax exemption policy activated.")
    end


    # Firms' and households' actions
    firms(model) do firm, model
        firm.existence_time += 1

        if (abmtime(model) >= model.burn_in_time && (abmtime(model) % 4 == firm.demand_update || firm.unsuccessful_innovation)) && model.enable_innovation
            innovation_decision(firm, model)
        end
    end

    if (abmtime(model) - 1) % 4 == 0
        firms(model) do firm, model
            reset_yearly_variables!(firm)
        end
    end

    firms(model) do firm, model
        reset_monthly_variables!(firm)
    end

    model.willing_to_buy = 0
    households(model) do hh, model
        update_product_use(hh, model)
        if hh.desire_to_replace_product
            model.willing_to_buy += 1
        end
        buy_product(hh, model)
    end

    model.ev_share_sales = sum(hh -> hh.ev_consumption, model.households) / sum(hh -> hh.consumption, model.households)

    firms(model) do firm, model
        if abmtime(model) % 4 == firm.demand_update || abmtime(model) == 0
            estimate_demand!(firm, model)
        end
    end


    firms(model) do firm, model
        production(firm, model)
        payments(firm, model)
        depreciate_capital(firm, model)
        top_consumer_group(firm, model)
    end

    # Firm entry
    if abmtime(model) == model.stage2_time
        firm_entry(model, model.eco_base_name, model.eco_base_class, model.seed_capital * model.entry_seed_capital_fraction)
        println("Eco Base enters the market.")
    end

    if (abmtime(model) == model.stage3_time) 
        firm_entry(model, model.eco_lux_name, model.eco_lux_class, model.seed_capital * model.entry_seed_capital_fraction)
        println("Eco Lux enters the market.")
    end

    if (abmtime(model) == model.stage4_time) 
        firm_entry(model, model.eco_mid_name, model.eco_mid_class, model.seed_capital * model.entry_seed_capital_fraction)
        println("Eco Mid enters the market.")
    end
end

