/***********************************************************************************************************************************************
Description:	Get number of minutes spent running backups. This is only for used when using OLA HALLENGREN backup solution.

Notes:			ACOSTA - 2016-09-21
				Created.
***********************************************************************************************************************************************/

USE [master]
GO

;WITH cteResults AS (
	SELECT
		*
		, CAST([cl].[StartTime] AS DATE) AS [Date]
		, DATEDIFF(SECOND,[cl].[StartTime],[cl].[EndTime]) AS TimeDiff
	FROM [dbo].[CommandLog] AS [cl]
	WHERE [cl].[CommandType] = 'BACKUP_DATABASE'
)
SELECT
	[cte].[Date]
	, [cte].[DatabaseName]
	, DATENAME(dw,[cte].[Date]) AS [Day Of Week]
	, DATENAME(MONTH,[cte].[Date]) AS [Month]
	, DATENAME(DAY,[cte].[Date]) AS [Day]
	, COUNT(1) AS [Number Backups]
	, (
		CASE WHEN [cte].[TimeDiff] > 60 THEN
			CAST(ROUND( SUM([cte].[TimeDiff]) / 60., 0 ) AS INT)
		ELSE
			SUM([cte].[TimeDiff])
		END	
	) AS TimeTaken
	, (
		CASE WHEN [cte].[TimeDiff] > 60 THEN
			' Min(s)'
		ELSE
			' Sec(s)'
		END	
	) AS TimeMeasurement
	--, CAST(ROUND( SUM([cte].[TimeDiff]) / 60., 0 ) AS INT) AS [Total Time (Minues)]
	--, SUM([cte].[TimeDiff]) AS [Total Time (Seconds)]
FROM [cteResults] cte
GROUP BY [cte].[Date], [cte].[DatabaseName], [cte].[TimeDiff]
ORDER BY [cte].[Date] DESC
GO
