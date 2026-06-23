{{ config(schema='risk_index_data') }}

WITH consolidated_metrics AS (
    SELECT
        cd.category,
        cd.quarter_start,
        weekly_average,
        percent_change_vs_rolling_avg,
        inter_issue_score,
        intra_issue_score,
        combined_score,
        engagement_count,
        backlash_count,
        engagement_score,
        backlash_score,
        political_rhetoric_rating,
        legislation_rating,
        litigation_rating,
        major_moments_rating,
        reputational_and_operational_impact_rating,
        polarization_rating    

        FROM {{ ref('int_consolidated_data') }} cd

        LEFT JOIN {{ ref('int_issue_inputs') }} ii
        ON TRIM(LOWER(cd.category)) = TRIM(LOWER(ii.category)) AND cd.quarter_start = ii.quarter_start
),

averaged_components AS (
    SELECT
        (political_rhetoric_rating + legislation_rating + litigation_rating + major_moments_rating) / 4 AS staying_power_avg,
        (engagement_score + backlash_score + reputational_and_operational_impact_rating) / 3 AS business_impact_avg,
        (inter_issue_score + intra_issue_score) / 2 AS volume_avg,
        polarization_rating AS polarization_avg

    FROM consolidated_metrics
),

weighted_components AS (
    SELECT
        business_impact_avg * 0.5 AS business_impact_weighted,
        ((staying_power_avg + volume_avg + polarization_avg) / 3) * 0.5 AS other_weighted

    FROM averaged_components
),

raw_scores AS (
    SELECT
        business_impact_weighted + other_weighted AS raw_score

    FROM weighted_components
),

normalized_scores AS (
    SELECT
        raw_score,
        (raw_score / 4) * 100 AS normalized_score

    FROM raw_scores
)

SELECT
    category,
    quarter_start,
    raw_score,
    normalized_score,
    normalized_score / 10 AS risk_index_score

FROM normalized_scores