DECLARE
	@timeGrain INT
	, @startTime DATETIME
	, @endTime DATETIME

SELECT      (( CONVERT( BIGINT, DATEDIFF( DAY, 0, [end_time] )) * 24 * 3600 + DATEDIFF( SECOND, DATEADD( DAY, DATEDIFF( DAY, 0, [end_time] ), 0 ), [end_time] )) / @timeGrain ) * @timeGrain AS [start_time_interval],
            MAX( [t].[cpu_percent] )                                                                                                                                                         AS [cpu_percent],
            MAX( [t].[physical_data_read_percent] )                                                                                                                                          AS [physical_data_read_percent],
            MAX( [t].[log_write_percent] )                                                                                                                                                   AS [log_write_percent],
            MAX( [t].[memory_usage_percent] )                                                                                                                                                AS [memory_usage_percent],
            MAX( [t].[xtp_storage_percent] )                                                                                                                                                 AS [xtp_storage_percent],
            MAX( [t].[dtu_consumption_percent] )                                                                                                                                             AS [dtu_consumption_percent],
            MAX( [t].[workers_percent] )                                                                                                                                                     AS [workers_percent],
            MAX( [t].[sessions_percent] )                                                                                                                                                    AS [sessions_percent],
            MAX( [t].[dtu_limit] )                                                                                                                                                           AS [dtu_limit],
            MAX( [t].[dtu_used] )                                                                                                                                                            AS [dtu_used]
FROM        (
    SELECT  [end_time],
            ISNULL( [avg_cpu_percent], 0 )          AS [cpu_percent],
            ISNULL( [avg_data_io_percent], 0 )      AS [physical_data_read_percent],
            ISNULL( [avg_log_write_percent], 0 )    AS [log_write_percent],
            ISNULL( [avg_memory_usage_percent], 0 ) AS [memory_usage_percent],
            ISNULL( [xtp_storage_percent], 0 )      AS [xtp_storage_percent],
            ISNULL((
                       SELECT   MAX( [value].[v] )
                       FROM     (
                           VALUES ( [avg_cpu_percent] ),
                                  ( [avg_data_io_percent] ),
                                  ( [avg_log_write_percent] )
                       ) AS [value] ( [v] )
                   ),
                   0
            )                                       AS [dtu_consumption_percent],
            ISNULL( [max_worker_percent], 0 )       AS [workers_percent],
            ISNULL( [max_session_percent], 0 )      AS [sessions_percent],
            ISNULL( [dtu_limit], 0 )                AS [dtu_limit],
            ISNULL( [dtu_limit], 0 ) * ISNULL((
                                                  SELECT    MAX( [value].[v] )
                                                  FROM      (
                                                      VALUES ( [avg_cpu_percent] ),
                                                             ( [avg_data_io_percent] ),
                                                             ( [avg_log_write_percent] )
                                                  ) AS [value] ( [v] )
                                              ),
                                              0
                                       ) / 100.0    AS [dtu_used]
    FROM    [sys].[dm_db_resource_stats]
    WHERE   [end_time] >= @startTime
            AND [end_time] <= @endTime
) AS [t]
GROUP BY    (( CONVERT( BIGINT, DATEDIFF( DAY, 0, [end_time] )) * 24 * 3600 + DATEDIFF( SECOND, DATEADD( DAY, DATEDIFF( DAY, 0, [end_time] ), 0 ), [end_time] )) / @timeGrain ) * @timeGrain;
GO