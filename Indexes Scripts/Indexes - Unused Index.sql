-- Unused Index Script
-- Original Author: Pinal Dave (C) 2011
-- http://blog.sqlauthority.com

;WITH cteResults AS (
	SELECT --TOP 25
			[o].[name] AS [ObjectName],
			[i].[name] AS [IndexName],
			[i].[index_id] AS [IndexID],
			[dm_ius].[user_seeks] AS [UserSeek],
			[dm_ius].[user_scans] AS [UserScans],
			[dm_ius].[user_lookups] AS [UserLookups],
			[dm_ius].[user_updates] AS [UserUpdates],
			[p].[TableRows],
			[dm_ius].[last_user_seek],
			[dm_ius].[last_user_scan],
			[dm_ius].[last_user_lookup],
			[dm_ius].[last_user_update],			
			'DROP INDEX ' + QUOTENAME([i].[name]) + ' ON ' + QUOTENAME([s].[name]) + '.' + QUOTENAME(OBJECT_NAME([dm_ius].[object_id])) + ';' AS [Drop Statement],
			'ALTER INDEX ' + QUOTENAME([i].[name]) + ' ON ' + QUOTENAME([s].[name]) + '.' + QUOTENAME(OBJECT_NAME([dm_ius].[object_id])) + ' DISABLE;' AS [Disable Statement]
	FROM    [sys].[dm_db_index_usage_stats] [dm_ius]
			INNER JOIN [sys].[indexes] [i] 
				ON [i].[index_id] = [dm_ius].[index_id]
				AND [dm_ius].[object_id] = [i].[object_id]
			INNER JOIN [sys].[objects] [o] 
				ON [dm_ius].[object_id] = [o].[object_id]
			INNER JOIN [sys].[schemas] [s] 
				ON [o].[schema_id] = [s].[schema_id]
			INNER JOIN ( 
				SELECT SUM([p].[rows]) [TableRows],
					[p].[index_id],
					[p].[object_id]
				FROM   [sys].[partitions] [p]
				GROUP BY [p].[index_id], [p].[object_id]
			) [p] 
				ON [p].[index_id] = [dm_ius].[index_id]
				AND [dm_ius].[object_id] = [p].[object_id]
	WHERE   OBJECTPROPERTY([dm_ius].[object_id], 'IsUserTable') = 1
			AND [dm_ius].[database_id] = DB_ID()
			AND [i].[type_desc] = 'nonclustered'
			AND [i].[is_primary_key] = 0
			AND [i].[is_unique_constraint] = 0
)
SELECT * FROM [cteResults] AS cte
--WHERE ( [cte].[UserSeek] + [cte].[UserScans] + [cte].[UserLookups] ) = 0
ORDER BY 
	( [cte].[UserSeek] + [cte].[UserScans] + [cte].[UserLookups] ) ASC
	, [cte].[ObjectName];
GO
