-- Get worker thread info.
SELECT  [cpu_count],
        [hyperthread_ratio],
        [max_workers_count],
        [scheduler_count]
FROM    [sys].[dm_os_sys_info];
GO

-- Check for schedulers.
SELECT * FROM sys.[dm_os_schedulers] AS [dos]
GO

-- Check for current workers.
SELECT * FROM [sys].[dm_os_workers];
GO

-- Check for current tasks.
SELECT * FROM [sys].[dm_os_threads] AS [dot]
GO

-- Get infor about THREADPOOL since last restart. 
SELECT  [wait_type],
        [waiting_tasks_count],
        [wait_time_ms],
        [max_wait_time_ms],
        [signal_wait_time_ms]
FROM    [sys].[dm_os_wait_stats]
WHERE   [wait_type] = 'THREADPOOL';
GO

-- You can also look at the connectivity ring buffer and see it in the LoginTaskEnqueuedInMilliseconds output.
-- Get connection info from RING_BUFFER.
;WITH cteResults AS (
SELECT  [tab].[record].[value]('(Record/@id)[1]', 'int') AS [id],
        [tab].[record].[value]('(Record/@type)[1]', 'varchar(50)') AS [type],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/RecordType)[1]', 'varchar(50)') AS [RecordType],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/RecordSource)[1]', 'varchar(50)') AS [RecordSource],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/Spid)[1]', 'int') AS [Spid],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/SniConnectionId)[1]', 'uniqueidentifier') AS [SniConnectionId],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/SniProvider)[1]', 'int') AS [SniProvider],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/OSError)[1]', 'int') AS [OSError],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/SniConsumerError)[1]', 'int') AS [SniConsumerError],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/State)[1]', 'int') AS [State],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/RemoteHost)[1]', 'varchar(50)') AS [RemoteHost],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/RemotePort)[1]', 'varchar(50)') AS [RemotePort],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LocalHost)[1]', 'varchar(50)') AS [LocalHost],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LocalPort)[1]', 'varchar(50)') AS [LocalPort],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/RecordTime)[1]', 'datetime') AS [RecordTime],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/TotalLoginTimeInMilliseconds)[1]', 'bigint') AS [TotalLoginTimeInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/LoginTaskEnqueuedInMilliseconds)[1]', 'bigint') AS [LoginTaskEnqueuedInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/NetworkWritesInMilliseconds)[1]', 'bigint') AS [NetworkWritesInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/NetworkReadsInMilliseconds)[1]', 'bigint') AS [NetworkReadsInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/SslProcessingInMilliseconds)[1]', 'bigint') AS [SslProcessingInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/SspiProcessingInMilliseconds)[1]', 'bigint') AS [SspiProcessingInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/LoginTimers/LoginTriggerAndResourceGovernorProcessingInMilliseconds)[1]',
                     'bigint') AS [LoginTriggerAndResourceGovernorProcessingInMilliseconds],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsInputBufferError)[1]', 'int') AS [TdsInputBufferError],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsOutputBufferError)[1]', 'int') AS [TdsOutputBufferError],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsInputBufferBytes)[1]', 'int') AS [TdsInputBufferBytes],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/PhysicalConnectionIsKilled)[1]', 'int') AS [PhysicalConnectionIsKilled],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/DisconnectDueToReadError)[1]', 'int') AS [DisconnectDueToReadError],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/NetworkErrorFoundInInputStream)[1]', 'int') AS [NetworkErrorFoundInInputStream],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/ErrorFoundBeforeLogin)[1]', 'int') AS [ErrorFoundBeforeLogin],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/SessionIsKilled)[1]', 'int') AS [SessionIsKilled],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/NormalDisconnect)[1]', 'int') AS [NormalDisconnect],
        [tab].[record].[value]('(Record/ConnectivityTraceRecord/TdsDisconnectFlags/NormalLogout)[1]', 'int') AS [NormalLogout]
FROM    ( SELECT    CAST([record] AS XML) AS [record]
          FROM      [sys].[dm_os_ring_buffers]
          WHERE     [ring_buffer_type] = 'RING_BUFFER_CONNECTIVITY'
        ) AS [tab]
)
SELECT * FROM [cteResults] cte
ORDER BY [cte].[id] DESC
