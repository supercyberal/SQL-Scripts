/***********************************************************************************************************************************************
Description:	Get index fragmentation info per DB.

Notes:			ACOSTA - 2014-03-28
				Created.

				ACOSTA - 2014-05-08
				Added argument @cTableName to search index fragmentation for an specific object.
***********************************************************************************************************************************************/

USE <DB_NAME>
GO

DECLARE
	@fMinFragPercent FLOAT
	, @fMaxFragPercent FLOAT
	, @cMode VARCHAR(16)
	, @cTableName SYSNAME

-- Determine the min and max fragmentation percentage to search.
SET @fMinFragPercent = 10;
SET @fMaxFragPercent = 40;
SET @cTableName = NULL;

-- Here are the other options: DEFAULT, NULL, LIMITED, SAMPLED, or DETAILED
-- Source: http://technet.microsoft.com/en-us/library/ms188917.aspx
SET @cMode = 'DETAILED'


IF @cTableName IS NULL
	SELECT  OBJECT_NAME(a.object_id) AS [Table Name]
			, b.name AS [Index Name]
			, a.index_type_desc AS [Index Type]
			, a.partition_number AS [Partition Number]
			, ROUND(a.avg_fragmentation_in_percent,2) AS [Fragmentation (%)]
			, a.fragment_count AS [Fragment Count]
			, a.avg_page_space_used_in_percent AS [Current Density]
			, ROUND(a.[avg_fragment_size_in_pages],2) AS [Fragmentation Size]
			, a.[page_count] AS [Page Count]
			, (
				CASE WHEN [a].[avg_fragmentation_in_percent] BETWEEN @fMinFragPercent AND @fMaxFragPercent THEN
					'REORG. INDEX - Fragmentation of ' + CAST(ROUND(a.avg_fragmentation_in_percent,2) AS VARCHAR) + '% is between Min: ' + CAST(@fMinFragPercent AS VARCHAR) + '% and Max: ' + CAST(@fMaxFragPercent AS VARCHAR) + '%'
				WHEN [a].[avg_fragmentation_in_percent] >= @fMaxFragPercent THEN
					'REBUILD INDEX - Fragmentation of ' + CAST(ROUND(a.avg_fragmentation_in_percent,2) AS VARCHAR) + '% is greater or equal to the Max fragmentation: ' + CAST(@fMaxFragPercent AS VARCHAR) + '%'
				END 
			) AS [Index Recommendation]
	FROM    sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, @cMode) a
			INNER JOIN sys.indexes b 
				ON a.object_id = b.object_id
				AND a.index_id = b.index_id	
	WHERE a.[avg_fragmentation_in_percent] BETWEEN @fMinFragPercent AND @fMaxFragPercent
	ORDER BY [Fragmentation (%)] DESC
ELSE
	SELECT  OBJECT_NAME(a.object_id) AS [Table Name]
			, b.name AS [Index Name]
			, a.index_type_desc AS [Index Type]
			, a.partition_number AS [Partition Number]
			, ROUND(a.avg_fragmentation_in_percent,2) AS [Fragmentation (%)]
			, a.fragment_count AS [Fragment Count]
			, a.avg_page_space_used_in_percent AS [Current Density]
			, ROUND(a.[avg_fragment_size_in_pages],2) AS [Fragmentation Size]
			, a.[page_count] AS [Page Count]
			, (
				CASE WHEN [a].[avg_fragmentation_in_percent] BETWEEN @fMinFragPercent AND @fMaxFragPercent THEN
					'REORG. INDEX - Fragmentation of ' + CAST(ROUND(a.avg_fragmentation_in_percent,2) AS VARCHAR) + '% is between Min: ' + CAST(@fMinFragPercent AS VARCHAR) + '% and Max: ' + CAST(@fMaxFragPercent AS VARCHAR) + '%'
				WHEN [a].[avg_fragmentation_in_percent] >= @fMaxFragPercent THEN
					'REBUILD INDEX - Fragmentation of ' + CAST(ROUND(a.avg_fragmentation_in_percent,2) AS VARCHAR) + '% is greater or equal to the Max fragmentation: ' + CAST(@fMaxFragPercent AS VARCHAR) + '%'
				END 
			) AS [Index Recommendation]
	FROM    sys.dm_db_index_physical_stats(DB_ID(), OBJECT_ID(@cTableName), NULL, NULL, @cMode) a
			INNER JOIN sys.indexes b 
				ON a.object_id = b.object_id
				AND a.index_id = b.index_id
	ORDER BY [Fragmentation (%)] DESC	