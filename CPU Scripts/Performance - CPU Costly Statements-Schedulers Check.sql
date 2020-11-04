/*
Name:				Get CPU consuming statements
Date:				2013-04-23
Related Articles:	http://blog.sqlauthority.com/2009/08/17/sql-server-measure-cpu-pressure-cpu-business/
					http://blog.sqlauthority.com/2011/02/08/sql-server-sos_scheduler_yield-wait-type-day-8-of-28/
*/

-- Get TOP 20 most CPU expensive queries.
SELECT TOP 20
		SUBSTRING(qt.TEXT, ( qs.statement_start_offset / 2 ) + 1,
				  ( ( CASE qs.statement_end_offset
						WHEN -1 THEN DATALENGTH(qt.TEXT)
						ELSE qs.statement_end_offset
					  END - qs.statement_start_offset ) / 2 ) + 1) ,
		qs.execution_count ,
		qs.total_logical_reads ,
		qs.last_logical_reads ,
		qs.total_logical_writes ,
		qs.last_logical_writes ,
		qs.total_worker_time ,
		qs.last_worker_time ,
		qs.total_elapsed_time / 1000000 total_elapsed_time_in_S ,
		qs.last_elapsed_time / 1000000 last_elapsed_time_in_S ,
		qs.last_execution_time ,
		qp.query_plan
FROM	sys.dm_exec_query_stats qs
		CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
		CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
ORDER BY qs.total_worker_time DESC -- CPU time
GO

-- Get AVG amounts for CPU statements.
SELECT TOP 20 query_stats.query_hash AS "Query Hash", 
    SUM(query_stats.total_worker_time) / SUM(query_stats.execution_count) AS "Avg CPU Time",
    MIN(query_stats.statement_text) AS "Statement Text"
FROM 
    (SELECT QS.*, 
    SUBSTRING(ST.text, (QS.statement_start_offset/2) + 1,
    ((CASE statement_end_offset 
        WHEN -1 THEN DATALENGTH(ST.text)
        ELSE QS.statement_end_offset END 
            - QS.statement_start_offset)/2) + 1) AS statement_text
     FROM sys.dm_exec_query_stats AS QS
     CROSS APPLY sys.dm_exec_sql_text(QS.sql_handle) as ST) as query_stats
GROUP BY query_stats.query_hash
ORDER BY 2 DESC;
GO

-- Get tasks counts from the schedulers.
/*
current_tasks_count:	Number of counts of the currently running task.
runnable_tasks_count:	Number of queries, which are assigned to the scheduler for processing, are waiting for its turn to run.
						If this number is high (2 digits) constantly, then it could be a sign of CPU preassure.
*/
SELECT
	scheduler_id,
	cpu_id,
	current_tasks_count,
	runnable_tasks_count,
	current_workers_count,
	active_workers_count,
	work_queue_count,
	pending_disk_io_count
FROM sys.dm_os_schedulers
WHERE scheduler_id < 255;

