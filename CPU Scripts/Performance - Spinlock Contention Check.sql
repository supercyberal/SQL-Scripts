USE [tempdb];
GO
DECLARE @cntr INT = 0;
IF EXISTS (
    SELECT  [name]
    FROM    [tempdb].[sys].[sysobjects]
    WHERE   [name] LIKE '#_spin_waits%'
)
    DROP TABLE [#_spin_waits];


CREATE TABLE [#_spin_waits] (
    [lock_name]  VARCHAR(128),
    [collisions] BIGINT,
    [spins]      BIGINT,
    [sleep_time] BIGINT,
    [backoffs]   BIGINT,
    [snap_time]  DATETIME
);

WHILE ( @cntr < 6 )
BEGIN
    --capture the current stats
    INSERT INTO [#_spin_waits] (
        [lock_name],
        [collisions],
        [spins],
        [sleep_time],
        [backoffs],
        [snap_time]
    )
    SELECT  [name],
            [collisions],
            [spins],
            [sleep_time],
            [backoffs],
            GETDATE()
    FROM    [sys].[dm_os_spinlock_stats];

    WAITFOR DELAY '00:00:10';
    SET @cntr = @cntr + 1;
END;

--Analysis

DECLARE @cpu INT;
SELECT  @cpu = [cpu_count]
FROM    [sys].[dm_os_sys_info];

--SPINLOCKS compute delta 
SELECT      [t2].[lock_name]                                                                                                                               AS [spinlock_name],
            CAST(CAST([t2].[spins] AS FLOAT) - CAST([t1].[spins] AS FLOAT) AS BIGINT)                                                                      AS [delta_spins],
            CAST(CAST([t2].[backoffs] AS FLOAT) - CAST([t1].[backoffs] AS FLOAT) AS BIGINT)                                                                AS [delta_backoff],
            DATEDIFF( MILLISECOND, [t1].[snap_time], [t2].[snap_time] )                                                                                    AS [delta_minuntes],
            CAST(CAST([t2].[spins] AS FLOAT) - CAST([t1].[spins] AS FLOAT) AS BIGINT) / DATEDIFF( MILLISECOND, [t1].[snap_time], [t2].[snap_time] ) / @cpu AS [delta_spins_per_millisecond_per_CPU]
FROM        (
    SELECT  ROW_NUMBER() OVER ( PARTITION BY [lock_name] ORDER BY [snap_time] ) AS [row],
            [lock_name],
            [collisions],
            [spins],
            [sleep_time],
            [backoffs],
            [snap_time]
    FROM    [#_spin_waits]
    WHERE   [snap_time] IN (
                SELECT  MIN( [snap_time] )FROM  [#_spin_waits]
            )
)             AS [t1]
            JOIN (
                SELECT  ROW_NUMBER() OVER ( PARTITION BY [lock_name] ORDER BY [snap_time] ) AS [row],
                        [lock_name],
                        [collisions],
                        [spins],
                        [sleep_time],
                        [backoffs],
                        [snap_time]
                FROM    [#_spin_waits]
                WHERE   [snap_time] IN (
                            SELECT  MAX( [snap_time] )FROM  [#_spin_waits]
                        )
            ) AS [t2]
                ON [t1].[row] = [t2].[row]
                   AND [t1].[lock_name] = [t2].[lock_name]
WHERE       CAST(CAST([t2].[spins] AS FLOAT) - CAST([t1].[spins] AS FLOAT) AS BIGINT) > 0
ORDER BY    [delta_spins] DESC;