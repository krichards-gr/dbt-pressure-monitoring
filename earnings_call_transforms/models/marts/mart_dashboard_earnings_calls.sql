SELECT 
    paragraph_id,
    symbol,
    corporation,
    sector,
    transcript_id,
    report_date,
    fiscal_year,
    fiscal_quarter,
    paragraph_number,
    speaker,
    speaker_type,
    segment_type,
    content
FROM {{ ref('int_dashboard_earnings_calls') }}