----------------------------------------------------------------------------------------------------------------------------------------------
-- Get performance counters info.

----------------------------------------------------------------------------------------------------------------------------------------------
-- Page Life Expectancy

SELECT  [object_name]
      , [counter_name]
      , [cntr_value] AS Time_In_Seconds
      , ( [cntr_value] / 60 ) AS Time_In_Minutes
      , ( ( [cntr_value] / 60 ) / 60 ) AS Time_In_Hours
FROM    sys.dm_os_performance_counters
WHERE   [object_name] LIKE '%Manager%'
        AND [counter_name] = 'Page life expectancy'

----------------------------------------------------------------------------------------------------------------------------------------------
-- DB Mirroring Queues

SELECT * FROM sys.dm_os_performance_counters dopc
WHERE object_name LIKE '%Mirror%'
AND (
	counter_name LIKE '%Queue%'
	--OR counter_name LIKE '%Queue%'
)
AND instance_name = 'EIS_Test'
ORDER BY counter_name