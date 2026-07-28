using Random

@agent struct Household(NoSpaceAgent)
    # Attributes
    env_preference::Float64 = 0.0
    budget::Float64 = 0.0
    normed_budget::Float64 = 0.0
    consumer_group::Int = 0
    green_distinction_weight::Float64 = 0.0
    material_distinction_weight::Float64 = 0.0
    
    # Consumption
    owned_product_brand::String = ""
    owned_product_greenness::Float64 = 0.0
    owned_product_prestige::Float64 = 0.0
    supplier::Int64 = 0
    desire_to_replace_product::Bool = false
    consumption::Bool = false
    ev_consumption::Bool = false
    time_of_use::Int = 0
    owns_product::Bool = true
    length_of_ownership::Int = 0
    supplier_idx::OrderedSet{Int64} = OrderedSet{Int64}()
    reference_group_green_imitation::Vector{Int64} = Vector{Int64}()
    reference_group_green_distinction::Vector{Int64} = Vector{Int64}()
    reference_group_prestige_imitation::Vector{Int64} = Vector{Int64}()
    reference_group_prestige_distinction::Vector{Int64} = Vector{Int64}()

    # Data collection
    total_utility::Float64 = 0.0
    green_status_utility::Float64 = 0.0
    green_distinction::Float64 = 0.0
    green_imitation::Float64 = 0.0
    prestige_status_utility::Float64 = 0.0
    prestige_distinction::Float64 = 0.0
    prestige_imitation::Float64 = 0.0
    status_utility::Float64 = 0.0
    remaining_budget_utility::Float64 = 0.0
    identity_utility::Float64 = 0.0
end

function update_product_use(hh:: Household, model::ABM)
    hh.consumption = false
    hh.ev_consumption = false
    hh.time_of_use += 1

    if !hh.desire_to_replace_product
        if hh.time_of_use >= hh.length_of_ownership
            hh.desire_to_replace_product = true
            hh.owns_product = false
        end
    end

end


function calculate_utility(hh::Household, model::ABM, supplier, price, greenness, prestige)

    utility = Dict()
        
    utility_remaining_budget = model.remaining_budget_scaling_param * ((hh.budget - price)/hh.budget)^0.5
    identity_utility = - model.identity_scaling * abs(hh.env_preference - greenness) 

    if abmtime(model) >= 4
        average_green_consumption = mean(model.average_green_consumption[end-3:end])
        average_prestige_consumption = mean(model.average_prestige_consumption[end-3:end])
    else
        average_green_consumption = model.average_green_consumption[end]
        average_prestige_consumption = model.average_prestige_consumption[end]
    end

    green_distinction = max(0, (greenness - model.av_green_cons_non_green)/(1 - model.av_green_cons_non_green + 1e-6))
    green_imitation = min(1, greenness/model.av_green_cons_green) 
    green_status = average_green_consumption * (hh.green_distinction_weight * green_distinction + (1 - hh.green_distinction_weight) * green_imitation) 

    prestige_distinction = max(0, (prestige - model.av_prestige_cons_poor)/(1 - model.av_prestige_cons_poor + 1e-6))
    prestige_imitation = min(1, prestige/model.av_prestige_cons_rich) 
    prestige_status = average_prestige_consumption * (hh.material_distinction_weight * prestige_distinction + (1 - hh.material_distinction_weight) * prestige_imitation) 

    product_time_horizon = hh.length_of_ownership

    product_utility = utility_remaining_budget + sum(model.discount_param^t * (identity_utility + prestige_status + green_status) for t in 0:product_time_horizon) 

    utility["utility_remaining_budget"] = utility_remaining_budget
    utility["utility_identity"] = sum(model.discount_param^t * (identity_utility) for t in 0:product_time_horizon)
    utility["discounted_green_status"] = sum(model.discount_param^t * (green_status) for t in 0:product_time_horizon)
    utility["green_distinction"] = sum(model.discount_param^t * (hh.green_distinction_weight * green_distinction) for t in 0:product_time_horizon)
    utility["green_imitation"] = sum(model.discount_param^t * ((1 - hh.green_distinction_weight) * green_imitation) for t in 0:product_time_horizon)
    utility["discounted_prestige_status"] = sum(model.discount_param^t * (prestige_status) for t in 0:product_time_horizon)
    utility["prestige_distinction"] = sum(model.discount_param^t * (hh.material_distinction_weight * prestige_distinction) for t in 0:product_time_horizon)
    utility["prestige_imitation"] = sum(model.discount_param^t * ((1 - hh.material_distinction_weight) * prestige_imitation) for t in 0:product_time_horizon)
    utility["product_utility"] = product_utility

    return utility

