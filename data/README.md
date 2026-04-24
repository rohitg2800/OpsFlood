## Data Lake Layout

This project now separates operational datasets into pipeline stages:

- `raw/`
  Append-only ingestion captures for weather and water-level snapshots.
- `cleaned/`
  Normalized tabular datasets ready for analyst use and downstream QA.
- `features/`
  Feature-ready joins that combine meteorological and hydrological signals.
- `manifest/`
  Run summaries and ingestion status metadata.

The backend scheduler materializes these layers from the live weather and water-level ingestion pipeline.
