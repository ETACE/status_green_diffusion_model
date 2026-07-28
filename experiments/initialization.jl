using Distributions, CSV, DataFrames
include("../model/agents/households.jl")

baseline_properties = Dict(
    # Macro parameters
    :n_households => 5000,
    :n_firms => 8,
    :firm_by_index => Dict{Int, Int}(),
    :burn_in_time => 100,
    :epsilon => 0.025,

    :stage1_time => 0,
    :stage2_time => 0,
    :stage3_time => 0,
    :stage4_time => 0,
    :ev_share_sales => 0.0,

    # Policy parameters
    :enable_green_subsidy => true,
    :green_subsidy_activated => false,
    :subsidy_start_period => 0,
    :state_subsidy => 1.577,
    :manufacturer_subsidy => 1.577,
    :enable_tax_exemption => true,
    :activate_tax_exemption => false,
    :activate_tax => true,
    :tax_exemption_start_period => 0,
    :tax_rate => 0.00145, 

    # Household parameters
    :mean_length_of_ownership => 24,
    :std_length_of_ownership => 10,
    :identity_scaling => 0.53,
    :discount_param => 0.975,
    :remaining_budget_scaling_param => 0.01,
    :uniform_env_preference => false,
    :data_env_preferences => nothing,
    :mean_env_preference => 0,
    :mean_budget => 26.03,
    :mean_normed_budget => 0,
    :beta_scaling1 => 1.75,
    :beta_scaling2 => 2.75,
    :average_green_consumption => [0.0],
    :average_prestige_consumption => [0.0],
    :av_prestige_cons_rich => 0,
    :av_prestige_cons_poor => 0,
    :av_green_cons_green => 0,
    :av_green_cons_non_green => 0,
    :willing_to_buy => 0,

    # Firm parameters
    :seed_capital => 1000,
    :brand_names => ["Comp 1", "Comp 2", "Comp 3", "Comp 4", "Comp 5", "Comp 6", "Comp 7", "Comp 8"],        
    :firm_classes => [1, 2, 2, 2, 3, 3, 4, 5],
    :mean_greenness => nothing,
    :eco_base_name => "Eco Base",
    :eco_lux_name => "Eco Lux",
    :eco_mid_name => "Eco Mid",
    :eco_base_class => 1,
    :eco_lux_class => 5,
    :eco_mid_class => 3,
    :entry_seed_capital_fraction => 0.25,
    :capital_depreciation => 0.035,
    :green_capital_costs => 0.325,
    :brown_capital_costs => 0.25,
    :green_capital_adaptation_costs => 1.3,
    :brown_capital_adaptation_costs => 1,
    :alpha => 0.5,
    :rho => 1.5,
    :marginal_cost => 3,
    :prestige_cost_exponent => 4,
    :prestige_update_cost_param => 5,
    :demand_est_price_lower_bound => 0.05,
    :demand_est_price_upper_bound => 2,
    :caution_factor => 0.25,
    :demand_pop_fraction => 0.1,
    :target_group_focus_weight => 0.8,
    :high_n_price_points => 100,
    :narrow_price_range => 0.03,
    :small_n_price_points => 20,
    :n_attribute_combinations => 3,
    :greenness_neighborhood => 0.05,
    :prestige_neighborhood => 0.05,
    :transformation_cost_param => 4,
    :enable_innovation => true,
    :enable_imitation => true,
    :no_sectors => 16,
    :sector_selection_prob => 0.1,
    :sector_decay => 0.6,

    :firms => Array{Firm},
    :households => Array{Household}
)

