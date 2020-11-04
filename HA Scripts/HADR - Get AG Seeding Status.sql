-- Check VDI Status
SELECT
	[r].[session_id]
	, [r].[status]
	, [r].[command]
	, [r].[wait_type]
	, [r].[percent_complete]
	, [r].[estimated_completion_time]
	, CAST(( [r].[estimated_completion_time] / 1000. / 60. ) AS DECIMAL(10,2)) AS Estimated_Time_Minutes
FROM [sys].[dm_exec_requests] AS [r]
    JOIN [sys].[dm_exec_sessions] AS [s]
        ON [r].[session_id] = [s].[session_id]
WHERE [r].[session_id] <> @@SPID
      AND [s].[is_user_process] = 0
      AND [r].[command] LIKE 'VDI%';
GO

-- Check physical seeding
SELECT * FROM sys.[dm_hadr_physical_seeding_stats] AS [dhpss]
GO

-- Check logical seeding
SELECT * FROM [sys].[dm_hadr_automatic_seeding] AS [dhas]
GO

-- Check AG Stats
SELECT 
	[ag].[name]
	, DB_NAME([dhdrs].[database_id]) AS DBName
	, [dhdrs].*
	, ( [dhdrs].[secondary_lag_seconds] / 60. ) AS RTO_Mins
	, ( [dhdrs].[secondary_lag_seconds] / 60. / 60. ) AS RTO_Hours
FROM [sys].[dm_hadr_database_replica_states] AS [dhdrs]
JOIN [sys].[availability_groups] AS [ag]
	ON [ag].[group_id] = [dhdrs].[group_id]
ORDER BY 
	[ag].[name]
	, DB_NAME([dhdrs].[database_id])
GO

/*

-- Stop seeding.
ALTER AVAILABILITY GROUP [<availability_group_name>] 
    MODIFY REPLICA ON '<secondary_node>'   
    WITH (SEEDING_MODE = MANUAL)
GO

-- Restart seeding.
ALTER AVAILABILITY GROUP [<availability_group_name>] 
    MODIFY REPLICA ON '<secondary_node>'   
    WITH (SEEDING_MODE = AUTOMATIC)
GO

*/