CREATE OR ALTER PROCEDURE dbo.sp_load_gold
AS
BEGIN
    TRUNCATE TABLE dbo.DimDate;
    TRUNCATE TABLE dbo.DimZone;
    TRUNCATE TABLE dbo.DimFX;
    TRUNCATE TABLE dbo.DimGDP;
    TRUNCATE TABLE dbo.FactTaxiDaily;
    TRUNCATE TABLE dbo.FactAirQualityDaily;

    INSERT INTO dbo.DimDate
    SELECT
        YEAR(f.[date]) * 10000 + MONTH(f.[date]) * 100 + DAY(f.[date]),
        f.[date],
        YEAR(f.[date]),
        DATEPART(quarter, f.[date]),
        MONTH(f.[date]),
        DATENAME(month, f.[date]),
        DAY(f.[date]),
        (DATEPART(weekday, f.[date]) + @@DATEFIRST - 2) % 7 + 1,
        DATENAME(weekday, f.[date]),
        CASE WHEN DATENAME(weekday, f.[date]) IN ('Saturday', 'Sunday') THEN 1 ELSE 0 END
    FROM lh_silver.dbo.silver_fx_daily AS f;

    INSERT INTO dbo.DimZone
    SELECT location_id, borough, zone, service_zone, centroid_lat, centroid_lon
    FROM lh_silver.dbo.silver_zones;

    INSERT INTO dbo.DimZone VALUES (-1, 'Outside NYC', 'Outside taxi zones', 'N/A', NULL, NULL);

    INSERT INTO dbo.DimFX
    SELECT
        YEAR([date]) * 10000 + MONTH([date]) * 100 + DAY([date]),
        usd_per_eur, eur_per_usd, is_ecb_fixing_day
    FROM lh_silver.dbo.silver_fx_daily;

    INSERT INTO dbo.DimGDP
    SELECT country_iso3, [year], gdp_usd
    FROM lh_silver.dbo.silver_gdp;

    INSERT INTO dbo.FactTaxiDaily
    SELECT
        YEAR(t.pickup_date) * 10000 + MONTH(t.pickup_date) * 100 + DAY(t.pickup_date),
        t.pu_location_id,
        COUNT(*),
        SUM(CAST(COALESCE(t.passenger_count, 0) AS BIGINT)),
        SUM(t.trip_distance_mi),
        SUM(t.fare_amount),
        SUM(t.tip_amount),
        SUM(t.total_amount),
        SUM(t.total_amount) / MAX(fx.usd_per_eur),
        AVG(t.total_amount),
        AVG(t.trip_distance_mi),
        AVG(t.trip_duration_min)
    FROM lh_silver.dbo.silver_taxi_trips AS t
    LEFT JOIN lh_silver.dbo.silver_fx_daily AS fx
           ON fx.[date] = t.pickup_date
    GROUP BY t.pickup_date, t.pu_location_id;

    INSERT INTO dbo.FactAirQualityDaily
    SELECT
        YEAR(a.[date]) * 10000 + MONTH(a.[date]) * 100 + DAY(a.[date]),
        COALESCE(a.zone_id, -1),
        a.parameter,
        MAX(a.unit),
        AVG(a.value_avg),
        MAX(a.value_max),
        COUNT(DISTINCT a.location_id)
    FROM lh_silver.dbo.silver_air_quality AS a
    GROUP BY a.[date], COALESCE(a.zone_id, -1), a.parameter;
END;