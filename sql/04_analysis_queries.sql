SELECT TOP 10
    d.[date],
    SUM(t.trip_count)        AS trips,
    MAX(a.pm25_city_avg)     AS pm25_avg,
    SUM(t.total_amount_usd)  AS revenue_usd,
    SUM(t.total_amount_eur)  AS revenue_eur
FROM dbo.FactTaxiDaily t
JOIN dbo.DimDate d ON d.date_key = t.date_key
LEFT JOIN (
    SELECT date_key, AVG(value_avg) AS pm25_city_avg
    FROM dbo.FactAirQualityDaily
    WHERE parameter = 'pm25' AND zone_id <> -1
    GROUP BY date_key
) a ON a.date_key = t.date_key
GROUP BY d.[date]
ORDER BY d.[date];