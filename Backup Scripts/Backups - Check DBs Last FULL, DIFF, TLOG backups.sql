SELECT DISTINCT
       [a].[name] AS [DatabaseName],
       CONVERT(sysname, DATABASEPROPERTYEX([a].[name], 'Recovery')) AS [RecoveryModel],
       COALESCE(
       (
           SELECT CONVERT(VARCHAR(12), MAX([backup_finish_date]), 101)
           FROM [msdb].[dbo].[backupset]
           WHERE [database_name] = [a].[name]
                 AND [type] = 'D'
                 AND [is_copy_only] = '0'
       ),
       'No Full'
               ) AS [Full],
       COALESCE(
       (
           SELECT CONVERT(VARCHAR(12), MAX([backup_finish_date]), 101)
           FROM [msdb].[dbo].[backupset]
           WHERE [database_name] = [a].[name]
                 AND [type] = 'I'
                 AND [is_copy_only] = '0'
       ),
       'No Diff'
               ) AS [Diff],
       COALESCE(
       (
           SELECT CONVERT(VARCHAR(20), MAX([backup_finish_date]), 120)
           FROM [msdb].[dbo].[backupset]
           WHERE [database_name] = [a].[name]
                 AND [type] = 'L'
       ),
       'No Log'
               ) AS [LastLog],
       COALESCE(
       (
           SELECT CONVERT(VARCHAR(20), [withrownum].[backup_finish_date], 120)
           FROM
           (
               SELECT ROW_NUMBER() OVER (ORDER BY [backup_finish_date] DESC) AS [rownum],
                      [backup_finish_date]
               FROM [msdb].[dbo].[backupset]
               WHERE [database_name] = [a].[name]
                     AND [type] = 'L'
           ) AS [withrownum]
           WHERE [withrownum].[rownum] = 2
       ),
       'No Log'
               ) AS [LastLog2]
FROM [sys].[databases] AS [a]
    LEFT OUTER JOIN [msdb].[dbo].[backupset] AS [b]
        ON [b].[database_name] = [a].[name]
WHERE [a].[name] <> 'tempdb'
      AND [a].[state_desc] = 'online'
GROUP BY [a].[name],
         [a].[compatibility_level]
ORDER BY [a].[name];