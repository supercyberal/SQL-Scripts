/*
Name:	Signal Wait Time
Source: Pinal Dave
URL:	http://blog.sqlauthority.com/2011/02/02/sql-server-signal-wait-time-introduction-with-simple-example-day-2-of-28/
*/

-- Signal Waits for instance
SELECT  
	CAST(100.0 * SUM(signal_wait_time_ms) / SUM(wait_time_ms) AS NUMERIC(20,2)) AS [%signal (cpu) waits]
	, CAST(100.0 * SUM(wait_time_ms - signal_wait_time_ms) / SUM(wait_time_ms) AS NUMERIC(20, 2)) AS [%resource waits]
FROM    sys.dm_os_wait_stats
OPTION  ( RECOMPILE );