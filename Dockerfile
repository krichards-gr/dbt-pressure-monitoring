FROM python:3.11-slim

RUN pip install --no-cache-dir dbt-bigquery==1.9.*

WORKDIR /app
COPY earnings_call_transforms/ ./earnings_call_transforms/
COPY profiles.yml /root/.dbt/profiles.yml

RUN dbt deps --project-dir /app/earnings_call_transforms --profiles-dir /root/.dbt

ENTRYPOINT ["sh", "-c", "dbt \"$@\" --project-dir /app/earnings_call_transforms --profiles-dir /root/.dbt", "--"]
CMD ["build"]