function initialize_model(properties)
    model = StandardABM(Union{Household, Firm}, model_step! = model_day!, properties = properties, warn = false)

    model.stage1_time = model.burn_in_time + 0
    model.stage2_time = model.burn_in_time + 4
    model.stage3_time = model.burn_in_time + 8
    model.stage4_time = model.burn_in_time + 28

    model.subsidy_start_period = model.burn_in_time + 24
    model.tax_exemption_start_period = model.burn_in_time + 4

    model.data_env_preferences = CSV.read("data/data_env_preferences.csv", DataFrame, header = false)[:,1]
    s = sample(model.data_env_preferences, model.n_households, replace = false)
    model.mean_env_preference = mean(s)
    
    beta_dist = Beta(model.beta_scaling1,model.beta_scaling2) 
    budget_samples_normed = rand(abmrng(model), beta_dist, model.n_households)
    budget_samples = budget_samples_normed * model.mean_budget/mean(budget_samples_normed)
    minimum_budget = minimum(budget_samples)
    maximum_budget = maximum(budget_samples)
    model.mean_normed_budget = mean(budget_samples_normed)

    model.mean_greenness = CSV.read("data/mean_greenness.csv", DataFrame)

    # Firms
    model.firms = Array{Firm, 1}()
    prices = []
    prestige = []
    greenness = []

    for i in 1:model.n_firms
        firm = add_agent!(Firm, model)

        firm.firm_index = i

        firm.brand = model.brand_names[i]
        firm.class = model.firm_classes[i]
        firm.inventory = 0.25 * model.n_households / model.n_firms
        firm.prestige = rand(Uniform((model.firm_classes[i]-1) * 0.2, model.firm_classes[i] * 0.2))
        row = model.mean_greenness[model.mean_greenness.Class .== firm.class, :]
        mu = row.Gas[1]
        firm.greenness = clamp(mu, model.epsilon, 1.0 - model.epsilon) 
        push!(greenness, firm.greenness)
        
        firm.green_capital = firm.greenness
        firm.brown_capital = 1 - firm.green_capital
        
        push!(prestige, firm.prestige)
        firm.price = (maximum_budget * 0.95 - (minimum_budget + 5)) * firm.prestige + 5 + minimum_budget
        push!(prices, firm.price)
        
        firm.money = model.seed_capital

        firm.sectors = zeros(model.no_sectors)
        firm.marginal_cost = model.marginal_cost * (1 + firm.prestige)^model.prestige_cost_exponent
        firm.demand_update = rand(0:3)

        if firm.greenness < 0.5 && firm.prestige < 0.5
            firm.target_consumer_group = 1
        elseif firm.greenness >= 0.5 && firm.prestige < 0.5
            firm.target_consumer_group = 2
        elseif firm.greenness >= 0.5 && firm.prestige >= 0.5
            firm.target_consumer_group = 3
        elseif firm.greenness < 0.5 && firm.prestige >= 0.5
            firm.target_consumer_group = 4
        end

        firm.state_subsidy = model.state_subsidy
        firm.manufacturer_subsidy = model.manufacturer_subsidy
        
        push!(model.firms, firm)
        model.firm_by_index[i] = firm.id
    end


    # Households
    model.households = Array{Household, 1}()
    env_preference = []
    group1 = 0
    group2 = 0
    group3 = 0
    group4 = 0

    for i in 1:model.n_households
        hh = add_agent!(Household, model)

        if model.uniform_env_preference
            hh.env_preference = rand(abmrng(model), Uniform(0, 1))
        else
            hh.env_preference = s[i]
        end
        push!(env_preference, hh.env_preference)

        hh.budget = budget_samples[i]
        hh.normed_budget = budget_samples_normed[i]
        
        # Assign consumer group
        if hh.env_preference < 0.5 && hh.normed_budget <= 0.5
            hh.consumer_group = 1
            group1 += 1
        elseif hh.env_preference >= 0.5 && hh.normed_budget <= 0.5
            hh.consumer_group = 2
            group2 += 1
        elseif hh.env_preference >= 0.5 && hh.normed_budget > 0.5
            hh.consumer_group = 3
            group3 += 1
        elseif hh.env_preference < 0.5 && hh.normed_budget > 0.5
            hh.consumer_group = 4
            group4 += 1
        end

        for s in model.firms
            push!(hh.supplier_idx, s.firm_index)
        end

        push!(model.households, hh)
    end

    for hh in model.households
        if hh.consumer_group == 1
            hh.green_distinction_weight = 0
            hh.material_distinction_weight = 0
        elseif hh.consumer_group == 2
            hh.green_distinction_weight = 1
            hh.material_distinction_weight = 0
        elseif hh.consumer_group == 3
            hh.green_distinction_weight = 1
            hh.material_distinction_weight = 1
        elseif hh.consumer_group == 4
            hh.green_distinction_weight = 0
            hh.material_distinction_weight = 1
        end
       

        hh.length_of_ownership = floor(rand(Normal(model.mean_length_of_ownership, model.std_length_of_ownership)))
        if hh.length_of_ownership < 4
            hh.length_of_ownership = 4
        end
        hh.time_of_use = floor(rand(Uniform(0, hh.length_of_ownership)))
      
        index = []
        for i in 1:length(prices)
            if prices[i] <= hh.budget
                push!(index, i)
            end
        end
        if !isempty(index) 
            random_index = rand(index)
            hh.owned_product_prestige = prestige[random_index]
        else
            hh.owned_product_prestige = 0
        end
        distance = []
        for i in 1:length(greenness)
            push!(distance, abs(greenness[i] - hh.env_preference))
        end
        closest_greenness_index = findmin(distance)[2]
        hh.owned_product_greenness = greenness[closest_greenness_index]
    end

    return model
end