USE [<DBNAME>]
GO

SELECT TOP ( 30 )
    bs.machine_name
  , bs.server_name
  , bs.database_name AS [Database Name]
  , bs.recovery_model
  , CONVERT (BIGINT, bs.backup_size / 1048576) AS [Uncompressed Backup Size (MB)]
  , CONVERT (BIGINT, bs.compressed_backup_size / 1048576) AS [Compressed Backup Size (MB)]
  , CONVERT (BIGINT, bs.backup_size / 1048576 / 1024.) AS [Uncompressed Backup Size (GB)]
  , CONVERT (BIGINT, bs.compressed_backup_size / 1048576 / 1024.) AS [Compressed Backup Size (GB)]
  , CONVERT (NUMERIC(20, 2), ( CONVERT (FLOAT, bs.backup_size) / CONVERT (FLOAT, bs.compressed_backup_size) )) AS [Compression Ratio]
  , DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) AS [Backup Elapsed Time (sec)]
  , DATEDIFF(MINUTE, bs.backup_start_date, bs.backup_finish_date) AS [Backup Elapsed Time (min)]
  , DATEDIFF(HOUR, bs.backup_start_date, bs.backup_finish_date) AS [Backup Elapsed Time (hr)]
  , bs.backup_finish_date AS [Backup Finish Date]
  , b.*
FROM
    msdb.dbo.backupset AS bs WITH ( NOLOCK )
	JOIN [msdb]..[backupmediafamily] AS [b]
		ON [b].[media_set_id] = [bs].[media_set_id]
WHERE
    DATEDIFF(SECOND, bs.backup_start_date, bs.backup_finish_date) > 0
    AND bs.backup_size > 0
    AND bs.type = 'D' -- Change to L if you want Log backups
    AND database_name = DB_NAME(DB_ID())
ORDER BY
    bs.backup_finish_date DESC
OPTION
    ( RECOMPILE );
