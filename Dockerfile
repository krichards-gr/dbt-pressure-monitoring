FROM python:3.11-slim

RUN pip install --no-cache-dir dbt-bigquery==1.9.* flask gunicorn

WORKDIR /app
COPY earnings_call_transforms/ ./earnings_call_transforms/
COPY profiles.yml /root/.dbt/profiles.yml

RUN dbt deps --project-dir /app/earnings_call_transforms --profiles-dir /root/.dbt

EXPOSE 8080

CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--timeout", "600", "main:app"]
