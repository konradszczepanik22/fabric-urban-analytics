# Data lineage

The diagrams render on GitHub (Mermaid). The same lineage can be inspected live in Fabric:
workspace `ws-urban-analytics` → **Lineage view**.

## End-to-end lineage

```mermaid
flowchart LR
    subgraph SRC[External sources]
        TLC[NYC TLC<br/>trip Parquet + zones]
        OAQ[OpenAQ API v3]
        WB[World Bank API]
        ECB[ECB Data API]
        OM[Open-Meteo API]
    end

    subgraph ING[Ingestion]
        PIT[pl_ingest_taxi<br/>pipeline]
        NOA[nb_bronze_openaq<br/>notebook]
        DFM[df_ingest_macro<br/>Dataflow Gen2]
        NGE[nb_bronze_generic<br/>notebook + sources.yaml]
    end

    subgraph BR[Bronze · lh_bronze]
        BT[(Files/raw/taxi)]
        BZ[(Files/raw/taxi_zones)]
        BO[(bronze_openaq<br/>bronze_openaq_sensors)]
        BG[(bronze_gdp)]
        BF[(bronze_fx)]
        BW[(bronze_weather)]
    end

    subgraph SV[Silver · lh_silver]
        ST[(silver_taxi_trips)]
        SZ[(silver_zones)]
        SA[(silver_air_quality)]
        SF[(silver_fx_daily)]
        SG[(silver_gdp)]
    end

    subgraph GD[Gold · wh_gold]
        FT[FactTaxiDaily]
        FA[FactAirQualityDaily]
        DD[DimDate]
        DZ[DimZone]
        DX[DimFX]
        DG[DimGDP]
    end

    SM[sm_urban_analytics<br/>semantic model] --> RP[rpt_urban_analytics<br/>Power BI report]

    TLC --> PIT --> BT & BZ
    OAQ --> NOA --> BO
    WB --> DFM --> BG
    ECB --> DFM --> BF
    OM --> NGE --> BW

    BT -->|nb_silver_taxi| ST
    BZ -->|nb_silver_reference| SZ
    BO -->|nb_silver_reference<br/>spatial join to zones| SA
    SZ -.-> SA
    BF -->|nb_silver_reference<br/>forward fill| SF
    BG -->|nb_silver_reference| SG

    ST -->|sp_load_gold| FT
    SF -->|sp_load_gold| FT
    SA -->|sp_load_gold| FA
    SF -->|sp_load_gold| DD
    SF -->|sp_load_gold| DX
    SZ -->|sp_load_gold| DZ
    SG -->|sp_load_gold| DG

    FT & FA & DD & DZ & DX & DG --> SM
```

`bronze_weather` stops at Bronze. It is the reference example of a config-driven source
(see [extending.md](extending.md)).

## Orchestration — `pl_master` (daily, 06:00 Europe/Warsaw)

```mermaid
flowchart LR
    A[Ingest taxi<br/>Invoke pl_ingest_taxi] --> E
    B[Ingest GDP and FX<br/>df_ingest_macro] --> E
    C[Ingest OpenAQ<br/>nb_bronze_openaq] --> E
    D[Ingest generic sources<br/>nb_bronze_generic] --> E
    E[Silver taxi<br/>nb_silver_taxi] --> F[Silver reference<br/>nb_silver_reference]
    F --> G[Load gold<br/>dbo.sp_load_gold]
    G --> H[Direct Lake semantic model<br/>sees new data automatically]
```

All ingestion activities run in parallel. Each later stage starts only when the previous one succeeds,
so a failed source never produces a partially refreshed Gold layer. A full run takes about 16 minutes.

## Column-level lineage of key Gold fields

| Gold column | Derived from | Transformation |
|---|---|---|
| `FactTaxiDaily.trip_count` | `silver_taxi_trips` | `COUNT(*)` per pickup date × `PULocationID` |
| `FactTaxiDaily.total_amount_usd` | `silver_taxi_trips.total_amount` | `SUM` |
| `FactTaxiDaily.total_amount_eur` | `total_amount_usd`, `silver_fx_daily.usd_per_eur` | `SUM(total_amount) / MAX(usd_per_eur)` for the day |
| `FactAirQualityDaily.value_avg` | `silver_air_quality.value` | `AVG` per day × zone × parameter |
| `FactAirQualityDaily.zone_id` | station coordinates, `silver_zones` geometry | point-in-polygon join; `-1` when outside all zones |
| `DimFX.usd_per_eur` | `bronze_fx.OBS_VALUE` | cast to decimal, forward-filled over non-fixing days |
| `DimDate.*` | calendar of `silver_fx_daily` dates | date attributes derived in SQL |
| `DimGDP.gdp_usd` | `bronze_gdp.value` | cast, nulls removed |
