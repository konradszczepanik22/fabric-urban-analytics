DROP TABLE IF EXISTS dbo.DimDate;
CREATE TABLE dbo.DimDate (
    date_key      INT          NOT NULL,
    [date]        DATE         NOT NULL,
    [year]        SMALLINT     NOT NULL,
    [quarter]     SMALLINT     NOT NULL,
    [month]       SMALLINT     NOT NULL,
    month_name    VARCHAR(12)  NOT NULL,
    [day]         SMALLINT     NOT NULL,
    day_of_week   SMALLINT     NOT NULL,
    day_name      VARCHAR(12)  NOT NULL,
    is_weekend    BIT          NOT NULL
);

DROP TABLE IF EXISTS dbo.DimZone;
CREATE TABLE dbo.DimZone (
    zone_id       INT          NOT NULL,
    borough       VARCHAR(50)  NULL,
    zone_name     VARCHAR(100) NULL,
    service_zone  VARCHAR(50)  NULL,
    centroid_lat  FLOAT        NULL,
    centroid_lon  FLOAT        NULL
);

DROP TABLE IF EXISTS dbo.DimFX;
CREATE TABLE dbo.DimFX (
    date_key          INT            NOT NULL,
    usd_per_eur       DECIMAL(12,6)  NOT NULL,
    eur_per_usd       DECIMAL(12,6)  NOT NULL,
    is_ecb_fixing_day BIT            NOT NULL
);

DROP TABLE IF EXISTS dbo.DimGDP;
CREATE TABLE dbo.DimGDP (
    country_iso3  VARCHAR(3)     NOT NULL,
    [year]        SMALLINT       NOT NULL,
    gdp_usd       DECIMAL(20,2)  NOT NULL
);

DROP TABLE IF EXISTS dbo.FactTaxiDaily;
CREATE TABLE dbo.FactTaxiDaily (
    date_key           INT            NOT NULL,
    pu_zone_id         INT            NOT NULL,
    trip_count         INT            NOT NULL,
    passenger_count    BIGINT         NULL,
    total_distance_mi  FLOAT          NULL,
    total_fare_usd     DECIMAL(18,2)  NULL,
    total_tip_usd      DECIMAL(18,2)  NULL,
    total_amount_usd   DECIMAL(18,2)  NULL,
    total_amount_eur   DECIMAL(18,2)  NULL,
    avg_amount_usd     DECIMAL(10,2)  NULL,
    avg_distance_mi    FLOAT          NULL,
    avg_duration_min   FLOAT          NULL
);

DROP TABLE IF EXISTS dbo.FactAirQualityDaily;
CREATE TABLE dbo.FactAirQualityDaily (
    date_key       INT          NOT NULL,
    zone_id        INT          NOT NULL,
    parameter      VARCHAR(10)  NOT NULL,
    unit           VARCHAR(20)  NOT NULL,
    value_avg      FLOAT        NULL,
    value_max      FLOAT        NULL,
    station_count  INT          NOT NULL
);