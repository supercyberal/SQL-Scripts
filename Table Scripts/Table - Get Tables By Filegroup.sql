/* Get Details of Object on different filegroup
Finding User Created Tables*/
SELECT  [o].[name]
       ,[o].[type]
       ,[i].[name]
       ,[i].[index_id]
       ,[f].[name]
	   ,[au].*	   
FROM    [sys].[indexes] [i]
        INNER JOIN [sys].[filegroups] [f] 
			ON [i].[data_space_id] = [f].[data_space_id]
        INNER JOIN [sys].[all_objects] [o] 
			ON [i].[object_id] = [o].[object_id]
		JOIN [sys].[allocation_units] AS [au] 
			ON [au].[data_space_id] = [f].[data_space_id]
WHERE   [f].[name] = 'PRIMARY'
        AND [o].[type] = 'U'; -- User Created Tables
GO


SELECT  FILEGROUP_NAME([AU].[data_space_id]) AS FileGroupName
       ,OBJECT_NAME([Parti].[object_id]) AS TableName
       ,[ind].[name] AS ClusteredIndexName
       ,[AU].[total_pages] / 128 AS TotalTableSizeInMB
       ,[AU].[used_pages] / 128 AS UsedSizeInMB
       ,[AU].[data_pages] / 128 AS DataSizeInMB
FROM    [sys].[allocation_units] AS AU
        INNER JOIN [sys].[partitions] AS Parti 
			ON [AU].[container_id] = (
				CASE WHEN [AU].[type] IN ( 1, 3 ) THEN 
					[Parti].[hobt_id]
				ELSE 
					[Parti].[partition_id]
				END
			)
        LEFT JOIN [sys].[indexes] AS ind 
			ON [ind].[object_id] = [Parti].[object_id]
			AND [ind].[index_id] = [Parti].[index_id]
WHERE FILEGROUP_NAME([AU].[data_space_id]) = 'PRIMARY'
ORDER BY TotalTableSizeInMB DESC
GO

/* Get Details of Object on different filegroup
Finding Objects on Specific Filegroup*/
;WITH cteResults AS (
	SELECT  [o].[name] AS TableName,
			[s].[name] AS SchemaName,
			[o].[type],
			[i].[name] AS IndexName,
			[i].[index_id],
			[f].[name] AS FileGroupName
	FROM    [sys].[indexes]                AS [i]
			INNER JOIN [sys].[filegroups]  AS [f]
				ON [i].[data_space_id] = [f].[data_space_id]

			INNER JOIN [sys].[all_objects] AS [o]
				ON [i].[object_id] = [o].[object_id]

			INNER JOIN [sys].[schemas] AS [s]
				ON [o].[schema_id] = [s].[schema_id]

	WHERE   [i].[data_space_id] = [f].[data_space_id]
			AND [i].[data_space_id] = 2    -- Filegroup
)
SELECT
	CASE WHEN [c].[IndexName] IS NULL THEN
		'ALTER TABLE ' + QUOTENAME([c].[SchemaName]) + '.' + QUOTENAME([c].[TableName]) + ' REBUILD;'
	ELSE
		'ALTER INDEX ' + QUOTENAME([c].[IndexName]) + ' ON ' + QUOTENAME([c].[SchemaName]) + '.' + QUOTENAME([c].[TableName]) + ' REBUILD;'
	END
	, * 
FROM [cteResults] AS [c]
WHERE [c].[FileGroupName] = N'';
