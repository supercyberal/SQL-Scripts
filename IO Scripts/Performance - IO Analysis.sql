-- Create a temp table to start the analysis.
IF OBJECT_ID('TempDB..#ReadWriteTemp') IS NULL
	SELECT
		[divfs].[database_id] 
		, [divfs].[file_id] 
		, [divfs].[sample_ms] 
		, [divfs].[num_of_reads] 
		, [divfs].[num_of_bytes_read] 
		, [divfs].[io_stall_read_ms] 
		, [divfs].[num_of_writes] 
		, [divfs].[num_of_bytes_written] 
		, [divfs].[io_stall_write_ms]
		, [divfs].[io_stall] 
		, [divfs].[size_on_disk_bytes] 
		, [divfs].[file_handle]
	INTO #ReadWriteTemp
	FROM [sys].[dm_io_virtual_file_stats](NULL, NULL) AS divfs
go  

--------------------------------------------------------------------------------------------------------------------------------------  
-- Analyse IO 

SELECT	
	DB_NAME([divfs].[database_id]) AS [database] 
	, [mf].[type_desc] AS [file type]
	, (
		CASE [mf].[type_desc] 
			WHEN 'ROWS' THEN 'Data File'
			WHEN 'LOG' THEN 'Log File'
		ELSE
			'N/A'      
		END
	) AS [file type desc]
	, mf.[name] AS [file name] 
	, CONVERT(DECIMAL(16, 3), CONVERT(BIGINT, [mf].[size]) / 128.0) AS [size_mb] 
	, CONVERT(DECIMAL(10, 2), ( [divfs].[sample_ms] - [t].[sample_ms] ) / 1000.0) AS [elapsed time s] 
	, [divfs].[num_of_reads] - [t].[num_of_reads] AS [reads] 
	, [divfs].[num_of_bytes_read] - [t].[num_of_bytes_read] AS [bytes read] 
	, [divfs].[io_stall_read_ms] - [t].[io_stall_read_ms] AS [stall read] 
	, (
		CASE WHEN ([divfs].[io_stall_read_ms] - [t].[io_stall_read_ms]) - ( [divfs].[io_stall_write_ms]- [t].[io_stall_write_ms] ) > 0 THEN 
			'<< Read Bias'
		WHEN ([divfs].[io_stall_read_ms] - [t].[io_stall_read_ms]) - ( [divfs].[io_stall_write_ms] - [t].[io_stall_write_ms]) < 0 
			THEN 'Write Bias >>'
		ELSE 
			'<Balanced>'
		END 
	) AS [Stall Balance]
	, (
		CASE WHEN ([divfs].[num_of_bytes_read] - [t].[num_of_bytes_read]) - ([divfs].[num_of_bytes_written] - [t].[num_of_bytes_written]) > 0 THEN 
			'<< Read Bias'
		WHEN ([divfs].[num_of_bytes_read] - [t].[num_of_bytes_read]) - ([divfs].[num_of_bytes_written] - [t].[num_of_bytes_written]) < 0 THEN 
			'Write Bias >>'
		ELSE 
			'<Balanced>'
		END 
	) AS [Read/Write Balance] 
	, [divfs].[num_of_writes] - [t].[num_of_writes] AS [writes] 
	, [divfs].[num_of_bytes_written] - [t].[num_of_bytes_written] AS [bytes write] 
	, [divfs].[io_stall_write_ms] - [t].[io_stall_write_ms] AS [stall write] 
	, [divfs].[io_stall] - [t].[io_stall] AS [stall] 
	, [divfs].[size_on_disk_bytes] - [t].[size_on_disk_bytes] AS [size change]	
	, (([divfs].[num_of_bytes_read] - [t].[num_of_bytes_read]) + ([divfs].[num_of_bytes_written] - [t].[num_of_bytes_written])) / CONVERT(DECIMAL(10, 2), ([divfs].[sample_ms] - [t].[sample_ms]) / 1000.0) AS [IOPS (Bytes/Sec)]	
	, ((([divfs].[num_of_bytes_read] - [t].[num_of_bytes_read]) + ([divfs].[num_of_bytes_written] - [t].[num_of_bytes_written])) / CONVERT(DECIMAL(10, 2), ([divfs].[sample_ms] - [t].[sample_ms]) / 1000.0) / 1024.) AS [IOPS (KB/Sec)]
FROM [sys].[dm_io_virtual_file_stats](NULL, NULL) AS divfs
INNER JOIN #ReadWriteTemp AS t 
	ON [divfs].[database_id] = [t].[database_id]
	AND [divfs].[file_handle] = [t].[file_handle]
