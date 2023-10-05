/*
Author:Brahmanand Shukla
Date:28-Oct-2019
Purpose:T-SQL query to get the latest available backup chain
*/
DECLARE 
	@server_name VARCHAR(50) = 'ALL'
	, @database_name VARCHAR(50) = 'ALL'
	, @cSQLStmt nvarchar(max) = '';

-- Uncomment the below section and supply your <server name> if you want to fetch the report for specific server
--SET @server_name='sql_server_1'

-- Uncomment the below section and supply your <database name> if you want to fetch the report for specific database
--SET @database_name='sql_database_1'

;
WITH cte_Backup
AS (SELECT backupset.server_name,
           backupset.database_name,
           backupset.backup_start_date,
           backupset.backup_finish_date,
           CASE backupset.type
               WHEN 'D' THEN
                   'Full'
               WHEN 'I' THEN
                   'Differential'
               WHEN 'L' THEN
                   'Log'
           END AS [backup_type],
           CAST(((backupset.backup_size / 1024) / 1024) AS NUMERIC(18, 2)) AS [Backup_size_MB],
           CAST(((backupset.compressed_backup_size / 1024) / 1024) AS NUMERIC(18, 2)) AS [Compressed_Backup_size_MB],
           DATEDIFF(SECOND, backupset.backup_start_date, backupset.backup_finish_date) AS [Duration_Seconds],
           backupset.database_creation_date,
           backupset.recovery_model,
           backupmediafamily.physical_device_name,
           backupset.[user_name],
           backupset.[backup_set_uuid],
           backupset.[database_backup_lsn],
           backupset.[differential_base_guid],
           ROW_NUMBER() OVER (PARTITION BY backupset.server_name,
                                           backupset.database_name,
                                           backupset.type
                              ORDER BY backupset.backup_finish_date DESC
                             ) AS [RowID],
           CASE backupset.type
               WHEN 'D' THEN
                   1
               WHEN 'I' THEN
                   2
               WHEN 'L' THEN
                   3
           END AS [backup_type_sort_order]
    FROM msdb.dbo.backupmediafamily backupmediafamily
        INNER JOIN msdb.dbo.backupset backupset
            ON backupmediafamily.media_set_id = backupset.media_set_id
    WHERE (
              @server_name = 'ALL'
              OR backupset.server_name = @server_name
          )
          AND
          (
              @database_name = 'ALL'
              OR backupset.database_name = @database_name
          )),
     cte_Backup_Full
AS (SELECT *
    FROM cte_Backup
    WHERE [backup_type] = 'Full'
          AND [RowID] = 1),
     cte_Backup_Differential
AS (SELECT DIF.[server_name],
           DIF.[database_name],
           DIF.[backup_start_date],
           DIF.[backup_finish_date],
           DIF.[backup_type],
           DIF.[Backup_size_MB],
           DIF.[Compressed_Backup_size_MB],
           DIF.[Duration_Seconds],
           DIF.[database_creation_date],
           DIF.[recovery_model],
           DIF.[physical_device_name],
           DIF.[user_name],
           DIF.[backup_type_sort_order],
           DIF.[database_backup_lsn],
           ROW_NUMBER() OVER (PARTITION BY DIF.[server_name],
                                           DIF.[database_name],
                                           DIF.[differential_base_guid]
                              ORDER BY DIF.[backup_finish_date] DESC
                             ) AS [RowID]
    FROM cte_Backup DIF
        INNER JOIN cte_Backup_Full FUL
            ON FUL.[server_name] = DIF.[server_name]
               AND FUL.[database_name] = DIF.[database_name]
               AND FUL.[backup_set_uuid] = DIF.[differential_base_guid]
    WHERE DIF.[backup_type] = 'Differential'
          AND DIF.[backup_finish_date] > FUL.[backup_finish_date]),
     cte_Backup_Log
AS (SELECT AL.*
    FROM cte_Backup AL
        INNER JOIN cte_Backup_Differential DIF
            ON DIF.[server_name] = AL.[server_name]
               AND DIF.[database_name] = AL.[database_name]
               AND DIF.[database_backup_lsn] = AL.[database_backup_lsn]
    WHERE DIF.[RowID] = 1
          AND AL.[backup_type] = 'Log'
          AND AL.[backup_finish_date] > DIF.[backup_finish_date]),
     cte_Backup_Chain
AS (SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order]
    FROM cte_Backup_Full
    UNION ALL
    SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order]
    FROM cte_Backup_Differential
    WHERE [RowID] = 1
    UNION ALL
    SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order]
    FROM cte_Backup_Log),
     cte_Backup_Full_All_DB
AS (SELECT [server_name],
           'ALL_FULL' AS [database_name],
           NULL AS [backup_start_date],
           NULL AS [backup_finish_date],
           NULL AS [backup_type],
           SUM([Backup_size_MB]) AS [Backup_size_MB],
           SUM([Compressed_Backup_size_MB]) AS [Compressed_Backup_size_MB],
           SUM([Duration_Seconds]) AS [Duration_Seconds],
           NULL AS [database_creation_date],
           NULL AS [recovery_model],
           NULL AS [physical_device_name],
           NULL AS [user_name],
           0 AS [backup_type_sort_order]
    FROM cte_Backup_Chain
    WHERE [backup_type] = 'Full'
    GROUP BY [server_name]),
     cte_Backup_Differential_All_DB
