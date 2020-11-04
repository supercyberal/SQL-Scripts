-- Query That Shows the Original and Current Size of all Files in Tempdb

SELECT  [alt].[filename]
       ,[alt].[name]
       ,[alt].[size] * 8.0 / 1024.0 AS [originalsize_MB]
       ,[files].[size] * 8.0 / 1024.0 AS [currentsize_MB]
FROM    [master].[sys].[sysaltfiles] [alt]
        INNER JOIN [tempdb].[sys].[sysfiles] [files] ON [alt].[fileid] = [files].[fileid]
WHERE   [alt].[dbid] = DB_ID('tempdb')
        AND [alt].[size] <> [files].[size];