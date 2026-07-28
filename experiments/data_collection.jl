using Statistics

when_collect(model, s) = abmtime(model) % 1 == 0


# Macro Data
market_penetration(m) = count(hh -> hh.owned_product_greenness > 0.5, m.households) / count(hh -> hh.owns_product, m.households)
ev_share_sales(m) = m.ev_share_sales
hh_index(m) = sum(map(f -> (f.yearly_sales / sum(f.yearly_sales for f in m.firms))^2, m.firms))
concentration_rate_three(m) = sum(sort(collect(map(f -> f.yearly_market_share, m.firms)), rev=true)[1:3])
green_prestige_ratio(m) = m.average_green_consumption[end] / m.average_prestige_consumption[end]
average_weighted_price(m) = (sum(map(f -> f.price * f.yearly_sales, m.firms)) / sum(f.yearly_sales for f in m.firms))

# Firm Data
MAX_FIRMS = 11

function get_firm_by_index(m, idx)
    idx ≤ length(m.firms) ? m.firms[idx] : missing
end

fields = (
    :yearly_production, :price, :demand_price, :money, :green_capital, :brown_capital, :total_capital,
    :greenness, :prestige, :inventory, :yearly_profit, :sales, :demand, :capital_cost_share, :production_cost_share, 
    :yearly_revenue, :yearly_market_share, :market_share_electric_market,
    :yearly_capital_cost, :yearly_production_cost, :top_consumer_group, :consumer_group_dist, :first_registration_share,
    :average_consumer, :cum_registrations
)


# Household Data
consumption_group1(m) = sum(map( hh -> hh.consumption, filter(hh -> hh.consumer_group == 1, m.households)))
consumption_group2(m) = sum(map( hh -> hh.consumption, filter(hh -> hh.consumer_group == 2, m.households)))
consumption_group3(m) = sum(map( hh -> hh.consumption, filter(hh -> hh.consumer_group == 3, m.households)))
consumption_group4(m) = sum(map( hh -> hh.consumption, filter(hh -> hh.consumer_group == 4, m.households)))
owned_product_greenness_group1(m) = mean(map( hh -> hh.owned_product_greenness, filter(hh -> hh.consumer_group == 1, m.households)))
owned_product_greenness_group2(m) = mean(map( hh -> hh.owned_product_greenness, filter(hh -> hh.consumer_group == 2, m.households)))
owned_product_greenness_group3(m) = mean(map( hh -> hh.owned_product_greenness, filter(hh -> hh.consumer_group == 3, m.households)))
owned_product_greenness_group4(m) = mean(map( hh -> hh.owned_product_greenness, filter(hh -> hh.consumer_group == 4, m.households)))
owned_product_prestige_group1(m) = mean(map( hh -> hh.owned_product_prestige, filter(hh -> hh.consumer_group == 1, m.households)))
owned_product_prestige_group2(m) = mean(map( hh -> hh.owned_product_prestige, filter(hh -> hh.consumer_group == 2, m.households)))
owned_product_prestige_group3(m) = mean(map( hh -> hh.owned_product_prestige, filter(hh -> hh.consumer_group == 3, m.households)))
owned_product_prestige_group4(m) = mean(map( hh -> hh.owned_product_prestige, filter(hh -> hh.consumer_group == 4, m.households)))
share_owners_group1(m) = sum(hh -> hh.owns_product, filter(hh -> hh.consumer_group == 1, m.households))/count(hh -> hh.consumer_group == 1, m.households)
share_owners_group2(m) = sum(hh -> hh.owns_product, filter(hh -> hh.consumer_group == 2, m.households))/count(hh -> hh.consumer_group == 2, m.households)
share_owners_group3(m) = sum(hh -> hh.owns_product, filter(hh -> hh.consumer_group == 3, m.households))/count(hh -> hh.consumer_group == 3, m.households)
share_owners_group4(m) = sum(hh -> hh.owns_product, filter(hh -> hh.consumer_group == 4, m.households))/count(hh -> hh.consumer_group == 4, m.households)
customer_base_firm1(m) = sum(map( hh -> hh.supplier == 1, m.households))
customer_base_firm2(m) = sum(map( hh -> hh.supplier == 2, m.households))
customer_base_firm3(m) = sum(map( hh -> hh.supplier == 3, m.households))
customer_base_firm4(m) = sum(map( hh -> hh.supplier == 4, m.households))
customer_base_firm5(m) = sum(map( hh -> hh.supplier == 5, m.households))
customer_base_firm6(m) = sum(map( hh -> hh.supplier == 6, m.households))
customer_base_firm7(m) = sum(map( hh -> hh.supplier == 7, m.households))
customer_base_firm8(m) = sum(map( hh -> hh.supplier == 8, m.households))
customer_base_firm9(m) = sum(map( hh -> hh.supplier == 9, m.households))
customer_base_firm10(m) = sum(map( hh -> hh.supplier == 10, m.households))
customer_base_firm11(m) = sum(map( hh -> hh.supplier == 11, m.households))
households_willing_to_buy(m) = m.willing_to_buy