INNER JOIN [sys].[master_files] AS mf 
	ON [t].[database_id] = [mf].[database_id]
	AND [t].[file_id] = [mf].[file_id]
-- Only check for the Master, TempDB and current DB.
--WHERE [divfs].[database_id] IN (1,2,DB_ID())
ORDER BY 
	[mf].[type_desc]
	, ([divfs].[num_of_bytes_read] - [t].[num_of_bytes_read]) + ([divfs].[num_of_bytes_written] - [t].[num_of_bytes_written]) DESC
go    

--------------------------------------------------------------------------------------------------------------------------------------
-- More AVG calculations

WITH Agg_IO_Stats
AS
(
  SELECT
    DB_NAME(database_id) AS database_name	
	, CAST(SUM(num_of_bytes_read + num_of_bytes_written) / 1048576 / 1024. AS DECIMAL(12, 2)) AS io_in_gb
  FROM sys.dm_io_virtual_file_stats(DB_ID(), NULL) AS DM_IO_Stats
  GROUP BY database_id
)
, Rank_IO_Stats AS
(
	SELECT
		ROW_NUMBER() OVER(ORDER BY io_in_gb DESC) AS row_num
		, database_name		
		, CAST(io_in_gb / SUM(io_in_gb) OVER() * 100 AS DECIMAL(5, 2)) AS pct
		, io_in_gb
	FROM Agg_IO_Stats
)
SELECT 
	R1.row_num
	, R1.database_name
	, R1.io_in_gb
	, R1.pct
	, SUM(R2.pct) AS run_pct
FROM Rank_IO_Stats AS R1
JOIN Rank_IO_Stats AS R2
    ON R2.row_num <= R1.row_num
GROUP BY R1.row_num, R1.database_name, R1.io_in_gb, R1.pct
ORDER BY R1.row_num;    

--------------------------------------------------------------------------------------------------------------------------------------
-- Quick Lookup for I/O info.

-- 1.
SELECT	DB_NAME(mf.database_id) AS databaseName ,
		name AS File_LogicalName ,
		CASE WHEN type_desc = 'LOG' THEN 'Log File'
			 WHEN type_desc = 'ROWS' THEN 'Data File'
			 ELSE type_desc
		END AS File_type_desc ,
		mf.physical_name ,
		num_of_reads ,
		num_of_bytes_read ,
		io_stall_read_ms ,
		num_of_writes ,
		num_of_bytes_written ,
		io_stall_write_ms ,
		io_stall ,
		size_on_disk_bytes ,
		size_on_disk_bytes / 1024 AS size_on_disk_KB ,
		size_on_disk_bytes / 1024 / 1024 AS size_on_disk_MB ,
		size_on_disk_bytes / 1024 / 1024 / 1024 AS size_on_disk_GB
FROM	sys.dm_io_virtual_file_stats(NULL, NULL) AS divfs
		JOIN sys.master_files AS mf ON mf.database_id = divfs.database_id
									   AND mf.FILE_ID = divfs.FILE_ID
where DB_NAME(mf.database_id) = 'LLS'
ORDER BY num_of_Reads DESC


-- 2.
SELECT	DB_NAME(vfs.DbId) DatabaseName ,
		mf.name ,
		mf.physical_name ,
		vfs.BytesRead ,
		vfs.BytesWritten ,
		vfs.IoStallMS ,
		vfs.IoStallReadMS ,
		vfs.IoStallWriteMS ,
		vfs.NumberReads ,
		vfs.NumberWrites ,
		( Size * 8 ) / 1024 Size_MB
FROM	::
		FN_VIRTUALFILESTATS(NULL, NULL) vfs
		INNER JOIN sys.master_files mf ON mf.database_id = vfs.DbId
										  AND mf.FILE_ID = vfs.FileId
order by IoStallMS DESC


--------------------------------------------------------------------------------------------------------------------------------------
-- More detailed I/O check.

DECLARE @TotalIO    BIGINT,
    @TotalBytes BIGINT,
    @TotalStall BIGINT

SELECT @TotalIO  = SUM(NumberReads + NumberWrites),
       @TotalBytes = SUM(BytesRead + BytesWritten),
       @TotalStall = SUM(IoStallMS)
FROM ::FN_VIRTUALFILESTATS(NULL, NULL)

