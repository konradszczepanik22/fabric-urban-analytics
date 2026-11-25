# Extending the platform — adding a new data source

The platform is **metadata-driven**. Every source is declared in [`config/sources.yaml`](../config/sources.yaml),
and the notebook [`nb_bronze_generic`](../notebooks/nb_bronze_generic.ipynb) ingests every source marked
`loader: generic`. It runs as part of `pl_master`, so a new source flows through the daily schedule automatically.

## Path A — source in a supported format (no code change)

Supported formats: `csv`, `json_records`, `json_columns`, `parquet`, served from a plain HTTP(S) GET.

1. **Add an entry** to `config/sources.yaml`:

   ```yaml
   - name: weather                 # unique, snake_case; used for folder and table names
     enabled: true
     loader: generic
     format: json_columns          # csv | json_records | json_columns | parquet
     record_path: daily            # JSON path to the records (json_* formats only)
     url: https://archive-api.open-meteo.com/v1/archive?...&start_date={start_date}&end_date={end_date}
     target_table: bronze_weather  # optional, default bronze_<name>
     write_mode: overwrite         # overwrite | append
     owner: data-engineering
   ```

   Optional keys: `headers` (dict of HTTP headers), `separator` (CSV), `all_strings: true` (load every column as
   string when the source has mixed types).

2. **Upload the file** to the lakehouse: `lh_bronze` → `Files` → `config` → Upload → `sources.yaml` (overwrite).
3. **Commit** the change to Git (`config/sources.yaml`).
4. **Run** `nb_bronze_generic` once, or wait for the next `pl_master` run. Result:
   - raw response in `lh_bronze/Files/raw/<name>/<name>_<timestamp>.<ext>`,
   - Delta table `lh_bronze.dbo.<target_table>` with lineage columns `_source`, `_source_url`, `_ingested_at`.

Weather data (Open-Meteo, daily temperature, precipitation and wind for New York) is already registered this
way as the reference example.

## Path B — source that needs custom logic

API keys, pagination, rate limits, binary or spatial files need a dedicated loader, as for OpenAQ
(`nb_bronze_openaq`) or the taxi files (`pl_ingest_taxi`).

1. Create a notebook `nb_bronze_<name>` (or a pipeline / Dataflow) that writes to `lh_bronze`.
2. Register it in `sources.yaml` with `loader: <item name>` so the registry stays complete.
3. Add an activity for it to `pl_master` in the ingestion stage, next to the other ingestion steps.
4. Keep secrets out of Git (see [governance](governance.md#secrets)).

## Taking the new source to Silver and Gold

1. **Silver:** add a cleaning step (a new notebook, or a function in `nb_silver_reference`) that writes
   `lh_silver.dbo.silver_<name>`: typed columns, deduplicated, with a `date` column at daily grain.
2. **Gold:** add the table to `sql/01_create_tables.sql` (for example `FactWeatherDaily(date_key, ...)`) and the load
   to `sql/02_sp_load_gold.sql`. Keys follow the existing convention: `date_key = yyyymmdd`, `zone_id` for spatial data.
3. **Semantic model:** add the table, a relationship `Fact → DimDate[date_key]`, and measures (in `docs/measures.dax`).
4. **Report and docs:** add visuals, then update [data_dictionary.md](data_dictionary.md) and [lineage.md](lineage.md).

Because every fact table shares the `DimDate` / `DimZone` dimensions, a new source can be compared
with taxi and air-quality data straight away (for example trips vs precipitation).
