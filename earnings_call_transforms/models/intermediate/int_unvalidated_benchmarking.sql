-- TEMP to test staging table
SELECT *
FROM {{ ref('stg_benchmarking_analyst_subs') }}