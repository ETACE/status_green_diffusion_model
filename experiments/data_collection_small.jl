using Statistics

when_collect(model, s) = abmtime(model) % 1 == 0

# Macro Data
market_penetration(m) = count(hh -> hh.owned_product_greenness > 0.5, m.households) / count(hh -> hh.owns_product, m.households)
ev_share_sales(m) = m.ev_share_sales

hh_dist(m) = [(h.normed_budget, h.env_preference) for h in m.households]

mdata = [market_penetration,hh_dist, ev_share_sales
    ]
adata = []