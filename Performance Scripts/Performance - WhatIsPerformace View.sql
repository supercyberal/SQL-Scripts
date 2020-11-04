/*
Name:			master..vw_WhatIsPerformance
Description:	Responsible to return the most important SQL-Server perfom counters.
Author:			Ritesh Shah
URL:			http://blog.extreme-advice.com/2012/10/09/performance-counter-in-sql-server/
*/

USE master
GO

CREATE VIEW vw_WhatIsPerformance
AS
-- Given counter in this query are most important as per my opinion
-- so gave status "Important" and sort order 1.....

SELECT	'Important' AS CounterType ,
		1 AS SortOrder ,
		Object_Name AS CounterObject ,
		Counter_Name AS CounterName ,
		Cntr_Value AS CounterValue ,
		Instance_Name AS CounterInstanceName
FROM	sys.dm_os_performance_counters WITH ( NOLOCK )
WHERE	( ( [counter_name] IN ( 'active transactions',
								'Average Wait Time (ms)', 'errors/sec',
								'Lock Requests/sec', 'Lock Timeouts/sec',
								'Lock Waits/sec', 'Repl. Pending Xacts',
								'Transactions/sec' )
			AND instance_name = '_total'
		  )
		  OR [counter_name] IN ( 'User Connections', 'Number of Deadlocks/sec',
								 'Repl. Trans. Rate', 'Bytes Sent/sec',
								 'Bytes Received/sec', 'SQL SENDs/sec',
								 'SQL RECEIVEs/sec', 'Enqueued Messages/sec',
								 'Send I/Os/sec', 'Receive I/Os/sec',
								 'lock waits', 'Network IO waits',
								 'Active Temp Tables',
								 'Temp Tables Creation Rate', 'Logins/sec',
								 'Logouts/sec' )
		)
		AND cntr_value > 0

UNION ALL

-- important memory statistics
SELECT	'Memory Stat' AS CounterType ,
		2 AS SortOrder ,
		Object_Name AS CounterObject ,
		Counter_Name AS CounterName ,
		Cntr_Value AS CounterValue ,
		Instance_Name AS CounterInstanceName
FROM	sys.dm_os_performance_counters WITH ( NOLOCK )
WHERE	( [counter_name] = 'Connection Memory (KB)' )
		OR ( [counter_name] = 'Optimizer Memory (KB)' )
		OR ( [counter_name] = 'SQL Cache Memory (KB)' )
		OR ( [counter_name] = 'Granted Workspace Memory (KB)' )
		OR ( [counter_name] = 'Maximum Workspace Memory (KB)' )
		OR ( [counter_name] = 'Memory Grants Outstanding' )
		OR ( [counter_name] = 'Memory Grants Pending' )
		OR ( [counter_name] = 'Lock Memory (KB)' )
		OR ( [counter_name] = 'Lock Blocks Allocated' )
		OR ( [counter_name] = 'Lock Owner Blocks Allocated' )
		OR ( [counter_name] = 'Lock Blocks' )
		OR ( [counter_name] = 'Lock Owner Blocks' )

UNION ALL

-- buffer statistics
SELECT	'Buffer Stat' AS CounterType ,
		3 AS SortOrder ,
		Object_Name AS CounterObject ,
		Counter_Name AS CounterName ,
		Cntr_Value AS CounterValue ,
		Instance_Name AS CounterInstanceName
FROM	sys.dm_os_performance_counters WITH ( NOLOCK )
WHERE	( [counter_name] = 'Buffer cache hit ratio' )
		OR ( [counter_name] = 'Buffer cache hit ratio base' )
		OR ( [counter_name] = 'Page lookups/sec' )
		OR ( [counter_name] = 'Readahead pages/sec' )
		OR ( [counter_name] = 'Page reads/sec' )
		OR ( [counter_name] = 'Page writes/sec' )
		OR ( [counter_name] = 'Page life expectancy' )

UNION ALL

-- total lock statistics
SELECT	'Lock Stat' AS CounterType ,
		4 AS SortOrder ,
		Object_Name AS CounterObject ,
		Counter_Name AS CounterName ,
		Cntr_Value AS CounterValue ,
		Instance_Name AS CounterInstanceName
FROM	sys.dm_os_performance_counters WITH ( NOLOCK )
WHERE	( [counter_name] = 'Lock Requests/sec'
		  AND [instance_name] = '_Total'
		)
		OR ( [counter_name] = 'Lock Timeouts/sec'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Number of Deadlocks/sec'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Lock Waits/sec'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Lock Wait Time (ms)'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Average Wait Time (ms)'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Average Wait Time Base'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Lock Timeouts (timeout > 0)/sec'
			 AND [instance_name] = '_Total'
		   )

UNION ALL

-- compilation and cache stat
SELECT	'Compilation and Cache Stat' AS CounterType ,
		5 AS SortOrder ,
		Object_Name AS CounterObject ,
		Counter_Name AS CounterName ,
		Cntr_Value AS CounterValue ,
		Instance_Name AS CounterInstanceName
FROM	sys.dm_os_performance_counters WITH ( NOLOCK )
WHERE	( [counter_name] = 'Cache Hit Ratio'
		  AND [instance_name] = '_Total'
		)
		OR ( [counter_name] = 'Cache Hit Ratio Base'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Cache Pages'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Cache Object Counts'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'Cache Objects in use'
			 AND [instance_name] = '_Total'
		   )
		OR ( [counter_name] = 'SQL Compilations/sec' )
		OR ( [counter_name] = 'SQL Re-Compilations/sec' );
GO


