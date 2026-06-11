-- TODO: What other cleanup and enforcement do we need to do here?

{{ config(schema='social_media_activity_archive') }}

SELECT
  TRIM(_Corporation) as corporation,
  TRIM(UPPER(Industry)) as sector,
  Date_of_engagement as engagement_date, -- Enforce date here
  TRIM(Societal_issues) as category, -- Enforce data validation here (case_when for corrections?)
  Engagement_type as engagement_type, -- Enforce data validation here (case_when for corrections?)
  Engagement_sub_category as engagement_subtype, -- Enforce data validation here (case_when for corrections?)
  TRIM(Details) as summary,
  TRIM(Link) as url,
  Submitter_s_name as submitted_by, -- Do we need to enforce some kind of formatting here?
  Timestamp as submitted_on,
  TRIM(Additional_notes__optional_) as notes,
  Done_ as completed

  FROM {{ source('social_media_activity_archive', 'external_analyst_ced_subs') }}