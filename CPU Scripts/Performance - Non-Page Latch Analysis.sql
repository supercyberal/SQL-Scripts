/***********************************************************************************************************************************************
Description:	Used to check the TOP most consuming Non-Pages LATCH types class.

Notes:			ACOSTA - 2014-03-26
				Created.
***********************************************************************************************************************************************/

WITH    [Latches]
          AS (SELECT    [latch_class]
                       ,[wait_time_ms] / 1000.0 AS [WaitS]
                       ,[waiting_requests_count] AS [WaitCount]
                       ,100.0 * [wait_time_ms] / SUM([wait_time_ms]) OVER () AS [Percentage]
                       ,ROW_NUMBER() OVER (ORDER BY [wait_time_ms] DESC) AS [RowNum]
              FROM      sys.dm_os_latch_stats
              WHERE     [latch_class] NOT IN ('BUFFER',
                                              'CLR_PROCEDURE_HASHTABLE',
                                              'CLR_UDX_STORE',
                                              'CLR_DATAT_ACCESS',
                                              'CLR_XVAR_PROXY_LIST',
                                              'DBCC_CHECK_AGGREGATE',
                                              'DBCC_CHECK_RESULTSET',
                                              'DBCC_CHECK_TABLE',
                                              'DBCC_CHECK_TABLE_INIT',
                                              'DBCC_CHECK_TRACE_LIST',
                                              'DBCC_FILE_CHECK_OBJECT',
                                              'DBCC_PFS_STATUS',
                                              'DBCC_OBJECT_METADATA',
                                              'DBCC_HASH_DLL',
                                              'EVENTING_CACHE', 'FCB_REPLICA',
                                              'FILEGROUP_MANAGER',
                                              'FILE_MANAGER', 'FILESTREAM_FCB',
                                              'FILESTREAM_FILE_MANAGER',
                                              'FILESTREAM_GHOST_FILES',
                                              'FILESTREAM_DFS_ROOT',
                                              'FULLTEXT_DOCUMENT_ID',
                                              'FULLTEXT_DOCUMENT_ID_TRANSACTION',
                                              'FULLTEXT_DOCUMENT_ID_NOTIFY',
                                              'FULLTEXT_LOGS',
                                              'FULLTEXT_CRAWL_LOG',
                                              'FULLTEXT_ADMIN',
                                              'FULLTEXT_AMDIN_COMMAND_CACHE',
                                              'FULLTEXT_LANGUAGE_TABLE',
                                              'FULLTEXT_CRAWL_DM_LIST',
                                              'FULLTEXT_CRAWL_CATALOG',
                                              'FULLTEXT_FILE_MANAGER',
                                              'DATABASE_MIRRORING_REDO',
                                              'DATABASE_MIRRORING_SERVER',
                                              'DATABASE_MIRRORING_STREAM',
                                              'QUERY_OPTIMIZER_VD_MANAGER',
                                              'QUERY_OPTIMIZER_ID_MANAGER',
                                              'QUERY_OPTIMIZER_VIEW_REP',
                                              'RECOVERY_BAD_PAGE_TABLE',
                                              'RECOVERY_MANAGER',
                                              'SECURITY_OPERATION_RULE_TABLE',
                                              'SECURITY_OBJPERM_CACHE',
                                              'SECURITY_CRYPTO',
                                              'SECURITY_KEY_RING',
                                              'SECURITY_KEY_LIST',
                                              'SERVICE_BROKER_CONNECTION_RECEIVE',
                                              'SERVICE_BROKER_TRANSMISSION',
                                              'SERVICE_BROKER_TRANSMISSION_UPDATE',
                                              'SERVICE_BROKER_TRANSMISSION_STATE',
                                              'SERVICE_BROKER_TRANSMISSION_ERRORS',
                                              'SSBXmitWork',
                                              'SERVICE_BROKER_MESSAGE_TRANSMISSION',
                                              'SERVICE_BROKER_MAP_MANAGER',
                                              'SERVICE_BROKER_HOST_NAME',
                                              'SERVICE_BROKER_READ_CACHE',
                                              'SERVICE_BROKER_WAITFOR_MANAGER',
                                              'SERVICE_BROKER_WAITFOR_TRANSACTION_DATA',
                                              'SERVICE_BROKER_TRANSMISSION_TRANSACTION_DATA',
                                              'SERVICE_BROKER_TRANSPORT',
                                              'SERVICE_BROKER_MIRROR_ROUTE',
                                              'TRACE_ID', 'TRACE_AUDIT_ID',
                                              'TRACE', 'TRACE_EVENT_QUEUE',
                                              'TRANSACTION_DISTRIBUTED_MARK',
                                              'TRANSACTION_OUTCOME',
                                              'NESTING_TRANSACTION_READONLY',
                                              'MSQL_TRANSACTION_MANAGER',
                                              'DATABASE_AUTONAME_MANAGER',
                                              'UTILITY_DYNAMIC_VECTOR',
                                              'UTILITY_SPARSE_BITMAP',
                                              'UTILITY_DATABASE_DROP',
                                              'UTILITY_DYNAMIC_MANAGER_VIEW',
                                              'UTILITY_DEBUG_FILESTREAM',
                                              'UTILITY_LOCK_INFORMATION',
                                              'VERSIONING_TRANSACTION',
                                              'VERSIONING_TRANSACTION_LIST',
                                              'VERSIONING_TRANSACTION_CHAIN',
                                              'VERSIONING_STATE',
                                              'VERSIONING_STATE_CHANGE',
                                              'KTM_VIRTUAL_CLOCK')
                        AND [wait_time_ms] > 0
             )
    SELECT  [L1].[latch_class] AS [LatchClass]
           ,latch_class_Description = CASE WHEN [L1].[latch_class] = 'ALLOC_CREATE_RINGBUF'
                                           THEN 'Used internally by SQL Server to initialize the synchronization of the creation of an allocation ring buffer.'
                                           WHEN [L1].[latch_class] = 'ALLOC_CREATE_FREESPACE_CACHE'
                                           THEN 'Used to initialize the synchronization of internal freespace caches for heaps.'
                                           WHEN [L1].[latch_class] = 'ALLOC_CACHE_MANAGER'
                                           THEN 'Used to synchronize internal coherency tests.'
                                           WHEN [L1].[latch_class] = 'ALLOC_FREESPACE_CACHE'
                                           THEN 'Used to synchronize the access to a cache of pages with available space for heaps and binary large objects (BLOBs). Contention on latches of this class can occur when multiple connections try to insert rows into a heap or BLOB at the same time. You can reduce this contention by partitioning the object. Each partition has its own latch. Partitioning will distribute the inserts across multiple latches.'
                                           WHEN [L1].[latch_class] = 'ALLOC_EXTENT_CACHE'
                                           THEN 'Used to synchronize the access to a cache of extents that contains pages that are not allocated. Contention on latches of this class can occur when multiple connections try to allocate data pages in the same allocation unit at the same time. This contention can be reduced by partitioning the object of which this allocation unit is a part.'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_DATASET_PARENT'
                                           THEN 'Used to synchronize child dataset access to the parent dataset during parallel operations. FROM PAUL RANDAL BLOG: These two latches(ACCESS_METHODS_DATASET_PARENT and ACCESS_METHODS_SCAN_RANGE_GENERATOR) are used during parallel scans to give each thread a range of page IDs to scan. The LATCH_XX waits for these latches will typically appear with CXPACKET waits and PAGEIOLATCH_XX waits (if the data being scanned is not memory-resident). Use normal parallelism troubleshooting methods to investigate further (e.g. is the parallelism warranted? maybe increase "cost threshold for parallelism", lower MAXDOP, use a MAXDOP hint, use Resource Governor to limit DOP using a workload group with a MAX_DOP limit. Did a plan change from index seeks to parallel table scans because a tipping point was reached or a plan recompiled with an atypical SP parameter or poor statistics? Do NOT knee-jerk and set server MAXDOP to 1 – that is some of the worst advice I see on the Internet.)--source:http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/ '
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_HOBT_FACTORY'
                                           THEN 'Used to synchronize access to an internal hash table.'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_HOBT'
                                           THEN 'Used to synchronize access to the in-memory representation of a HoBt.'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_HOBT_COUNT'
                                           THEN 'Used to synchronize access to a HoBt page and row counters. From Paul Randals Blog: This latch is used to flush out page and row count deltas for a HoBt (Heap-or-B-tree) to the Storage Engine metadata tables. Contention would indicate *lots* of small, concurrent DML operations on a single table. --Source: http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_HOBT_VIRTUAL_ROOT'
                                           THEN 'Used to synchronize access to the root page abstraction of an internal B-tree. From Paul Randals Blog: This latch is used to access the metadata for an index that contains the page ID of the root page of the index. Contention on this latch can occur when a B-tree root page split occurs (requiring the latch in EX mode) and threads wanting to navigate down the B-tree (requiring the latch in SH mode) have to wait. This could be from very fast population of a small index using many concurrent connections, with or without page splits from random key values causing cascading page splits (from leaf to root).--source:http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_CACHE_ONLY_HOBT_ALLOC'
                                           THEN 'Used to synchronize worktable access.'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_BULK_ALLOC'
                                           THEN 'Used to synchronize access within bulk allocators.'
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_SCAN_RANGE_GENERATOR'
                                           THEN 'Used to synchronize access to a range generator during parallel scans. FROM PAUL RANDAL BLOG: These two latches(ACCESS_METHODS_DATASET_PARENT and ACCESS_METHODS_SCAN_RANGE_GENERATOR) are used during parallel scans to give each thread a range of page IDs to scan. The LATCH_XX waits for these latches will typically appear with CXPACKET waits and PAGEIOLATCH_XX waits (if the data being scanned is not memory-resident). Use normal parallelism troubleshooting methods to investigate further (e.g. is the parallelism warranted? maybe increase "cost threshold for parallelism", lower MAXDOP, use a MAXDOP hint, use Resource Governor to limit DOP using a workload group with a MAX_DOP limit. Did a plan change from index seeks to parallel table scans because a tipping point was reached or a plan recompiled with an atypical SP parameter or poor statistics? Do NOT knee-jerk and set server MAXDOP to 1 – that is some of the worst advice I see on the Internet.)--source:http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/ '
                                           WHEN [L1].[latch_class] = 'ACCESS_METHODS_KEY_RANGE_GENERATOR'
                                           THEN 'Used to synchronize access to read-ahead operations during key range parallel scans.'
                                           WHEN [L1].[latch_class] = 'APPEND_ONLY_STORAGE_INSERT_POINT'
                                           THEN 'Used to synchronize inserts in fast append-only storage units.'
                                           WHEN [L1].[latch_class] = 'APPEND_ONLY_STORAGE_FIRST_ALLOC'
                                           THEN 'Used to synchronize the first allocation for an append-only storage unit.'
                                           WHEN [L1].[latch_class] = 'APPEND_ONLY_STORAGE_UNIT_MANAGER'
                                           THEN 'Used for internal data structure access synchronization within the fast append-only storage unit manager.'
                                           WHEN [L1].[latch_class] = 'APPEND_ONLY_STORAGE_MANAGER'
                                           THEN 'Used to synchronize shrink operations in the fast append-only storage unit manager.'
                                           WHEN [L1].[latch_class] = 'BACKUP_RESULT_SET'
                                           THEN 'Used to synchronize parallel backup result sets.'
                                           WHEN [L1].[latch_class] = 'BACKUP_TAPE_POOL'
                                           THEN 'Used to synchronize backup tape pools.'
                                           WHEN [L1].[latch_class] = 'BACKUP_LOG_REDO'
                                           THEN 'Used to synchronize backup log redo operations.'
                                           WHEN [L1].[latch_class] = 'BACKUP_INSTANCE_ID'
                                           THEN 'Used to synchronize the generation of instance IDs for backup performance monitor counters.'
                                           WHEN [L1].[latch_class] = 'BACKUP_MANAGER'
                                           THEN 'Used to synchronize the internal backup manager.'
                                           WHEN [L1].[latch_class] = 'BACKUP_MANAGER_DIFFERENTIAL'
                                           THEN 'Used to synchronize differential backup operations with DBCC.'
                                           WHEN [L1].[latch_class] = 'BACKUP_OPERATION'
                                           THEN 'Used for internal data structure synchronization within a backup operation, such as database, log, or file backup.'
                                           WHEN [L1].[latch_class] = 'BACKUP_FILE_HANDLE'
                                           THEN 'Used to synchronize file open operations during a restore operation.'
                                           WHEN [L1].[latch_class] = 'BUFFER'
                                           THEN 'Used to synchronize short term access to database pages. A buffer latch is required before reading or modifying any database page. Buffer latch contention can indicate several issues, including hot pages and slow I/Os. This latch class covers all possible uses of page latches. sys.dm_os_wait_stats makes a difference between page latch waits that are caused by I/O operations and read and write operations on the page.'
                                           WHEN [L1].[latch_class] = 'BUFFER_POOL_GROW'
                                           THEN 'Used for internal buffer manager synchronization during buffer pool grow operations.'
                                           WHEN [L1].[latch_class] = 'DATABASE_CHECKPOINT'
                                           THEN 'Used to serialize checkpoints within a database.'
                                           WHEN [L1].[latch_class] = 'DBCC_PERF'
                                           THEN 'Used to synchronize internal performance monitor counters.'
                                           WHEN [L1].[latch_class] = 'FCB'
                                           THEN 'Used to synchronize access to the file control block.'
                                           WHEN [L1].[latch_class] = 'FGCB_ALLOC'
                                           THEN 'Use to synchronize access to round robin allocation information within a filegroup.'
                                           WHEN [L1].[latch_class] = 'FGCB_ADD_REMOVE'
                                           THEN 'Use to synchronize access to filegroups for ADD and DROP file operations. FROM PAUL RANDALs Blog: FGCB stands for File Group Control Block. This latch is required whenever a file is added or dropped from the filegroup, whenever a file is grown (manually or automatically), when recalculating proportional-fill weightings, and when cycling through the files in the filegroup as part of round-robin allocation. If you are seeing this, the most common cause is that there is a lot of file auto-growth happening. It could also be from a filegroup with lots of file (e.g. the primary filegroup in tempdb) where there are thousands of concurrent connections doing allocations. The proportional-fill weightings are recalculated every 8192 allocations, so there is the possibility of a slowdown with frequent recalculations over many files.--source:http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'DBCC_MULTIOBJECT_SCANNER'
                                           THEN 'FROM PAUL RANDALs Blog: This latch appears on Enterprise Edition when DBCC CHECK* commands are allowed to run in parallel. It is used by threads to request the next data file page to process. Late last year this was identified as a major contention point inside DBCC CHECK* and there was work done to reduce the contention and make DBCC CHECK* run faster. See KB article 2634571(http://support.microsoft.com/kb/2634571) and Bob Wards write-up (http://blogs.msdn.com/b/psssql/archive/2012/02/23/a-faster-checkdb-part-ii.aspx) for more details.--Source: http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'LOG_MANAGER'
                                           THEN 'FROM PAUL RANDALs Blog: If you see this latch it is almost certainly because a transaction log is growing because it could not clear/truncate for some reason. Find the database where the log is growing and then figure out what is preventing log clearing using: SELECT [log_reuse_wait_desc] FROM sys.databases WHERE [name] = [youdbname] --Source: http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'TRACE_CONTROLLER'
                                           THEN 'FROM PAUL RANDALs Blog: This latch is used by SQL Trace for myriad different things, including just generating trace events. Contention on this latch would imply that there are multiple traces on the server tracing lots of stuff – i.e. you are over-tracing.--Source: http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'DATABASE_MIRRORING_CONNECTION'
                                           THEN 'FROM PAUL RANDALs Blog: This latch is involved in controlling the message flow for database mirroring sessions on a server. If this latch is prevalent, I would suspect there are too many busy database mirroring sessions on the server.--source:http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           WHEN [L1].[latch_class] = 'NESTING_TRANSACTION_FULL'
                                           THEN 'FROM PAUL RANDALs Blog: This latch, along with NESTING_TRANSACTION_READONLY, is used to control access to transaction description structures (called an XDES) for parallel nested transactions. The _FULL is for a transaction that is "active", i.e. it is changed the database (usually for an index build/rebuild), and that makes the _READONLY description obvious. A query that involves a parallel operator must start a sub-transaction for each parallel thread that is used – these transactions are sub-transactions of the parallel nested transaction. For contention on these, I had investigate unwanted parallelism but I do not have a definite "it is usually this problem". Also check out the comments for some info about these also sometimes being a problem when RCSI is used.--source:http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                           ELSE 'This Latch type type is not documented in http://msdn.microsoft.com/en-us/library/ms175066.aspx or in http://www.sqlskills.com/blogs/paul/most-common-latch-classes-and-what-they-mean/'
                                      END
           ,CAST ([L1].[WaitS] AS DECIMAL(14, 2)) AS [Wait_S]
           ,[L1].[WaitCount] AS [WaitCount]
           ,CAST ([L1].[Percentage] AS DECIMAL(14, 2)) AS [Percentage]
           ,CAST (([L1].[WaitS] / [L1].[WaitCount]) AS DECIMAL(14, 4)) AS [AvgWait_S]
    FROM    [Latches] AS [L1]
            INNER JOIN [Latches] AS [W2] ON [W2].[RowNum] <= [L1].[RowNum]
    WHERE   [L1].[WaitCount] > 0
    GROUP BY [L1].[RowNum]
           ,[L1].[latch_class]
           ,[L1].[WaitS]
           ,[L1].[WaitCount]
           ,[L1].[Percentage]
    HAVING  SUM([W2].[Percentage]) - [L1].[Percentage] < 95; -- percentage threshold
GO


