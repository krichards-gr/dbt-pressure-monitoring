{% docs earnings_call_transcript_id %}
Unique identifier for each transcript. MD5 hash of...
{% enddocs %}


{% docs earnings_call_paragraph_number %}
Ordering id for transcript content. Sort by this to arrange content in order of occurrence.
{% enddocs %}


{% docs earnings_call_paragraph_id %}
Unique identifier for pararaph, made by combining (MD5) transcript_id and paragraph_number.
{% enddocs %}


{% docs earnings_call_speaker %}
Person responsible for statement in the row content column. Provided by defeatbeta API.
{% enddocs %}

{% docs earnings_call_content %}
Spoken content, broken up into segments by either speaker transition (primarily) or length
{% enddocs %}


{% docs earnings_call_speaker_role %}
Type of speaker: Executive, Operator, Analyst.
{% enddocs %}


{% docs earnings_call_segment_type %}
Type of content in segment: Admin, Question, Answer.
{% enddocs %}


{% docs symbol_or_ticker %}
Stock ticker associated with given corporation. NYSE or Nasdaq preferred.
{% enddocs %}


{% docs fiscal_year %}
Company fiscal year in which the content (call transcript, press release, etc.) was generated. Company fiscal years often to not align with 'base' fiscal year.
{% enddocs %}


{% docs fiscal_quarter %}
Company fiscal quarter in which the content (call transcript, press release, etc.) was generated. Company fiscal quarters often to not align with 'base' fiscal quarters.
{% enddocs %}


{% docs assignments %}
Associate or analyst responsible for reviewing benchmarking records associated with this company.
{% enddocs %}


{% docs sector %}
Company sector. Generally follows GICS framework, but refined upward for client-facing content (e.g., "Consumer Discretionary" and "Consumer Staples" combined into "Consumer Goods")
{% enddocs %}


{% docs corporation %}
Entity title, as named across SRI products
{% enddocs %}


{% docs profile_linkedin_url %}
Base LinkedIn company profile url. Used as input for Bright Data LinkedIn scraper.
{% enddocs %}


{% docs instagram_url %}
Base Instagram company profile url. Used as input for Bright Data Instagram scraper.
{% enddocs %}


{% docs x_url %}
Base X/Twitter company profile url. Used as input for Bright Data X/Twitter scraper.
{% enddocs %}


{% docs newsroom_url %}
Base newsroom company profile url. Used as input for SRI in-house pressroom scraper.
{% enddocs %}


{% docs cik %}
Unique SEC corporate identification code. Used to link corporations to SEC filings like 10ks and proxy statements.
{% enddocs %}


{% docs peer_of %}
Companies for which a given corporation is listed as a peer
{% enddocs %}


{% docs product %}
SRI product for which this company is tracked. Can be multiple. Semicolon delimited.
{% enddocs %}


{% docs company_rank %}
Fortune rank for the given corporation, based on 2025 list. Only validated through F500 as of 6.2.2026.
{% enddocs %}


{% docs f100 %}
Company is part of the F100, true/false
{% enddocs %}


{% docs f500 %}
Company is part of the F500, true/false
{% enddocs %}


{% docs parent_company %}
Company of which the given corporation is a subsidiary.
{% enddocs %}


{% docs story_id %}
Unique identifier for each story. Primary key.
{% enddocs %}


{% docs category %}
Issue area/category. Subject to changes in definition/scope. Corrected by seed table 'category_map' across pipelines.
{% enddocs %}


{% docs first_seen_date %}
Date story first appeared in monitoring dataset.
{% enddocs %}


{% docs story_count %}
Count of unique stories on the given date, identified by story_id.
{% enddocs %}


{% docs engagement_count %}
Count of unique engagements on the given date, identified by retool_primary_key.
{% enddocs %}