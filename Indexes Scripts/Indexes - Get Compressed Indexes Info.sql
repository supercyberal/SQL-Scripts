--Check for data compression for all tables
SELECT  SCHEMA_NAME([schema_id]) AS [SchemaName],
        OBJECT_NAME([objects].[object_id]) AS [ObjectName],
        [rows],
        [data_compression_desc],
        [index_id] AS [IndexID_on_Table]
FROM    [sys].[partitions]
        INNER JOIN [sys].[objects] ON [partitions].[object_id] = [objects].[object_id]
WHERE   [data_compression] > 0
        AND SCHEMA_NAME([schema_id]) <> 'SYS'
ORDER BY [SchemaName],
        [ObjectName];


--Check VarDecimal all tables
SELECT  [name],
        [object_id],
        [type_desc]
FROM    [sys].[objects]
WHERE   OBJECTPROPERTY([object_id], N'TableHasVarDecimalStorageFormat') = 1; 
GO 

--Estimate the amount of additional disk space that will be required after disabling compression
SELECT  SUM([s].[used_page_count]) * 8 * 2 / 1024.0
FROM    [sys].[partitions] [p]
        JOIN [sys].[dm_db_partition_stats] [s] ON [s].[partition_id] = [p].[partition_id]
                                            AND [s].[object_id] = [p].[object_id]
                                            AND [s].[index_id] = [p].[index_id]
WHERE   [p].[data_compression_desc] = 'page';

