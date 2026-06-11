{{ config(schema='social_media_activity_archive') }} -- Override default schema (dataset assignment) to build in the benchmarking BQ dataset

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