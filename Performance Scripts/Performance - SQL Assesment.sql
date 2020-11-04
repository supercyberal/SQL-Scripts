-- Get SQL service info.
SELECT  [servicename]
       ,[startup_type_desc]
       ,[status_desc]
       ,[last_startup_time]
       ,[service_account]
       ,[is_clustered]
       ,[cluster_nodename]
FROM    [sys].[dm_server_services]
OPTION  ( RECOMPILE );

-- Get SQL installation date.
SELECT  [createdate] AS [SQL Server Install Date]
FROM    [sys].[syslogins]
WHERE   [sid] = 0x010100000000000512000000;

-- Get server info.
SELECT  
CONVERT(VARCHAR(20), SERVERPROPERTY('ServerName')) [ServerName]
,CONVERT(VARCHAR(20), SERVERPROPERTY('MachineName')) [MachineName]
,CONVERT(VARCHAR(40), SERVERPROPERTY('Collation')) [Collation]
,CONVERT(VARCHAR(40), SERVERPROPERTY('Edition')) [Edition]
,CONVERT(VARCHAR(20), SERVERPROPERTY('InstanceName')) [InstanceName]
,CONVERT(VARCHAR(20), SERVERPROPERTY('ProcessID')) [ProcessID]
,CONVERT(VARCHAR(20), SERVERPROPERTY('ProductVersion')) [ProductVersion]
,CONVERT(VARCHAR(20), SERVERPROPERTY('ProductLevel')) [ProductLevel]
,CONVERT(VARCHAR(20), SERVERPROPERTY('LicenseType')) [LicenseType]
,CONVERT(VARCHAR(20), SERVERPROPERTY('NumLicenses')) [NumLicenses]
,CASE SERVERPROPERTY('EngineEdition')
    WHEN 1 THEN 'Desktop Engine'
    WHEN 2 THEN 'Standard'
    WHEN 3 THEN 'Enterprise'
END [EngineEdition]
,CASE SERVERPROPERTY('IsClustered')
    WHEN 0 THEN 'Not Clustered'
    WHEN 1 THEN 'Clustered'
    ELSE 'error'
END [IsClustered]
,CASE SERVERPROPERTY('IsFullTextInstalled')
    WHEN 0 THEN 'Full-text is not installed'
    WHEN 1 THEN 'Full-text is installed'
    ELSE 'error'
END [IsFullTextInstalled]
,CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
    WHEN 0 THEN 'Not Integrated Security'
    WHEN 1 THEN 'Integrated Security'
    ELSE 'error'
END [IsIntegratedSecurityOnly]
,CASE SERVERPROPERTY('IsSingleUser')
    WHEN 0 THEN 'Not Single User'
    WHEN 1 THEN 'Single User'
    ELSE 'error'
END [IsSingleUser]
,CASE SERVERPROPERTY('IsSyncWithBackup')
    WHEN 0 THEN 'FALSE'
    WHEN 1 THEN 'TRUE'
END [IsSyncWithBackup]
,[@@version] = @@version;

-- Get plan cache info.
SELECT  [objtype] AS [CacheType]
       ,COUNT_BIG(*) AS [Total Plans]
       ,SUM(CAST([size_in_bytes] AS DECIMAL(18, 2))) / 1024 / 1024 AS [Total MBs]
       ,AVG([usecounts]) AS [Avg Use Count]
       ,SUM(CAST(( CASE WHEN [usecounts] = 1 THEN [size_in_bytes]
                        ELSE 0
                   END ) AS DECIMAL(18, 2))) / 1024 / 1024 AS [Total MBs - USE Count 1]
       ,SUM(CASE WHEN [usecounts] = 1 THEN 1
                 ELSE 0
            END) AS [Total Plans - USE Count 1]
FROM    [sys].[dm_exec_cached_plans]
GROUP BY [objtype]
ORDER BY [Total MBs - USE Count 1] DESC;
GO

-- Get Implicit conversions.
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED; 
GO

DECLARE @dbname sysname; 
SET @dbname = QUOTENAME(DB_NAME()); 

