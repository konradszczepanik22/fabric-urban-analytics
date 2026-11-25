# Data governance

## 1. Ownership and roles

| Role | Who | Responsibilities |
|---|---|---|
| Data owner | Project owner (data engineering) | Approves new sources, retention and access |
| Data engineer | Workspace **Admin / Member** | Pipelines, notebooks, warehouse, semantic model |
| Report consumer | Workspace **Viewer**, or report sharing | Read-only access to `rpt_urban_analytics` |

- One workspace (`ws-urban-analytics`) holds all items. Access is granted to groups through workspace roles,
  not to individuals per item.
- Consumers get the report (or app), never write access to lakehouses or the warehouse.
- In production, Dev / Test / Prod workspaces would be promoted with Fabric deployment pipelines.

## 2. Naming conventions

| Item | Pattern | Example |
|---|---|---|
| Workspace | `ws-<domain>` | `ws-urban-analytics` |
| Lakehouse | `lh_<layer>` | `lh_bronze`, `lh_silver` |
| Warehouse | `wh_<layer>` | `wh_gold` |
| Pipeline | `pl_<action>` | `pl_ingest_taxi`, `pl_master` |
| Dataflow | `df_<action>` | `df_ingest_macro` |
| Notebook | `nb_<layer>_<subject>` | `nb_silver_taxi` |
| Tables | `bronze_*`, `silver_*`, `Dim*`, `Fact*` | `silver_fx_daily`, `FactTaxiDaily` |
| Semantic model / report | `sm_*` / `rpt_*` | `sm_urban_analytics` |

Columns use `snake_case`. Keys follow fixed formats: `date_key` = `yyyymmdd`, `zone_id` = TLC LocationID.

## 3. Data classification and privacy

| Source | Classification | Personal data | License / terms |
|---|---|---|---|
| NYC TLC trip records | Public | None (no names or exact addresses; zone level only) | NYC Open Data terms of use |
| OpenAQ | Public | None | Data licenses of the original providers (attribution required) |
| World Bank WDI | Public | None | CC BY 4.0 |
| ECB exchange rates | Public | None | ECB reuse policy (attribution required) |
| Open-Meteo | Public | None | CC BY 4.0 |

All data is public and aggregated, so no sensitivity label is required. Gold is aggregated further
(day × zone), so trip-level records never leave Silver.

## 4. Secrets

- The OpenAQ API key is **not stored in Git**. The key value is cleared in the exported notebook; it lives only
  in the Fabric copy of `nb_bronze_openaq`.
- Production target: store the key in **Azure Key Vault** and read it at run time with
  `notebookutils.credentials.getSecret(...)`.
- `.gitignore` excludes local credential and environment files.
- Any key that is accidentally committed or shared must be rotated immediately.

## 5. Source control

- All code is versioned in GitHub (`fabric-urban-analytics`): notebooks (`.ipynb`), pipeline JSON definitions,
  the Dataflow M script, SQL scripts, DAX measures, configuration and documentation.
- Fabric's built-in Git integration was not available: the tenant disables GitHub sync, and Azure DevOps needs an
  Azure subscription. Items are therefore exported manually after every change and committed with a descriptive
  message. With Git integration enabled, the same repository structure can be connected directly.

## 6. Data quality

| Layer | Check |
|---|---|
| Bronze | Raw files kept unchanged; generic loader adds `_source`, `_source_url`, `_ingested_at` |
| Silver taxi | Invalid trips removed (3.9 % of Q1 2024 records); schema types enforced |
| Silver air quality | Only requested parameters (PM2.5, NO2) and the selected period; NO2 unit normalised to ppb |
| Silver FX | Calendar completed with forward fill; `is_ecb_fixing_day` marks filled values |
| Gold | Every fact key resolves to a dimension (technical member `zone_id = -1` instead of NULL); row counts checked after each load |

Failures stop `pl_master` before the next layer (activities are chained "on success"), and the run history is
available in the **Monitor** hub.

## 7. Refresh and retention

- **Schedule:** `pl_master` runs daily at 06:00 Europe/Warsaw. The semantic model uses Direct Lake, so it shows new
  Gold data without a separate import refresh.
- **Bronze:** raw files are kept for full re-processing (the source of truth for replay).
- **Silver / Gold:** rebuilt from Bronze by every run (overwrite / truncate-and-load), so they can always be
  regenerated.
- **Delta maintenance:** run `OPTIMIZE` and `VACUUM` (default 7-day retention) on large Silver tables periodically.

## 8. Lineage and discoverability

- The Fabric **Lineage view** shows item-level lineage from sources to the report; [lineage.md](lineage.md)
  documents table and column lineage.
- Table and column definitions: [data_dictionary.md](data_dictionary.md).
- New sources must be registered in `config/sources.yaml` and documented before they reach Gold
  (see [extending.md](extending.md)).
