/*
Name:	TempDB Allocations
Date:	2013-04-23
*/

USE [master]
GO

-- =============================================================================================================================================
-- 1. All sessions that are and have used TempDB allocations.

WITH cteAlloc AS (
	SELECT
	   [ses].[session_id] AS [SESSION ID]
	   , DB_NAME([u].[database_id]) AS [DATABASE Name]
	   , HOST_NAME AS [System Name]
	   , program_name AS [Program Name]
	   , login_name AS [USER Name]
	   , status

	   , (cpu_time / 1000.) AS [CPU TIME (in Secs)]
	   , (total_scheduled_time / 1000.) AS [Total Scheduled TIME (in Secs)]
	   , (total_elapsed_time / 1000.) AS [Elapsed TIME (in Secs)]

	   , ((cpu_time / 1000.) / 60.) AS [CPU TIME (in Mins)]
	   , ((total_scheduled_time / 1000.) / 60.) AS [Total Scheduled TIME (in Mins)]
	   , ((total_elapsed_time / 1000.) / 60.) AS [Elapsed TIME (in Mins)]

	   -- Memory usage.
	   , ( memory_usage * 8 ) AS [Memory USAGE (in KB)]

	   , CAST((u.user_objects_alloc_page_count * 8) / 1024. AS DECIMAL(10,2)) AS [SPACE Allocated FOR USER Objects (in MB)]
	   , CAST((u.user_objects_dealloc_page_count * 8) / 1024. AS DECIMAL(10,2)) AS [SPACE Deallocated FOR USER Objects (in MB)]
	   , CAST((u.internal_objects_alloc_page_count * 8) / 1024. AS DECIMAL(10,2)) AS [SPACE Allocated FOR Internal Objects (in MB)]
	   , CAST((u.internal_objects_dealloc_page_count * 8) / 1024. AS DECIMAL(10,2)) AS [SPACE Deallocated FOR Internal Objects (in MB)]
	FROM sys.dm_db_session_space_usage u
	JOIN sys.dm_exec_sessions ses 
		ON u.session_id = ses.session_id
)
SELECT 
    [SESSION ID]
    , [DATABASE Name]
    , [System Name]
    , [Program Name]
    , [USER Name]
    , [status]
    , [CPU TIME (in Secs)]
    , [Total Scheduled TIME (in Secs)]
    , [Elapsed TIME (in Secs)]
    , [CPU TIME (in Mins)]
    , [Total Scheduled TIME (in Mins)]
    , [Elapsed TIME (in Mins)]
    , [Memory USAGE (in KB)]
    , [SPACE Allocated FOR USER Objects (in MB)]
    , [SPACE Deallocated FOR USER Objects (in MB)]
    , [SPACE Allocated FOR Internal Objects (in MB)]
    , [SPACE Deallocated FOR Internal Objects (in MB)]         
FROM cteAlloc
ORDER BY [cteAlloc].[SPACE Allocated FOR Internal Objects (in MB)] DESC

-- =============================================================================================================================================
-- 2. Only running sessions that are now using TempDB allocations.

SELECT  [SPID] = [s].[session_id]
       ,[s].[host_name]
       ,[s].[program_name]
       ,[s].[status]
       ,[s].[memory_usage]
       ,[granted_memory] = CONVERT(INT, [r].[granted_query_memory] * 8.00)
       ,[t].[text]
       ,[sourcedb] = DB_NAME([r].[database_id])
       ,[workdb] = DB_NAME([dt].[database_id])
       ,[mg].[session_id]
       ,[mg].[request_id]
       ,[mg].[scheduler_id]
       ,[mg].[dop]
       ,[mg].[request_time]
       ,[mg].[grant_time]
       ,[mg].[requested_memory_kb]
       ,[mg].[granted_memory_kb]
       ,[mg].[required_memory_kb]
       ,[mg].[used_memory_kb]
       ,[mg].[max_used_memory_kb]
       ,[mg].[query_cost]
       ,[mg].[timeout_sec]
       ,[mg].[resource_semaphore_id]
       ,[mg].[queue_id]
       ,[mg].[wait_order]
       ,[mg].[is_next_candidate]
       ,[mg].[wait_time_ms]
       ,[mg].[plan_handle]
       ,[mg].[sql_handle]
       ,[mg].[group_id]
       ,[mg].[pool_id]
       ,[mg].[is_small]
       ,[mg].[ideal_memory_kb]
       ,[su].[session_id]
       ,[su].[database_id]
       ,[su].[user_objects_alloc_page_count]
       ,[su].[user_objects_dealloc_page_count]
       ,[su].[internal_objects_alloc_page_count]
       ,[su].[internal_objects_dealloc_page_count]
FROM    [sys].[dm_exec_sessions] [s]
        INNER JOIN [sys].[dm_db_session_space_usage] [su] ON [s].[session_id] = [su].[session_id]
                                                       AND [su].[database_id] = DB_ID('tempdb')
        INNER JOIN [sys].[dm_exec_connections] [c] ON [s].[session_id] = [c].[most_recent_session_id]
        LEFT OUTER JOIN [sys].[dm_exec_requests] [r] ON [r].[session_id] = [s].[session_id]
        LEFT OUTER JOIN ( SELECT    [t].[session_id]
                                   ,[dt].[database_id]
                          FROM      [sys].[dm_tran_session_transactions] [t]
                                    INNER JOIN [sys].[dm_tran_database_transactions] [dt] ON [t].[transaction_id] = [dt].[transaction_id]
                          WHERE     [dt].[database_id] = DB_ID('tempdb')
                          GROUP BY  [t].[session_id]
                                   ,[dt].[database_id]
                        ) [dt] ON [s].[session_id] = [dt].[session_id]
        CROSS APPLY [sys].[dm_exec_sql_text](COALESCE([r].[sql_handle], [c].[most_recent_sql_handle])) [t]
        LEFT OUTER JOIN [sys].[dm_exec_query_memory_grants] [mg] ON [s].[session_id] = [mg].[session_id]
WHERE   (
          [r].[database_id] = DB_ID('tempdb')
          OR [dt].[database_id] = DB_ID('tempdb')
        )
        AND [s].[status] = 'running'
ORDER BY [SPID]; 
