/***********************************************************************************************************************************************
Measure CPU's Context Switching.
***********************************************************************************************************************************************/
USE [master]
GO

DECLARE @iNumberSecsToCheck INT = 5;	

DECLARE @tmp TABLE
(
    [cpu_id] INT,
    [context_switches_count] INT
);

INSERT @tmp
(
    [cpu_id],
    [context_switches_count]
)
SELECT  [cpu_id],
        -SUM([context_switches_count]) [context_switches_count]
FROM    [sys].[dm_os_schedulers]
GROUP BY [cpu_id];

WAITFOR DELAY '00:00:';

INSERT @tmp
(
    [cpu_id],
    [context_switches_count]
)
SELECT  [cpu_id],
        SUM([context_switches_count])
FROM    [sys].[dm_os_schedulers]
GROUP BY [cpu_id];

SELECT  (
			CASE WHEN GROUPING([cpu_id]) = 1 THEN 
				'SUM ALL Cores'
			ELSE 
				CAST([cpu_id] AS VARCHAR(4))
			END 
		) AS [CoreID]
        , SUM([context_switches_count]) [context_switches_count]
FROM    @tmp
GROUP BY 
	[cpu_id]
    WITH ROLLUP;
