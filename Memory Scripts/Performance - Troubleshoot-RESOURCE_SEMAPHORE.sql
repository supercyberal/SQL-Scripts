/***********************************************************************************************************************************************
Description:	Get RESOURCE_SEMAPHORE sessions and DMV details. Based from this article:
				https://www.mssqltips.com/sqlservertip/2827/troubleshooting-sql-server-resourcesemaphore-waittype-memory-issues/

Notes:			Alvaro Costa
				2016-06-27 - Created.
***********************************************************************************************************************************************/

-- Get current activity with WhoIsActive
EXEC [dbo].[sp_WhoIsActive]
	@get_locks = 1, -- bit
    @get_plans = 1, -- tinyint
	@get_avg_time = 1, -- bit
	@get_task_info = 1, -- tinyint
    @get_outer_command = 1, -- bit
	@get_additional_info = 1, -- bit
    @get_transaction_info = 1;
GO

-- Get query semaphore memory info.
SELECT * FROM [sys].[dm_exec_query_resource_semaphores] AS [deqrs]
GO

-- Get current memory grants info.
SELECT * FROM [sys].[dm_exec_query_memory_grants] AS mg
CROSS APPLY [sys].[dm_exec_query_plan](mg.[plan_handle]) AS [deqp]
GO

-- Check pending memory grants perfmon counter.
SELECT * FROM [sys].[dm_os_performance_counters] AS [dopc]
WHERE [dopc].[counter_name] LIKE '%grants pending%'
GO