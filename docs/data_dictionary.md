# Data dictionary

Layers: **Bronze** (`lh_bronze`, raw), **Silver** (`lh_silver`, cleaned and conformed),
**Gold** (`wh_gold`, star schema served to Power BI through the semantic model `sm_urban_analytics`).
Row counts are from the Q1 2024 load (January–March 2024).

## Bronze — `lh_bronze`

| Object | Type | Source | Loader | Content |
|---|---|---|---|---|
| `Files/raw/taxi/yellow_tripdata_YYYY-MM.parquet` | file | NYC TLC | `pl_ingest_taxi` | Monthly yellow-taxi trip records, unchanged (9,554,778 rows for Q1 2024) |
| `Files/raw/taxi_zones/taxi_zone_lookup.csv`, `taxi_zones.zip` | file | NYC TLC | `pl_ingest_taxi` | Zone lookup and zone shapefile |
| `bronze_openaq` | Delta | OpenAQ v3 `/sensors/{id}/days` | `nb_bronze_openaq` | Daily aggregates per sensor (PM2.5, NO2) |
| `bronze_openaq_sensors` | Delta | OpenAQ v3 `/locations` | `nb_bronze_openaq` | Stations and sensors in the NYC bounding box |
| `Files/raw/openaq/` | file | OpenAQ | `nb_bronze_openaq` | Raw JSON responses |
| `bronze_gdp` | Delta | World Bank API | `df_ingest_macro` | GDP (current USD) by country and year |
| `bronze_fx` | Delta | ECB Data API | `df_ingest_macro` | Daily USD per EUR reference rate since 2015 |
| `bronze_weather` | Delta | Open-Meteo archive | `nb_bronze_generic` | Daily NYC weather (example of a config-driven source) |

Tables loaded by `nb_bronze_generic` carry three lineage columns: `_source`, `_source_url` and `_ingested_at`.

## Silver — `lh_silver`

| Table | Rows | Grain | Description |
|---|---|---|---|
| `silver_taxi_trips` | 9,179,406 | trip | Cleaned trips, typed, partitioned by `year`/`month`. Invalid records removed (3.9 %); rules in `nb_silver_taxi`. |
| `silver_zones` | 265 | zone | Taxi zones with borough, service zone and centroid coordinates |
| `silver_air_quality` | 2,002 | sensor × day | Daily PM2.5 (µg/m³) and NO2 (converted to ppb), with the taxi zone from a spatial join. 15 of 24 stations lie inside taxi zones. |
| `silver_fx_daily` | 4,345 | day | USD per EUR for every calendar day; weekends and holidays forward-filled |
| `silver_gdp` | 66 | country × year | GDP in current USD |

## Gold — `wh_gold` (star schema)

Keys: `date_key` is an integer in `yyyymmdd` format; `zone_id` is the TLC LocationID.

### DimDate (4,345 rows)

| Column | Type | Description |
|---|---|---|
| `date_key` | int | Primary key, `yyyymmdd` |
| `date` | date | Calendar date |
| `year` | int | Year |
| `quarter` | int | Quarter 1–4 |
| `month` | int | Month 1–12 (sort key for `month_name`) |
| `month_name` | text | January … December |
| `day` | int | Day of month |
| `day_of_week` | int | Day of week (sort key for `day_name`) |
| `day_name` | text | Monday … Sunday |
| `is_weekend` | bool | True for Saturday and Sunday |

### DimZone (266 rows)

| Column | Type | Description |
|---|---|---|
| `zone_id` | int | Primary key (TLC LocationID). **`-1` = "Outside taxi zones"** technical member for stations outside all zones |
| `borough` | text | Manhattan, Brooklyn, Queens, Bronx, Staten Island, EWR |
| `zone_name` | text | Zone name |
| `service_zone` | text | Yellow Zone, Boro Zone, Airports, EWR |
| `centroid_lat` | decimal | Zone centroid latitude |
| `centroid_lon` | decimal | Zone centroid longitude |

### DimFX

| Column | Type | Description |
|---|---|---|
| `date_key` | int | Primary key, 1:1 with `DimDate` |
| `usd_per_eur` | decimal | USD for 1 EUR (ECB reference rate) |
| `eur_per_usd` | decimal | `1 / usd_per_eur` |
| `is_ecb_fixing_day` | bool | False when the value was forward-filled (weekend or holiday) |

### DimGDP

| Column | Type | Description |
|---|---|---|
| `country_iso3` | text | Country code (ISO 3166-1 alpha-3) |
| `year` | int | Year; joined to `DimDate[year]` in DAX (`TREATAS`) |
| `gdp_usd` | decimal | GDP, current USD |

### FactTaxiDaily (20,278 rows) — grain: day × pickup zone

| Column | Type | Description |
|---|---|---|
| `date_key` | int | FK → `DimDate` (pickup date) |
| `pu_zone_id` | int | FK → `DimZone` (pickup zone) |
| `trip_count` | int | Number of trips |
| `passenger_count` | int | Sum of passengers |
| `total_distance_mi` | decimal | Sum of trip distance, miles |
| `total_fare_usd` | decimal | Sum of metered fare |
| `total_tip_usd` | decimal | Sum of tips |
| `total_amount_usd` | decimal | Sum of total amount charged |
| `total_amount_eur` | decimal | `total_amount_usd / usd_per_eur` for that day |
| `avg_amount_usd` | decimal | Average total amount per trip |
| `avg_distance_mi` | decimal | Average distance per trip |
| `avg_duration_min` | decimal | Average trip duration, minutes |

### FactAirQualityDaily (1,174 rows) — grain: day × zone × parameter

| Column | Type | Description |
|---|---|---|
| `date_key` | int | FK → `DimDate` |
| `zone_id` | int | FK → `DimZone` (`-1` when the station is outside taxi zones) |
| `parameter` | text | `pm25` or `no2` |
| `unit` | text | `µg/m³` (PM2.5), `ppb` (NO2) |
| `value_avg` | decimal | Average of station daily means |
| `value_max` | decimal | Maximum of station daily means |
| `station_count` | int | Number of stations contributing |

## Semantic model measures (`docs/measures.dax`)

| Measure | Definition |
|---|---|
| Trips | `SUM(trip_count)` |
| Revenue USD / Revenue EUR | `SUM(total_amount_usd)` / `SUM(total_amount_eur)` |
| Avg Fare USD / EUR | Revenue / Trips |
| Avg Distance mi | `SUM(total_distance_mi) / Trips` |
| PM25 Avg | Average `value_avg` for `pm25`, stations inside taxi zones only |
| NO2 Avg | Average `value_avg` for `no2`, all stations in the NYC bounding box (all NO2 stations lie outside taxi zones) |
| USD per EUR | Average `DimFX[usd_per_eur]` |
| GDP USD | GDP for the years in the current filter context (`TREATAS` on `DimDate[year]`) |
| Corr Trips vs PM25 | Pearson correlation of daily Trips and PM25 Avg (Q1 2024: r = 0.11) |

## Relationships

| From (many) | To (one) | Direction |
|---|---|---|
| `FactTaxiDaily[date_key]` | `DimDate[date_key]` | single |
| `FactTaxiDaily[pu_zone_id]` | `DimZone[zone_id]` | single |
| `FactAirQualityDaily[date_key]` | `DimDate[date_key]` | single |
| `FactAirQualityDaily[zone_id]` | `DimZone[zone_id]` | single |
| `DimFX[date_key]` | `DimDate[date_key]` | 1:1, both |

`DimGDP` is yearly, so it has no physical relationship; the `GDP USD` measure applies the year filter with `TREATAS`.