SELECT [DbName] = DB_NAME([DbId]),
      (SELECT name FROM sys.master_files
        WHERE database_id = [DbId]
              and FILE_ID = [FileId]) filename,
    [%ReadWrites]       = (100 * (NumberReads + NumberWrites) / @TotalIO),
    [%Bytes]        = (100 * (BytesRead + BytesWritten) / @TotalBytes),
    [%Stall]        = (100 * IoStallMS / @TotalStall),
    [NumberReads],
    [NumberWrites],
    [TotalIO]       = CAST((NumberReads + NumberWrites) AS BIGINT),
    [MBsRead]       = [BytesRead] / (1024*1024),
    [MBsWritten]        = [BytesWritten] / (1024*1024),
    [TotalMBs]      = (BytesRead + BytesWritten) / (1024*1024),
    [IoStallMS],
    IoStallReadMS,
    IoStallWriteMS,
    [AvgStallPerIO]     = ([IoStallMS] / ([NumberReads] + [NumberWrites] + 1)),
    [AvgStallPerReadIO] = (IoStallReadMS / ([NumberReads] + 1)),
    [AvgStallPerWriteIO]= (IoStallWriteMS / ( [NumberWrites] + 1)),

    [AvgBytesPerRead]  = ((BytesRead) / (NumberReads + 1)),
    [AvgBytesPerWrite] = ((BytesWritten) / (NumberWrites + 1))
FROM ::FN_VIRTUALFILESTATS(NULL, NULL)
ORDER BY dbname

--------------------------------------------------------------------------------------------------------------------------------------
-- More detailed I/O check - From SQLSkills

SELECT
    [ReadLatency] =
        CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([io_stall_read_ms] / [num_of_reads]) END,
    [WriteLatency] =
        CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([io_stall_write_ms] / [num_of_writes]) END,
    [Latency] =
        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            THEN 0 ELSE ([io_stall] / ([num_of_reads] + [num_of_writes])) END,
    [AvgBPerRead] =
        CASE WHEN [num_of_reads] = 0
            THEN 0 ELSE ([num_of_bytes_read] / [num_of_reads]) END,
    [AvgBPerWrite] =
        CASE WHEN [num_of_writes] = 0
            THEN 0 ELSE ([num_of_bytes_written] / [num_of_writes]) END,
    [AvgBPerTransfer] =
        CASE WHEN ([num_of_reads] = 0 AND [num_of_writes] = 0)
            THEN 0 ELSE
                (([num_of_bytes_read] + [num_of_bytes_written]) /
                ([num_of_reads] + [num_of_writes])) END,
    LEFT ([mf].[physical_name], 2) AS [Drive],
    DB_NAME ([vfs].[database_id]) AS [DB],
    [mf].[physical_name]
FROM
    sys.dm_io_virtual_file_stats (NULL,NULL) AS [vfs]
JOIN sys.master_files AS [mf]
    ON [vfs].[database_id] = [mf].[database_id]
    AND [vfs].[file_id] = [mf].[file_id]
-- WHERE [vfs].[file_id] = 2 -- log files
--ORDER BY [Latency] DESC
-- ORDER BY [ReadLatency] DESC
ORDER BY [WriteLatency] DESC;
GO

--------------------------------------------------------------------------------------------------------------------------------------
-- More detailed I/O check - From BrentOzar sp_Blitz.

SELECT  
		-- MS values.
		[a].[io_stall],
        [a].[io_stall_read_ms],
        [a].[io_stall_write_ms],

		-- Sec values.
		( [a].[io_stall] / 1000.) AS [io_stall_sec],
        ( [a].[io_stall_read_ms] / 1000.) AS [io_stall_read_sec],
        ( [a].[io_stall_write_ms] / 1000.) AS [io_stall_write_sec],

        [a].[num_of_reads],
        [a].[num_of_writes],
        [a].[sample_ms],
        [a].[num_of_bytes_read],
        [a].[num_of_bytes_written],
        [a].[io_stall_write_ms],
        ( ( [a].[size_on_disk_bytes] / 1024 ) / 1024.0 ) AS [size_on_disk_mb],
        DB_NAME([a].[database_id]) AS [dbname],
        [b].[name],
        [a].[file_id],
        [db_file_type] = ( CASE WHEN [a].[file_id] = 2 THEN '[Log]' ELSE '[Data]' END ),
        UPPER(SUBSTRING([b].[physical_name], 1, 2)) AS [disk_location]
FROM    [sys].[dm_io_virtual_file_stats](NULL, NULL) [a]
        JOIN [sys].[master_files] [b] 
			ON [a].[file_id] = [b].[file_id]
			AND [a].[database_id] = [b].[database_id]
ORDER BY [a].[io_stall] DESC;