end

function buy_product(hh::Household, model::ABM)
    if hh.desire_to_replace_product

        # Filter products that are in households' budget
        potential_supplier_idxs = []

        for supplier_idx in hh.supplier_idx
            supplier = model[model.firm_by_index[supplier_idx]]

            if model.activate_tax
                if supplier.greenness >= 0.5 && !model.activate_tax_exemption
                    if model.green_subsidy_activated
                        demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate) - supplier.manufacturer_subsidy - supplier.state_subsidy
                    else
                        demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                    end
                elseif supplier.greenness >= 0.5 && model.activate_tax_exemption
                    demand_price = supplier.demand_price
                elseif supplier.greenness < 0.5
                    demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                end
            else
                demand_price = supplier.demand_price
            end

            if demand_price <= hh.budget
                push!(potential_supplier_idxs, supplier_idx)
            end
        end


        if !isempty(potential_supplier_idxs)
            # Calculate utilities of products
            utility_remaining_budget = []
            utility_identity = []
            utility_green_status = []
            utility_green_distinction = []
            utility_green_imitation = []
            utility_prestige_status = []
            utility_prestige_distinction = []
            utility_prestige_imitation = []
            utility_status = []
            product_utilities = []
            
            for supplier_idx in potential_supplier_idxs
                supplier = model[model.firm_by_index[supplier_idx]]

                if model.activate_tax
                    if supplier.greenness >= 0.5 && !model.activate_tax_exemption
                        if model.green_subsidy_activated
                            demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate) - supplier.manufacturer_subsidy - supplier.state_subsidy
                        else
                            demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                        end
                    elseif supplier.greenness >= 0.5 && model.activate_tax_exemption
                        demand_price = supplier.demand_price
                    elseif supplier.greenness < 0.5
                        demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                    end
                else
                    demand_price = supplier.demand_price
                end
             
                utility_dict = calculate_utility(hh, model, supplier, demand_price, supplier.greenness, supplier.prestige)

                push!(utility_remaining_budget, utility_dict["utility_remaining_budget"])
                push!(utility_identity, utility_dict["utility_identity"])
                push!(utility_green_status, utility_dict["discounted_green_status"])
                push!(utility_green_distinction, utility_dict["green_distinction"])
                push!(utility_green_imitation, utility_dict["green_imitation"])
                push!(utility_prestige_status, utility_dict["discounted_prestige_status"])
                push!(utility_prestige_distinction, utility_dict["prestige_distinction"])
                push!(utility_prestige_imitation, utility_dict["prestige_imitation"])
                push!(utility_status, utility_dict["discounted_green_status"] + utility_dict["discounted_prestige_status"])
                push!(product_utilities, utility_dict["product_utility"])
            end

            bought_product = false

            while !bought_product
                chosen_product_index = argmax(product_utilities)
                chosen_supplier_idx = potential_supplier_idxs[chosen_product_index]
                chosen_supplier = model[model.firm_by_index[chosen_supplier_idx]]

                if product_utilities[chosen_product_index] > 0
                    if chosen_supplier.inventory >= 1 

                        hh.owned_product_brand = chosen_supplier.brand
                        hh.owned_product_greenness = chosen_supplier.greenness
                        hh.owned_product_prestige = chosen_supplier.prestige
                        
                        hh.supplier = chosen_supplier_idx
                        hh.total_utility = product_utilities[chosen_product_index]

                        hh.green_status_utility = utility_green_status[chosen_product_index]
                        hh.green_distinction = utility_green_distinction[chosen_product_index]
                        hh.green_imitation = utility_green_imitation[chosen_product_index]
                        
                        hh.prestige_status_utility = utility_prestige_status[chosen_product_index]
                        hh.prestige_distinction = utility_prestige_distinction[chosen_product_index]
                        hh.prestige_imitation = utility_prestige_imitation[chosen_product_index]

                        hh.status_utility = utility_status[chosen_product_index]
                        hh.remaining_budget_utility = utility_remaining_budget[chosen_product_index]
                        hh.identity_utility = utility_identity[chosen_product_index]
                    
                        if model.green_subsidy_activated && chosen_supplier.greenness >= 0.5
                            chosen_supplier.revenue += chosen_supplier.price - model.manufacturer_subsidy
                        else
                            chosen_supplier.revenue += chosen_supplier.price
                        end
                        chosen_supplier.sales += 1
                        chosen_supplier.cum_registrations += 1
                        chosen_supplier.demand += 1
                        chosen_supplier.inventory -= 1

                        bought_product = true
                        hh.desire_to_replace_product = false

                        if chosen_supplier.greenness >= 0.5
                            hh.ev_consumption = true
                        else
                            hh.ev_consumption = false
                        end
                        
                        hh.consumption = true
                        hh.time_of_use = 0
                        hh.owns_product = true
                    
                    else
                        chosen_supplier.demand += 1
                        deleteat!(product_utilities, chosen_product_index)
                        deleteat!(utility_green_status, chosen_product_index)
                        deleteat!(utility_green_distinction, chosen_product_index)
                        deleteat!(utility_green_imitation, chosen_product_index)
                        deleteat!(utility_prestige_status, chosen_product_index)
                        deleteat!(utility_prestige_distinction, chosen_product_index)
                        deleteat!(utility_prestige_imitation, chosen_product_index)
                        deleteat!(utility_status, chosen_product_index)
                        deleteat!(utility_remaining_budget, chosen_product_index)
                        deleteat!(utility_identity, chosen_product_index)
                        deleteat!(potential_supplier_idxs, chosen_product_index)
                    end
                else
                    break
                end

                # If household is unable to buy a product
                if isempty(potential_supplier_idxs)
                    break
                end
            
            end
        end

    end


