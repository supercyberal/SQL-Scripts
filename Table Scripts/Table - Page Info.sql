USE <DBName>

----------------------------------------------------------------------------------------------------------------------------------------------
-- 1. List number of pages for each Index and/or Table.

SELECT OBJECT_NAME(p.object_id) AS object_name
       , i.name AS index_name
       , ps.in_row_used_page_count
FROM sys.dm_db_partition_stats ps
JOIN sys.partitions p
       ON ps.partition_id = p.partition_id
JOIN sys.indexes i
       ON p.index_id = i.index_id
       AND p.object_id = i.object_id

----------------------------------------------------------------------------------------------------------------------------------------------
-- 2. Find page info.

DECLARE 
	@sTableName VARCHAR(64) = '<Table_Name>'
	, @DBName SYSNAME = DB_NAME()

SELECT * FROM sys.dm_db_index_physical_stats(DB_ID(@DBName),object_id(@sTableName),NULL,NULL,NULL) ddips

SELECT * FROM sys.dm_db_partition_stats ddps
WHERE ddps.object_id = object_id(@sTableName)

SELECT * FROM sys.indexes i 
WHERE i.object_id = object_id(@sTableName)

DBCC IND(@DBName,@sTableName,-1);