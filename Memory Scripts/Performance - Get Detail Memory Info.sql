------------------------------------------------------------------------------------------------------------------------------------------------
-- Bpool statistics

SELECT  ( CAST([bpool_committed] AS BIGINT) * 8192 ) / ( 1024 * 1024 ) AS [bpool_committed_mb]
       ,( CAST([bpool_commit_target] AS BIGINT) * 8192 ) / ( 1024 * 1024 ) AS [bpool_target_mb]
       ,( CAST([bpool_visible] AS BIGINT) * 8192 ) / ( 1024 * 1024 ) AS [bpool_visible_mb]
FROM    [sys].[dm_os_sys_info];
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Get me physical RAM installed and size of user VAS.

SELECT  [physical_memory_in_bytes] / ( 1024 * 1024 ) AS [phys_mem_mb]
       ,[virtual_memory_in_bytes] / ( 1024 * 1024 ) AS [user_virtual_address_space_size]
FROM    [sys].[dm_os_sys_info];
GO
 
------------------------------------------------------------------------------------------------------------------------------------------------
--System memory information.
 
SELECT  [total_physical_memory_kb] / ( 1024 ) AS [phys_mem_mb]
       ,[available_physical_memory_kb] / ( 1024 ) AS [avail_phys_mem_mb]
       ,[system_cache_kb] / ( 1024 ) AS [sys_cache_mb]
       ,( [kernel_paged_pool_kb] + [kernel_nonpaged_pool_kb] ) / ( 1024 ) AS [kernel_pool_mb]
       ,[total_page_file_kb] / ( 1024 ) AS [total_virtual_memory_mb]
       ,[available_page_file_kb] / ( 1024 ) AS [available_virtual_memory_mb]
       ,[system_memory_state_desc]
FROM    [sys].[dm_os_sys_memory];
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Memory utilized by SQLSERVR process GetMemoryProcessInfo() API used for this.

SELECT  [physical_memory_in_use_kb] / ( 1024 ) AS [sql_physmem_inuse_mb]
       ,[locked_page_allocations_kb] / ( 1024 ) AS [awe_memory_mb]
       ,[total_virtual_address_space_kb] / ( 1024 ) AS [max_vas_mb]
       ,[virtual_address_space_committed_kb] / ( 1024 ) AS [sql_committed_mb]
       ,[memory_utilization_percentage] AS [working_set_percentage]
       ,[virtual_address_space_available_kb] / ( 1024 ) AS [vas_available_mb]
       ,[process_physical_memory_low] AS [is_there_external_pressure]
       ,[process_virtual_memory_low] AS [is_there_vas_pressure]
FROM    [sys].[dm_os_process_memory];
GO

SELECT  [type]
       ,SUM([single_pages_kb]) AS [Single Pages]
       ,SUM([multi_pages_kb]) AS [Multi Pages]
FROM    [sys].[dm_os_memory_clerks]
GROUP BY [type] 
ORDER BY [Single Pages] DESC
--ORDER BY [Multi Pages] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Resource monitor ringbuffer.

SELECT  [ring_buffer_address]
       ,[ring_buffer_type]
       ,[timestamp]
       ,[record]
FROM    [sys].[dm_os_ring_buffers]
WHERE   [ring_buffer_type] LIKE 'RING_BUFFER_RESOURCE%';
GO
 
------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Memory in each node.
 
SELECT  [memory_node_id] AS [node]
       ,[virtual_address_space_reserved_kb] / ( 1024 ) AS [VAS_reserved_mb]
       ,[virtual_address_space_committed_kb] / ( 1024 ) AS [virtual_committed_mb]
       ,[locked_page_allocations_kb] / ( 1024 ) AS [locked_pages_mb]
       ,[single_pages_kb] / ( 1024 ) AS [single_pages_mb]
       ,[multi_pages_kb] / ( 1024 ) AS [multi_pages_mb]
       ,[shared_memory_committed_kb] / ( 1024 ) AS [shared_memory_mb]
FROM    [sys].[dm_os_memory_nodes]
WHERE   [memory_node_id] <> 64;
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Vas summary.

;WITH    [vasummary] ( [Size], [reserved], [free] )
        AS ( SELECT   [size] = [vadump].[size]
                    ,[reserved] = SUM(CASE ( CONVERT(INT, [vadump].[base]) ^ 0 )
                                        WHEN 0 THEN 0
                                        ELSE 1
                                        END)
                    ,[free] = SUM(CASE ( CONVERT(INT, [vadump].[base]) ^ 0x0 )
                                    WHEN 0 THEN 1
                                    ELSE 0
                                    END)
            FROM     ( SELECT    CONVERT(VARBINARY, SUM([region_size_in_bytes])) AS [size]
                                ,[region_allocation_base_address] AS [base]
                        FROM      [sys].[dm_os_virtual_address_dump]
                        WHERE     [region_allocation_base_address] <> 0x0
                        GROUP BY  [region_allocation_base_address]
                        UNION
                        ( SELECT  CONVERT(VARBINARY, [region_size_in_bytes])
                                ,[region_allocation_base_address]
                        FROM    [sys].[dm_os_virtual_address_dump]
                        WHERE   [region_allocation_base_address] = 0x0
                        )
                    ) AS [vadump]
            GROUP BY [size]
            )