end

function simulate_purchase_decision(hh::Household, test_price, index, greenness, prestige, model::ABM)
    if test_price > hh.budget
        return false
    else
        potential_supplier_idxs = [index]

        for supplier_idx in hh.supplier_idx
            if supplier_idx != index
                supplier = model[model.firm_by_index[supplier_idx]]

                if model.activate_tax
                    if supplier.greenness >= 0.5 && !model.activate_tax_exemption
                        if model.green_subsidy_activated
                            demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate) - supplier.manufacturer_subsidy - supplier.state_subsidy
                        else
                            demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                        end
                    elseif supplier.greenness >= 0.5 && model.activate_tax_exemption
                        demand_price = supplier.demand_price
                    elseif supplier.greenness < 0.5
                        demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                    end
                else
                    demand_price = supplier.demand_price
                end
                
                if demand_price <= hh.budget
                    push!(potential_supplier_idxs, supplier_idx)
                end
            end
        end


        product_utilities = []

        for supplier_idx in potential_supplier_idxs
            supplier = model[model.firm_by_index[supplier_idx]]

            if model.activate_tax
                if supplier.greenness >= 0.5 && !model.activate_tax_exemption
                    if model.green_subsidy_activated
                        demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate) - supplier.manufacturer_subsidy - supplier.state_subsidy
                    else
                        demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                    end
                elseif supplier.greenness >= 0.5 && model.activate_tax_exemption
                    demand_price = supplier.demand_price
                elseif supplier.greenness < 0.5
                    demand_price = supplier.price * (1 + hh.length_of_ownership * model.tax_rate)
                end
            else
                demand_price = supplier.demand_price
            end
            
            if supplier_idx == index
                product_utility = calculate_utility(hh, model, supplier, test_price, greenness, prestige)["product_utility"]
            else
                product_utility = calculate_utility(hh, model, supplier, demand_price, supplier.greenness, supplier.prestige)["product_utility"]
            end

            push!(product_utilities, product_utility)
        end

        chosen_product_index = argmax(product_utilities)
        chosen_supplier_idx = potential_supplier_idxs[chosen_product_index]

        return chosen_supplier_idx == index

    end
end
