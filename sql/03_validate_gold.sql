EXEC dbo.sp_load_gold;
SELECT 'DimDate' AS tbl, COUNT(*) AS cnt FROM dbo.DimDate UNION ALL
SELECT 'DimZone', COUNT(*) FROM dbo.DimZone UNION ALL
SELECT 'DimFX', COUNT(*) FROM dbo.DimFX UNION ALL
SELECT 'DimGDP', COUNT(*) FROM dbo.DimGDP UNION ALL
SELECT 'FactTaxiDaily', COUNT(*) FROM dbo.FactTaxiDaily UNION ALL
SELECT 'FactAirQualityDaily', COUNT(*) FROM dbo.FactAirQualityDaily;