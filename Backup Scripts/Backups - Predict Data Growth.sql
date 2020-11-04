USE [msdb]
GO

;WITH cteResults AS (
    SELECT
	   [database_name] AS [Database]
	   , DATEPART(mm,[backup_start_date]) AS [Month]
	   , DATEPART(yyyy,[backup_start_date]) AS [Year]
	   , CAST( (AVG([backup_size]/1024./1024.)) AS DECIMAL(10,2) ) AS [AVG Backup Size MB]    

	   /* Only Available in 2008R2+ */
	   --, AVG([compressed_backup_size]/1024/1024) AS "Compressed Backup Size MB"
	   --, AVG([backup_size]/[compressed_backup_size]) AS "Compression Ratio"
    FROM msdb.dbo.backupset
    WHERE [type] = 'D'
    GROUP BY 
	   [database_name]
	   , DATEPART(mm,[backup_start_date])
	   , DATEPART(yyyy,[backup_start_date])
)
SELECT
    [Database]
    , [Month]
    , [Year]
    , [AVG Backup Size MB]

    /* Only Available in 2008R2+ */
    --, [Compressed Backup Size MB]
    --, [Compression Ratio]
FROM cteResults cte

--WHERE [Database] = <YOUR_DB_NAME>
--AND [Year] = <YEAR>
--AND [Month] = <MONTH>

ORDER BY 
    [Database]
    , [Year]
    , [Month];
    
    