# Utility data for customers who bought in the current period
status_utility_firm1_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 1 && hh.time_of_use == 0, m.households)))
status_utility_firm2_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 2 && hh.time_of_use == 0, m.households)))
status_utility_firm3_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 3 && hh.time_of_use == 0, m.households)))
status_utility_firm4_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 4 && hh.time_of_use == 0, m.households)))
status_utility_firm5_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 5 && hh.time_of_use == 0, m.households)))
status_utility_firm6_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 6 && hh.time_of_use == 0, m.households)))
status_utility_firm7_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 7 && hh.time_of_use == 0, m.households)))
status_utility_firm8_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 8 && hh.time_of_use == 0, m.households)))
status_utility_firm9_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 9 && hh.time_of_use == 0, m.households)))
status_utility_firm10_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 10 && hh.time_of_use == 0, m.households)))
status_utility_firm11_customers(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.supplier == 11 && hh.time_of_use == 0, m.households)))

total_utility_group1(m) = mean(map( hh -> hh.total_utility, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
total_utility_group2(m) = mean(map( hh -> hh.total_utility, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
total_utility_group3(m) = mean(map( hh -> hh.total_utility, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
total_utility_group4(m) = mean(map( hh -> hh.total_utility, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))

green_status_group1(m) = mean(map( hh -> hh.green_status_utility, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
green_status_group2(m) = mean(map( hh -> hh.green_status_utility, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
green_status_group3(m) = mean(map( hh -> hh.green_status_utility, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
green_status_group4(m) = mean(map( hh -> hh.green_status_utility, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))
green_distinction_group1(m) = mean(map( hh -> hh.green_distinction, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
green_distinction_group2(m) = mean(map( hh -> hh.green_distinction, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
green_distinction_group3(m) = mean(map( hh -> hh.green_distinction, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
green_distinction_group4(m) = mean(map( hh -> hh.green_distinction, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))
green_imitation_group1(m) = mean(map( hh -> hh.green_imitation, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
green_imitation_group2(m) = mean(map( hh -> hh.green_imitation, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
green_imitation_group3(m) = mean(map( hh -> hh.green_imitation, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
green_imitation_group4(m) = mean(map( hh -> hh.green_imitation, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))

prestige_status_group1(m) = mean(map( hh -> hh.prestige_status_utility, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
prestige_status_group2(m) = mean(map( hh -> hh.prestige_status_utility, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
prestige_status_group3(m) = mean(map( hh -> hh.prestige_status_utility, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
prestige_status_group4(m) = mean(map( hh -> hh.prestige_status_utility, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))
prestige_distinction_group1(m) = mean(map( hh -> hh.prestige_distinction, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
prestige_distinction_group2(m) = mean(map( hh -> hh.prestige_distinction, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
prestige_distinction_group3(m) = mean(map( hh -> hh.prestige_distinction, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
prestige_distinction_group4(m) = mean(map( hh -> hh.prestige_distinction, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))
prestige_imitation_group1(m) = mean(map( hh -> hh.prestige_imitation, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
prestige_imitation_group2(m) = mean(map( hh -> hh.prestige_imitation, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
prestige_imitation_group3(m) = mean(map( hh -> hh.prestige_imitation, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
prestige_imitation_group4(m) = mean(map( hh -> hh.prestige_imitation, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))

status_group1(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
status_group2(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
status_group3(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
status_group4(m) = mean(map( hh -> hh.status_utility, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))

identity_utility_group1(m) = mean(map( hh -> hh.identity_utility, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
identity_utility_group2(m) = mean(map( hh -> hh.identity_utility, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
identity_utility_group3(m) = mean(map( hh -> hh.identity_utility, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
identity_utility_group4(m) = mean(map( hh -> hh.identity_utility, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))
utility_remaining_budget_group1(m) = mean(map( hh -> hh.remaining_budget_utility, filter(hh -> hh.consumer_group == 1 && hh.time_of_use == 0, m.households)))
utility_remaining_budget_group2(m) = mean(map( hh -> hh.remaining_budget_utility, filter(hh -> hh.consumer_group == 2 && hh.time_of_use == 0, m.households)))
utility_remaining_budget_group3(m) = mean(map( hh -> hh.remaining_budget_utility, filter(hh -> hh.consumer_group == 3 && hh.time_of_use == 0, m.households)))
utility_remaining_budget_group4(m) = mean(map( hh -> hh.remaining_budget_utility, filter(hh -> hh.consumer_group == 4 && hh.time_of_use == 0, m.households)))



mdata = [market_penetration, ev_share_sales, hh_index, concentration_rate_three, green_prestige_ratio, average_weighted_price,
        consumption_group1, consumption_group2, consumption_group3, consumption_group4,
        owned_product_greenness_group1, owned_product_greenness_group2, owned_product_greenness_group3, owned_product_greenness_group4,
        owned_product_prestige_group1, owned_product_prestige_group2, owned_product_prestige_group3, owned_product_prestige_group4,
        share_owners_group1, share_owners_group2, share_owners_group3, share_owners_group4,
        customer_base_firm1, customer_base_firm2, customer_base_firm3, customer_base_firm4, customer_base_firm5, customer_base_firm6, customer_base_firm7, customer_base_firm8, 
        customer_base_firm9, customer_base_firm10, customer_base_firm11,
        status_utility_firm1_customers, status_utility_firm2_customers, status_utility_firm3_customers, status_utility_firm4_customers, status_utility_firm5_customers, status_utility_firm6_customers, status_utility_firm7_customers, status_utility_firm8_customers,
        status_utility_firm9_customers, status_utility_firm10_customers, status_utility_firm11_customers, households_willing_to_buy,
        total_utility_group1, total_utility_group2, total_utility_group3, total_utility_group4,
        green_status_group1, green_status_group2, green_status_group3, green_status_group4,
        green_distinction_group1, green_distinction_group2, green_distinction_group3, green_distinction_group4,
        green_imitation_group1, green_imitation_group2, green_imitation_group3, green_imitation_group4,
        prestige_status_group1, prestige_status_group2, prestige_status_group3, prestige_status_group4,
        prestige_distinction_group1, prestige_distinction_group2, prestige_distinction_group3, prestige_distinction_group4,
        prestige_imitation_group1, prestige_imitation_group2, prestige_imitation_group3, prestige_imitation_group4,
        status_group1, status_group2, status_group3, status_group4,
        identity_utility_group1, identity_utility_group2, identity_utility_group3, identity_utility_group4,
        utility_remaining_budget_group1, utility_remaining_budget_group2, utility_remaining_budget_group3, utility_remaining_budget_group4
    ]

vector_fields = Set([:consumer_group_dist])
tuple_fields = Set([:average_consumer])

for idx in 1:MAX_FIRMS
    for field in fields
        let f = field, i = idx
            name = Symbol("firm_", i, "_", f)
            func = eval(quote
                function $name(m)
                    firm = get_firm_by_index(m, $i)
                    if firm === missing
                        if $(f in vector_fields)
                            return zeros(4)
                        elseif $(f in tuple_fields)
                            return (0.0, 0.0)
                        else
                            return NaN
                        end
                    else
                        return getfield(firm, $(QuoteNode(f)))
                    end
                end
                $name
            end)
            push!(mdata, func)
        end
    end
end

adata = []