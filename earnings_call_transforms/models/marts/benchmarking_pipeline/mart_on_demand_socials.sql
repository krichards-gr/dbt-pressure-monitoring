{{
    config(
        schema='social_media_activity_archive',
        materialized = 'table',
        partition_by = {
            "field": "date_posted",
            "data_type": "timestamp",
            "granularity": "day"
        },
        cluster_by = ['corporation', 'sector', 'platform', 'product']
    )
}}

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