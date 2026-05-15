SELECT type,
executive_name,
corporation,
sector,
date_posted,
post_text,
url,
platform,
product

FROM {{ ref('int_on_demand_socials')}}