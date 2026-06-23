{{ config(schema='risk_index_data') }}

SELECT 
  quarter_start,
  timestamp,
  email_address,
  category,
  risk_overview,
  key_subtopics,
  political_rhetoric,
  political_rhetoric_rating,
  legislation,
  legislation_rating,
  litigation,
  litigation_rating,
  major_moments,
  major_moments_rating,
  engagement,
  backlash,
  reputational_and_operational_impact,
  reputational_and_operational_impact_rating,
  polarization,
  major_polls,
  polarization_rating,
  volume_drivers,
  predictions_for_q2,
  predictions_for_next_quarter,
  what_you_re_watching,
  end_of_quarter_flags

FROM {{ ref('int_issue_inputs')}}