SELECT  [vasummary].[Size]
        ,[vasummary].[reserved]
        ,[vasummary].[free]
FROM    [vasummary];
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Clerks that are consuming memory.

SELECT  [memory_clerk_address]
       ,[type]
       ,[name]
       ,[memory_node_id]
       ,[single_pages_kb]
       ,[multi_pages_kb]
       ,[virtual_memory_reserved_kb]
       ,[virtual_memory_committed_kb]
       ,[awe_allocated_kb]
       ,[shared_memory_reserved_kb]
       ,[shared_memory_committed_kb]
       ,[page_size_bytes]
       ,[page_allocator_address]
       ,[host_address]
FROM    [sys].[dm_os_memory_clerks]
WHERE   ( [single_pages_kb] > 0 )
        OR ( [multi_pages_kb] > 0 )
        OR ( [virtual_memory_committed_kb] > 0 )
ORDER BY [single_pages_kb] DESC;
GO
 
------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Get me stolen pages.

SELECT  ( SUM([single_pages_kb]) * 1024 ) / 8192 AS [total_stolen_pages]
FROM    [sys].[dm_os_memory_clerks];
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Breakdown clerks with stolen pages.

SELECT  [type]
       ,[name]
       ,SUM(( [single_pages_kb] * 1024 ) / 8192) AS [stolen_pages]
FROM    [sys].[dm_os_memory_clerks]
WHERE   [single_pages_kb] > 0
GROUP BY [type]
       ,[name]
ORDER BY [stolen_pages] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Non-Bpool allocation from SQL Server clerks.

SELECT  SUM([multi_pages_kb]) / 1024 AS [total_multi_pages_mb]
FROM    [sys].[dm_os_memory_clerks];
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Who are Non-Bpool consumers.

SELECT  [type]
       ,[name]
       ,SUM([multi_pages_kb]) / 1024 AS [multi_pages_mb]
FROM    [sys].[dm_os_memory_clerks]
WHERE   [multi_pages_kb] > 0
GROUP BY [type]
       ,[name]
ORDER BY [multi_pages_mb] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Let's now get the total consumption of virtual allocator

SELECT  SUM([virtual_memory_committed_kb]) / 1024 AS [total_virtual_mem_mb]
FROM    [sys].[dm_os_memory_clerks];
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Breakdown the clerks who use virtual allocator.

SELECT  [type]
       ,[name]
       ,SUM([virtual_memory_committed_kb]) / 1024 AS [virtual_mem_mb]
FROM    [sys].[dm_os_memory_clerks]
WHERE   [virtual_memory_committed_kb] > 0
GROUP BY [type]
       ,[name]
ORDER BY [virtual_mem_mb] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- memory allocated by AWE allocator API'S.

SELECT  SUM([awe_allocated_kb]) / 1024 AS [total_awe_allocated_mb]
FROM    [sys].[dm_os_memory_clerks];
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Who clerks consumes memory using AWE.

SELECT  [type]
       ,[name]
       ,SUM([awe_allocated_kb]) / 1024 AS [awe_allocated_mb]
FROM    [sys].[dm_os_memory_clerks]
WHERE   [awe_allocated_kb] > 0
GROUP BY [type]
       ,[name]
ORDER BY [awe_allocated_mb] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- What is the total memory used by the clerks?.

SELECT  ( SUM([multi_pages_kb]) + SUM([virtual_memory_committed_kb]) + SUM([awe_allocated_kb]) ) / 1024
FROM    [sys].[dm_os_memory_clerks];
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Does this sync up with what the node thinks?

SELECT  SUM([virtual_address_space_committed_kb]) / 1024 AS [total_node_virtual_memory_mb]
       ,SUM([locked_page_allocations_kb]) / 1024 AS [total_awe_memory_mb]
       ,SUM([single_pages_kb]) / 1024 AS [total_single_pages_mb]
       ,SUM([multi_pages_kb]) / 1024 AS [total_multi_pages_mb]
FROM    [sys].[dm_os_memory_nodes]
WHERE   [memory_node_id] <> 64;
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Total memory used by SQL Server through SQLOS memory nodes
-- including DAC node
-- What takes up the rest of the space?

SELECT  ( SUM([virtual_address_space_committed_kb]) + SUM([locked_page_allocations_kb]) + SUM([multi_pages_kb]) ) / 1024 AS [total_sql_memusage_mb]
FROM    [sys].[dm_os_memory_nodes];
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Who are the biggest cache stores?

SELECT  [name]
       ,[type]
       ,( SUM([single_pages_kb]) + SUM([multi_pages_kb]) ) / 1024 AS [cache_size_mb]
FROM    [sys].[dm_os_memory_cache_counters]
WHERE   [type] LIKE 'CACHESTORE%'
GROUP BY [name]
       ,[type]
ORDER BY [cache_size_mb] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Who are the biggest user stores?

SELECT  [name]
       ,[type]
       ,( SUM([single_pages_kb]) + SUM([multi_pages_kb]) ) / 1024 AS [cache_size_mb]
