/*
Description:	Get table info and space per DB.
Date:			2013-06-04
Author:			Alvaro Costa
*/

USE <DBName>
GO

CREATE TABLE #temp (
	table_name sysname ,
	row_count INT,
	reserved_size VARCHAR(50),
	data_size VARCHAR(50),
	index_size VARCHAR(50),
	unused_size VARCHAR(50)
)

SET NOCOUNT ON

INSERT #temp
EXEC sp_msforeachtable 'sp_spaceused ''?'''

SELECT * FROM (
	SELECT 
		a.table_name
		, a.row_count
		, COUNT(*) AS col_count
		, a.data_size
		, a.index_size
		, a.unused_size
		, CAST((CAST(LTRIM(RTRIM(REPLACE(a.data_size,'KB',''))) AS DECIMAL(10,2)) / 1024.) AS DECIMAL(10,2)) AS Data_Size_MB
		, CAST((CAST(LTRIM(RTRIM(REPLACE(a.index_size,'KB',''))) AS DECIMAL(10,2)) / 1024.) AS DECIMAL(10,2)) AS Index_Size_MB
		, CAST((CAST(LTRIM(RTRIM(REPLACE(a.unused_size,'KB',''))) AS DECIMAL(10,2)) / 1024.) AS DECIMAL(10,2)) AS Unused_Size_MB
	FROM #temp a
	INNER JOIN information_schema.columns b
		ON a.table_name collate database_default = b.table_name collate database_default
	GROUP BY
		a.table_name
		, a.row_count
		, a.data_size
		, a.index_size
		, a.unused_size
) tbl
ORDER BY CAST(REPLACE(tbl.data_size, ' KB', '') AS integer) DESC

COMPUTE	
	SUM(Data_Size_MB)
	, SUM(Index_Size_MB)

DROP TABLE #temp