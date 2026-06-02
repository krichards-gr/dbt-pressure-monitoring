{% docs earnings_call_transcript_id %}
Unique identifier for each transcript. MD5 hash of...
{% enddocs %}


{% docs earnings_call_paragraph_number %}
Ordering id for transcript content. Sort by this to arrange content in order of occurrence.
{% enddocs %}


{% docs earnings_call_speaker %}
Person responsible for statement in the row content column. Provided by defeatbeta API.
{% enddocs %}

{% docs earnings_call_content %}
Spoken content, broken up into segments by either speaker transition (primarily) or length
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