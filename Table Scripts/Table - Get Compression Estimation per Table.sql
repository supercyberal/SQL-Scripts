/*
Name:	Get compression estimation for tables.
Date:	2013-04-16
*/

SET NOCOUNT ON;
 
DECLARE @printOnly  BIT = 0 -- change to 1 if you don't want to execute, just print commands
    , @tableName    VARCHAR(256)
    , @schemaName   VARCHAR(100)
    , @sqlStatement NVARCHAR(1000)
    , @tableCount   INT
    , @statusMsg    VARCHAR(1000);
 
IF EXISTS(SELECT * FROM tempdb.sys.tables WHERE name LIKE '%#tables%')
    DROP TABLE #tables; 
 
CREATE TABLE #tables
(
      database_name     sysname
    , schemaName        sysname NULL
    , tableName         sysname NULL
    , processed         bit
);
 
IF EXISTS(SELECT * FROM tempdb.sys.tables WHERE name LIKE '%#compression%')
    DROP TABLE #compressionResults;
 
IF NOT EXISTS(SELECT * FROM tempdb.sys.tables WHERE name LIKE '%#compression%')
BEGIN 
 
    CREATE TABLE #compressionResults
    (
          objectName                    varchar(100)
        , schemaName                    varchar(50)
        , index_id                      int
        , partition_number              int
        , size_current_compression      bigint
        , size_requested_compression    bigint
        , sample_current_compression    bigint
        , sample_requested_compression  bigint
    );
 
END;
 
INSERT INTO #tables
SELECT DB_NAME()
    , SCHEMA_NAME([t].[schema_id])
    , [t].[name]
    , 0 -- unprocessed
FROM [sys].[tables] AS [t]
WHERE [t].[name] LIKE 'FactTransactionDetail%'
 
SELECT @tableCount = COUNT(*) FROM #tables;
 
WHILE EXISTS(SELECT * FROM #tables WHERE processed = 0)
BEGIN
 
    SELECT TOP 1 @tableName = tableName
        , @schemaName = schemaName
    FROM #tables WHERE processed = 0;
 
    SELECT @statusMsg = 'Working on ' + CAST(((@tableCount - COUNT(*)) + 1) AS VARCHAR(10)) 
        + ' of ' + CAST(@tableCount AS VARCHAR(10))
    FROM #tables
    WHERE processed = 0;
 
    RAISERROR(@statusMsg, 0, 42) WITH NOWAIT;
 
    SET @sqlStatement = 'EXECUTE sp_estimate_data_compression_savings ''' 
                        + @schemaName + ''', ''' + @tableName + ''', NULL, NULL, ''PAGE'';' -- ROW, PAGE, or NONE
 
    IF @printOnly = 1
    BEGIN 
 
        SELECT @sqlStatement;
 
    END
    ELSE
    BEGIN
 
        INSERT INTO #compressionResults
        EXECUTE sp_executesql @sqlStatement;
 
    END;
 
    UPDATE #tables
    SET processed = 1
    WHERE tableName = @tableName
        AND schemaName = @schemaName;
 
END;

SELECT [a].[objectName],
       [a].[schemaName],
       [i].[name] AS [Index_Name],
       [a].[partition_number],
       CAST(([a].[size_current_compression] / 1024.0) AS DECIMAL(10, 2)) AS [size_current_compression_MB],
       CAST(([a].[size_requested_compression] / 1024.0) AS DECIMAL(10, 2)) AS [size_requested_compression_MB],
       [a].[sample_current_compression],
       [a].[sample_requested_compression],
       [a].[size_diff_KB],
       CAST(([a].[size_diff_KB] / 1024.) AS DECIMAL(10, 2)) AS [size_diff_MB]
FROM
(
    SELECT [objectName],
           [schemaName],
           [index_id],
           [partition_number],
           [size_current_compression],
           [size_requested_compression],
           [sample_current_compression],
           [sample_requested_compression],
           ([size_current_compression] - [size_requested_compression]) AS [size_diff_KB]
    FROM [#compressionResults]
) AS [a]
    JOIN [sys].[indexes] AS [i]
        ON [i].[index_id] = [a].[index_id]
		AND [i].[object_id] = OBJECT_ID([a].[objectName])
ORDER BY 	
	[a].[size_diff_KB] DESC,
	[a].[objectName];