DECLARE @dbid INT;
SELECT @dbid = DB_ID(DB_NAME());

SELECT OBJECT_NAME([I].[object_id]) AS [OBJECTNAME],
       [I].[name] AS [INDEXNAME],
       [I].[index_id]
FROM [sys].[indexes] AS [I]
    JOIN [sys].[objects] AS [O]
        ON [I].[object_id] = [O].[object_id]
WHERE OBJECTPROPERTY([O].[object_id], 'IsUserTable') = 1
      AND [I].[index_id] NOT IN
          (
              SELECT [S].[index_id]
              FROM [sys].[dm_db_index_usage_stats] AS [S]
              WHERE [S].[object_id] = [I].[object_id]
                    AND [I].[index_id] = [S].[index_id]
                    AND [S].[database_id] = @dbid
          )
ORDER BY [OBJECTNAME],
         [I].[index_id],
         [INDEXNAME] ASC;
GO