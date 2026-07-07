**Current Status:**
This dbt data model contains pipelines that support all existing SRI product lines, though completeness varies

**Organization**
*In Models Directory:* All models are grouped by pipeline/product that they serve
 - **Staging:** Models that pull straight from source storage (e.g., Google Cloud Storage, raw data tables in Big Query) where a collection process (e.g., a scraper) deposits data. These models perform basic normalization and cleaning
 - **Intermediate:** Models that perform major cleaning and normalization operations. All analyses are performed by these models.
 - **Marts:** Models that materialize tables from which to serve processed data to the team. These models perform, at most, type casting, and their main purpose is to be queried by internal tools/analysts

https://docs.google.com/document/d/1cdU99drA-1e67kuVmWRnPRiuv9ytPXSmJcPWaPiuxos/edit?tab=t.0