WITH XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan')
SELECT 
   [t].[value]('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'sysname') +'.'+
   [t].[value]('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'sysname') AS [ObjectName]
   ,[t].[value]('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'sysname') AS [ColumnName]
   ,[ic].[DATA_TYPE] AS [ConvertFrom]
   ,[ic].[CHARACTER_MAXIMUM_LENGTH] AS [ConvertFromLength]
   ,[t].[value]('(@DataType)[1]', 'sysname') AS [ConvertTo]
   ,[t].[value]('(@Length)[1]', 'int') AS [ConvertToLength]
   ,[stmt].[value]('(@StatementText)[1]', 'varchar(max)') AS [TSQL]
   ,[qp].[query_plan] 
   ,[cp].[plan_handle]
FROM [sys].[dm_exec_cached_plans] AS [cp] 
    CROSS APPLY [sys].[dm_exec_query_plan]([cp].[plan_handle]) AS [qp] 
    CROSS APPLY [query_plan].[nodes]('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS [batch]([stmt]) 
    CROSS APPLY [stmt].[nodes]('.//Convert[@Implicit="1"]') AS [n]([t]) 
    INNER JOIN [INFORMATION_SCHEMA].[COLUMNS] AS [ic] 
        ON QUOTENAME([ic].[TABLE_SCHEMA]) = [t].[value]('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'sysname') 
        AND QUOTENAME([ic].[TABLE_NAME]) = [t].[value]('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'sysname') 
        AND [ic].[COLUMN_NAME] = [t].[value]('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'sysname') 
WHERE [t].[exist]('ScalarOperator/Identifier/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]') = 1; 


/*
This DMV query shows currently executing tasks and 

tempdb space usage
Once you have isolated the task(s) that are generating lots 

of internal object allocations, 
you can even find out which TSQL statement and its query plan 
for detailed analysis
*/

SELECT TOP 10
        [t1].[session_id]
       ,[t1].[request_id]
       ,[t1].[task_alloc]
       ,[t1].[task_dealloc]
       ,( SELECT    SUBSTRING([text], [t2].[statement_start_offset] / 2 + 1,
                              ( CASE WHEN [t2].[statement_end_offset] = -1 THEN LEN(CONVERT(NVARCHAR(MAX), [text])) * 2
                                     ELSE [t2].[statement_end_offset]
                                END - [t2].[statement_start_offset] ) / 2)
          FROM      [sys].[dm_exec_sql_text]([t2].[sql_handle])
        ) AS [query_text]
       ,( SELECT    [query_plan]
          FROM      [sys].[dm_exec_query_plan]([t2].[plan_handle])
        ) AS [query_plan]
FROM    ( SELECT    [session_id]
                   ,[request_id]
                   ,SUM([internal_objects_alloc_page_count] + [user_objects_alloc_page_count]) AS [task_alloc]
                   ,SUM([internal_objects_dealloc_page_count] + [user_objects_dealloc_page_count]) AS [task_dealloc]
          FROM      [sys].[dm_db_task_space_usage]
          GROUP BY  [session_id]
                   ,[request_id]
        ) AS [t1]
       ,[sys].[dm_exec_requests] AS [t2]
WHERE   [t1].[session_id] = [t2].[session_id]
        AND ( [t1].[request_id] = [t2].[request_id] )
        AND [t1].[session_id] > 50
ORDER BY [t1].[task_alloc] DESC;


-- TempDB allocations.
SELECT TOP 10
        [t1].[session_id]
       ,[t1].[request_id]
       ,[t1].[task_alloc]
       ,[t1].[task_dealloc]
       ,( SELECT    SUBSTRING([text], [t2].[statement_start_offset] / 2 + 1,
                              ( CASE WHEN [t2].[statement_end_offset] = -1 THEN LEN(CONVERT(NVARCHAR(MAX), [text])) * 2
                                     ELSE [t2].[statement_end_offset]
                                END - [t2].[statement_start_offset] ) / 2)
          FROM      [sys].[dm_exec_sql_text]([t2].[sql_handle])
        ) AS [query_text]
       ,( SELECT    [query_plan]
          FROM      [sys].[dm_exec_query_plan]([t2].[plan_handle])
        ) AS [query_plan]
FROM    ( SELECT    [session_id]
                   ,[request_id]
                   ,SUM([internal_objects_alloc_page_count] + [user_objects_alloc_page_count]) AS [task_alloc]
                   ,SUM([internal_objects_dealloc_page_count] + [user_objects_dealloc_page_count]) AS [task_dealloc]
          FROM      [sys].[dm_db_task_space_usage]
          GROUP BY  [session_id]
                   ,[request_id]
        ) AS [t1]
       ,[sys].[dm_exec_requests] AS [t2]
WHERE   [t1].[session_id] = [t2].[session_id]
        AND ( [t1].[request_id] = [t2].[request_id] )
        AND [t1].[session_id] > 50
ORDER BY [t1].[task_alloc] DESC;
