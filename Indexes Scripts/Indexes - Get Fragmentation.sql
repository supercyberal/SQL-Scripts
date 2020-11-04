/*
Description:	Indexes fragmentation results.
Date:			2013-06-26
Author:			Alvaro Costa
*/

SELECT
	OBJECT_NAME(ind.OBJECT_ID) AS TableName
	, p.TableRows
	, dm_ius.UserSeek
	, dm_ius.UserScans
	, dm_ius.UserLookups
	, dm_ius.UserUpdates
	, (CASE WHEN indexstats.index_type_desc = 'HEAP' THEN 'HEAP_TABLE' ELSE ind.name END) AS IndexName
	, indexstats.index_type_desc AS IndexType
	, indexstats.avg_fragmentation_in_percent
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, NULL) indexstats
INNER JOIN sys.indexes ind
	ON ind.object_id = indexstats.object_id
	AND ind.index_id = indexstats.index_id
LEFT JOIN (
	SELECT
		object_id
		, index_id
		, MAX(user_seeks) AS UserSeek
		, MAX(user_scans) AS UserScans
		, MAX(user_lookups) AS UserLookups
		, MAX(user_updates) AS UserUpdates
	FROM sys.dm_db_index_usage_stats
	GROUP BY object_id, index_id
) dm_ius
	ON dm_ius.index_id = ind.index_id
	AND dm_ius.object_id = ind.object_id
INNER JOIN ( 
	SELECT 
		SUM(p.rows) TableRows 
		, p.index_id 
		, p.object_id
	FROM sys.partitions p
	GROUP BY p.index_id, p.object_id
) p 
	ON p.index_id = ind.index_id
	AND p.object_id = ind.object_id
WHERE indexstats.avg_fragmentation_in_percent > 40--You can specify the percent as you want
ORDER BY 
	OBJECT_NAME(ind.OBJECT_ID)
	, indexstats.avg_fragmentation_in_percent DESC;

