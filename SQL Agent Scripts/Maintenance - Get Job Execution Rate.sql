USE [msdb]
GO

DECLARE
	@siTopRecords SMALLINT = 15
	, @cJobName SYSNAME = 'DBA Maint - DatabaseBackup - USER_DATABASES - LOG'
	, @gdJobID UNIQUEIDENTIFIER;

;WITH cteGetJobHistory AS (
	SELECT
		[dbo].[agent_datetime]([h].[run_date],[h].[run_time]) AS JobTime
		, *
	FROM [dbo].[sysjobhistory] AS [h]
	WHERE EXISTS (
		SELECT 1 FROM [dbo].[sysjobs] AS [j]
		WHERE [j].[job_id] = [h].[job_id]
		AND [j].[name] = @cJobName
		AND [j].[enabled] = 1
	)	
	AND [h].[step_id] = 1
)
, cteGetLastResults AS (
	SELECT TOP (@siTopRecords)
		[cte].[JobTime]
		, (
			CASE [cte].[run_status]
				WHEN 0 THEN 'Failed'
				WHEN 1 THEN 'Success'
			END
		) AS Job_Result
		, [cte].[run_status]
	FROM cteGetJobHistory cte
	ORDER BY [cte].[JobTime] DESC
)
SELECT
	COUNT(1) AS Total_Job_Executions
	, CAST( ( SUM([cte].[run_status]) / CAST(@siTopRecords AS NUMERIC(10,2)) * 100 ) AS NUMERIC(10,2) ) AS [Success Rate (%)]
FROM [cteGetLastResults] cte


