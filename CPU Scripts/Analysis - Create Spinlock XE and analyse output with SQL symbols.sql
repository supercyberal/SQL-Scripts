/*

This Script is provided "AS IS" with no warranties, and confers no rights.
This script will monitor for backoff events over a given period of time and
capture the code paths (callstacks) for those.

--Find the spinlock types
select map_value, map_key, name from sys.dm_xe_map_values
where name = 'spinlock_types'
order by map_value asc

--Example: Get the type value for any given spinlock type
select map_value, map_key, name from sys.dm_xe_map_values
where map_value IN ('SOS_CACHESTORE', 'LOCK_HASH', 'MUTEX')

Examples:
61LOCK_HASH
144 SOS_CACHESTORE
08MUTEX

*/
--create the even session that will capture the callstacks to a bucketizer
--more information is available in this reference: http://msdn.microsoft.com/enus/library/bb630354.aspx
CREATE EVENT SESSION [spin_lock_backoff]
    ON SERVER
    ADD EVENT [sqlos].[spinlock_backoff]
    ( ACTION (
          [package0].[callstack]
      )
     WHERE [Type] = 61 --LOCK_HASH
           OR   [Type] = 144 --SOS_CACHESTORE
           OR   [Type] = 8 --MUTEX
    )
    ADD TARGET [package0].[asynchronous_bucketizer]
    ( SET [filtering_event_name] = 'sqlos.spinlock_backoff', [source_type] = 1, [source] = 'package0.callstack' )
    WITH (
        MAX_MEMORY = 50MB,
        MEMORY_PARTITION_MODE = PER_NODE
    );

--Ensure the session was created
SELECT  [address],
        [name],
        [pending_buffers],
        [total_regular_buffers],
        [regular_buffer_size],
        [total_large_buffers],
        [large_buffer_size],
        [total_buffer_size],
        [buffer_policy_flags],
        [buffer_policy_desc],
        [flags],
        [flag_desc],
        [dropped_event_count],
        [dropped_buffer_count],
        [blocked_event_fire_time],
        [create_time],
        [largest_event_dropped_size]
FROM    [sys].[dm_xe_sessions]
WHERE   [name] = 'spin_lock_backoff';

--Run this section to measure the contention
ALTER EVENT SESSION [spin_lock_backoff] ON SERVER STATE = START;

--wait to measure the number of backoffs over a 1 minute period
WAITFOR DELAY '00:01:00';

--To view the data
--1. Ensure the sqlservr.pdb is in the same directory as the sqlservr.exe
--2. Enable this trace flag to turn on symbol resolution
DBCC TRACEON(3656, -1);

--Get the callstacks from the bucketize target
SELECT  [xst].[event_session_address],
        [xst].[target_name],
        [xst].[execution_count],
        CAST([xst].[target_data] AS XML)
FROM    [sys].[dm_xe_session_targets]     AS [xst]
        INNER JOIN [sys].[dm_xe_sessions] AS [xs]
            ON ( [xst].[event_session_address] = [xs].[address] )
WHERE   [xs].[name] = 'spin_lock_backoff';

--clean up the session
ALTER EVENT SESSION [spin_lock_backoff] ON SERVER STATE = STOP;
DROP EVENT SESSION [spin_lock_backoff] ON SERVER;