AS (SELECT [server_name],
           'ALL_DIFF' AS [database_name],
           NULL AS [backup_start_date],
           NULL AS [backup_finish_date],
           NULL AS [backup_type],
           SUM([Backup_size_MB]) AS [Backup_size_MB],
           SUM([Compressed_Backup_size_MB]) AS [Compressed_Backup_size_MB],
           SUM([Duration_Seconds]) AS [Duration_Seconds],
           NULL AS [database_creation_date],
           NULL AS [recovery_model],
           NULL AS [physical_device_name],
           NULL AS [user_name],
           0 AS [backup_type_sort_order]
    FROM cte_Backup_Chain
    WHERE [backup_type] = 'Differential'
    GROUP BY [server_name]),
     cte_Backup_Log_All_DB
AS (SELECT [server_name],
           'ALL_LOG' AS [database_name],
           NULL AS [backup_start_date],
           NULL AS [backup_finish_date],
           NULL AS [backup_type],
           SUM([Backup_size_MB]) AS [Backup_size_MB],
           SUM([Compressed_Backup_size_MB]) AS [Compressed_Backup_size_MB],
           SUM([Duration_Seconds]) AS [Duration_Seconds],
           NULL AS [database_creation_date],
           NULL AS [recovery_model],
           NULL AS [physical_device_name],
           NULL AS [user_name],
           0 AS [backup_type_sort_order]
    FROM cte_Backup_Chain
    WHERE [backup_type] = 'Log'
    GROUP BY [server_name]),
     cte_Backup_Full_Differential_Log_All_DB
AS (SELECT [server_name],
           'FULL+DIFF+LOG' AS [database_name],
           NULL AS [backup_start_date],
           NULL AS [backup_finish_date],
           NULL AS [backup_type],
           SUM([Backup_size_MB]) AS [Backup_size_MB],
           SUM([Compressed_Backup_size_MB]) AS [Compressed_Backup_size_MB],
           SUM([Duration_Seconds]) AS [Duration_Seconds],
           NULL AS [database_creation_date],
           NULL AS [recovery_model],
           NULL AS [physical_device_name],
           NULL AS [user_name],
           0 AS [backup_type_sort_order]
    FROM cte_Backup_Chain
    GROUP BY [server_name]),
     cte_Final_Output_Staging
AS (SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order],
           1 AS [sort_priority]
    FROM cte_Backup_Full_All_DB
    UNION ALL
    SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order],
           2 AS [sort_priority]
    FROM cte_Backup_Differential_All_DB
    UNION ALL
    SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order],
           3 AS [sort_priority]
    FROM cte_Backup_Log_All_DB
    UNION ALL
    SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order],
           4 AS [sort_priority]
    FROM cte_Backup_Full_Differential_Log_All_DB
    UNION ALL
    SELECT [server_name],
           [database_name],
           [backup_start_date],
           [backup_finish_date],
           [backup_type],
           [Backup_size_MB],
           [Compressed_Backup_size_MB],
           [Duration_Seconds],
           [database_creation_date],
           [recovery_model],
           [physical_device_name],
           [user_name],
           [backup_type_sort_order],
           (4 + [backup_type_sort_order]) AS [sort_priority]
    FROM cte_Backup_Chain)
SELECT [server_name],
       [database_name],
       [backup_start_date],
       [backup_finish_date],
       [backup_type],
       [Backup_size_MB],
       [Compressed_Backup_size_MB],
       [Duration_Seconds],
       [database_creation_date],
       [recovery_model],
       [physical_device_name],
       [user_name]
FROM cte_Final_Output_Staging
ORDER BY ROW_NUMBER() OVER (ORDER BY [sort_priority] ASC,
                                     [database_name] ASC,
                                     [backup_type_sort_order] ASC,
                                     [backup_finish_date] ASC
                           )

-- More additional info.
IF @database_name = 'ALL'
BEGIN
	SET @cSQLStmt = N'SELECT TOP 100 * FROM msdb.dbo.backupset a WITH (nolock) JOIN msdb.dbo.backupmediafamily b WITH (nolock) ON a.media_set_id = b.media_set_id ORDER BY a.database_name DESC, a.backup_finish_date DESC;';
	EXEC sp_executesql @cSQLStmt;
END
ELSE
BEGIN
	SET @cSQLStmt = N'SELECT TOP 500 * FROM msdb.dbo.backupset a WITH (nolock) JOIN msdb.dbo.backupmediafamily b WITH (nolock) ON a.media_set_id = b.media_set_id WHERE a.[database_name] = @cDB ORDER BY a.database_name DESC, a.backup_finish_date DESC;';
	EXEC sp_executesql @cSQLStmt, N'@cDB SYSNAME', @cDB = @database_name;
END

/*
SELECT *
FROM msdb.dbo.backupset a WITH (nolock)
    INNER JOIN msdb.dbo.backupmediafamily b WITH (nolock)
        ON a.media_set_id = b.media_set_id
WHERE (
          @database_name = 'ALL'
          OR a.[database_name] = @database_name
      )
ORDER BY a.database_name DESC,
         a.backup_finish_date DESC
*/