FROM    [sys].[dm_os_memory_cache_counters]
WHERE   [type] LIKE 'USERSTORE%'
GROUP BY [name]
       ,[type]
ORDER BY [cache_size_mb] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------ 
-- Who are the biggest object stores?

SELECT  [name]
       ,[type]
       ,( SUM([single_pages_kb]) + SUM([multi_pages_kb]) ) / 1024 AS [cache_size_mb]
FROM    [sys].[dm_os_memory_clerks]
WHERE   [type] LIKE 'OBJECTSTORE%'
GROUP BY [name]
       ,[type]
ORDER BY [cache_size_mb] DESC;
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
-- Which object is really consuming from clerk.

SELECT  [a].[memory_clerk_address]
       ,[a].[type]
       ,[a].[name]
       ,[a].[memory_node_id]
       ,[a].[single_pages_kb]
       ,[a].[multi_pages_kb]
       ,[a].[virtual_memory_reserved_kb]
       ,[a].[virtual_memory_committed_kb]
       ,[a].[awe_allocated_kb]
       ,[a].[shared_memory_reserved_kb]
       ,[a].[shared_memory_committed_kb]
       ,[a].[page_size_bytes]
       ,[a].[page_allocator_address]
       ,[a].[host_address]
       ,[b].[memory_object_address]
       ,[b].[parent_address]
       ,[b].[pages_allocated_count]
       ,[b].[creation_options]
       ,[b].[bytes_used]
       ,[b].[type]
       ,[b].[name]
       ,[b].[memory_node_id]
       ,[b].[creation_time]
       ,[b].[page_size_in_bytes]
       ,[b].[max_pages_allocated_count]
       ,[b].[page_allocator_address]
       ,[b].[creation_stack_address]
       ,[b].[sequence_num]
FROM    [sys].[dm_os_memory_clerks] [a]
       ,[sys].[dm_os_memory_objects] [b]
WHERE   [a].[page_allocator_address] = [b].[page_allocator_address]
--group by a.type, b.type
ORDER BY [a].[type]
       ,[b].[type];
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
--To get the list of 3rd party DLL loaded inside SQL server memory.

SELECT  *
FROM    [sys].[dm_os_loaded_modules]
WHERE   [company] <> 'Microsoft Corporation';
GO

------------------------------------------------------------------------------------------------------------------------------------------------  
--Which database page is in my memory.

;WITH    [cteMem]
        AS ( SELECT   DB_NAME([database_id]) AS [DBName],
                    ( CAST(COUNT(*) AS BIGINT) * 8192 ) / 1024 / 1024 AS "size in mb"
            FROM     [sys].[dm_os_buffer_descriptors]
            GROUP BY DB_NAME([database_id])
            )
SELECT  [cte].[DBName],
        [cte].[size in mb]
FROM    [cteMem] [cte]
ORDER BY [cte].[size in mb] DESC;

------------------------------------------------------------------------------------------------------------------------------------------------
-- Get connection memory info.

SELECT  [object_name]
       ,[counter_name]
       ,[cntr_value]
       ,[cntr_value] / 1024. / 1024. AS [Value_GB]
FROM    [sys].[dm_os_performance_counters]
WHERE   [counter_name] = 'Connection Memory (KB)';
--WHERE [counter_name] LIKE '%Fault%'

------------------------------------------------------------------------------------------------------------------------------------------------
-- Get number of users connections.

SELECT  [object_name]
       ,[counter_name]
       ,[cntr_value]
FROM    [sys].[dm_os_performance_counters]
WHERE   [counter_name] = 'User Connections';

------------------------------------------------------------------------------------------------------------------------------------------------
-- Find all queries waiting in the memory queue:

SELECT  *
FROM    [sys].[dm_exec_query_memory_grants]
WHERE   [grant_time] IS NULL;

------------------------------------------------------------------------------------------------------------------------------------------------
-- Find who uses the most query memory grant

SELECT  [mg].[granted_memory_kb],
        [mg].[session_id],
        [t].[text],
        [qp].[query_plan]
FROM    [sys].[dm_exec_query_memory_grants] AS [mg]
        CROSS APPLY [sys].[dm_exec_sql_text]([mg].[sql_handle]) AS [t]
        CROSS APPLY [sys].[dm_exec_query_plan]([mg].[plan_handle]) AS [qp]
ORDER BY 1 DESC
OPTION  ( MAXDOP 1 );

------------------------------------------------------------------------------------------------------------------------------------------------
-- Search cache for queries with memory grants

SELECT  [t].[text],
        [cp].[objtype],
        [qp].[query_plan]
FROM    [sys].[dm_exec_cached_plans] AS [cp]
        JOIN [sys].[dm_exec_query_stats] AS [qs] ON [cp].[plan_handle] = [qs].[plan_handle]
        CROSS APPLY [sys].[dm_exec_query_plan]([cp].[plan_handle]) AS [qp]
        CROSS APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [t]
WHERE   [qp].[query_plan].[exist]('declare namespace n="http://schemas.microsoft.com/sqlserver/2004/07/showplan"; //n:MemoryFractions') = 1;