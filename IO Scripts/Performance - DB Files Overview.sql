/*****************************************************************************************************************************
CHECK DB FILES.
*****************************************************************************************************************************/

USE [master]
GO

------------------------------------------------------------------------------------------------------------------------------
-- Variable and Table Declaration.

DECLARE	@SQL NVARCHAR(max);

DECLARE @tblSums TABLE (
	SizeMB DECIMAL(10,2) NULL
	, FreeSpaceMB DECIMAL(10,2) NULL
	, UsedSpaceMB DECIMAL(10,2) NULL
);

DECLARE @tblResults TABLE (
	ID INT NULL
	, SizeMB DECIMAL(10,2) NULL
	, GrowthMB DECIMAL(10,2) NULL
	, MaxSizeMB DECIMAL(10,2) NULL
	, FreeSpaceMB DECIMAL(10,2) NULL
	, UsedSpaceMB DECIMAL(10,2) NULL
	, [DBID] INT NULL
	, DBName NVARCHAR(512)
	, [Logical Name] NVARCHAR(128)
	, [FileGroup] NVARCHAR(512) NULL
	, [Physical Path] NVARCHAR(1024)
	, [DB Recovery Model] NVARCHAR(512)
	, [LOG Reuse Wait] NVARCHAR(256)
);

IF OBJECT_ID('tempdb..##DbSize') IS NOT NULL
	DROP TABLE ##DbSize;

CREATE TABLE ##DbSize
	(
	  DbName NVARCHAR(128) ,
	  Name NVARCHAR(128) ,
	  [FileName] NVARCHAR(512) ,
	  [FileGroup] NVARCHAR(512) ,
	  Size FLOAT ,
	  UsedSpace FLOAT ,
	  FreeSpace AS Size - UsedSpace ,
	  ID INT ,
	  Growth FLOAT ,
	  MaxSize FLOAT
	);

SET @SQL = '
USE [?]
DECLARE	@PageSize FLOAT 
SELECT	@PageSize = v.low / 1024.0
FROM	master..spt_values v
WHERE	v.number = 1
		AND v.type = ''E''

CREATE TABLE #tmpspc
	(
	  Fileid INT ,
	  FileGroup INT ,
	  TotalExtents INT ,
	  UsedExtents INT ,
	  Name NVARCHAR(128) ,
	  FileName NCHAR(520)
	)

INSERT	#tmpspc
		EXEC ( ''DBCC showfilestats''
			)

CREATE TABLE #tmplogspc
	(
	  DatabaseName NVARCHAR(128) ,
	  LogSize FLOAT ,
	  SpaceUsedPerc FLOAT ,
	  Status BIT
	)

INSERT	#tmplogspc
		EXEC ( ''DBCC sqlperf(logspace)''
			)

INSERT	INTO ##DbSize
		( DbName ,
		  Name ,
		  FileName ,
		  [FileGroup] ,
		  Size ,
		  UsedSpace ,
		  ID ,
		  Growth ,
		  MaxSize
		)
		SELECT	DB_NAME() ,
				RTRIM(s.name) AS [Name] ,
				RTRIM(s.filename) AS [FileName] ,
				[g].[groupname] ,
				( s.size * @PageSize ) AS [Size] ,
				CAST(tspc.UsedExtents * CONVERT(FLOAT, 64) AS FLOAT) AS [UsedSpace] ,
				CAST(s.fileid AS INT) AS [ID] , 
				( s.growth * @PageSize) AS Growth ,
				( CASE WHEN s.maxsize < 0 THEN -1 ELSE ( s.maxsize * @PageSize ) END ) AS MaxSize
		FROM	dbo.sysfilegroups AS g
				INNER JOIN dbo.sysfiles AS s ON s.groupid = CAST(g.groupid AS INT)
				INNER JOIN #tmpspc tspc ON tspc.Fileid = CAST(s.fileid AS INT)
	--WHERE (g.groupname=N''PRIMARY'')

INSERT	INTO ##DbSize
		( DbName ,
		  Name ,
		  FileName ,
		  Size ,
		  UsedSpace ,
		  ID ,
		  Growth ,
		  MaxSize
		)
		SELECT	DB_NAME() ,
				RTRIM(s.name) AS [Name] ,
				RTRIM(s.filename) AS [FileName] ,
				( s.size * @PageSize ) AS [Size] ,
				tspclog.LogSize * tspclog.SpaceUsedPerc * 10.24 AS [UsedSpace] ,
				CAST(s.fileid AS INT) AS [ID] ,
				( s.growth * @PageSize) AS Growth ,
				( CASE WHEN s.maxsize < 0 THEN -1 ELSE ( s.maxsize * @PageSize ) END ) AS MaxSize
		FROM	dbo.sysfiles AS s
				INNER JOIN #tmplogspc tspclog ON tspclog.DatabaseName = DB_NAME()
		WHERE	( s.groupid = 0 )

DROP TABLE #tmpspc
DROP TABLE #tmplogspc
';

EXEC sp_MSforeachdb @SQL, '?'

------------------------------------------------------------------------------------------------------------------------------
-- Insert Data.

INSERT INTO @tblResults (
	ID
	, SizeMB
	, GrowthMB
	, MaxSizeMB
	, FreeSpaceMB
	, UsedSpaceMB
	, DBName
	, [DBID]
	, [Logical Name]
	, [FileGroup]
	, [Physical Path]
	, [DB Recovery Model]
	, [LOG Reuse Wait]
)
OUTPUT INSERTED.SizeMB, INSERTED.FreeSpaceMB, INSERTED.UsedSpaceMB INTO @tblSums (SizeMB, FreeSpaceMB, UsedSpaceMB)
SELECT
	ROW_NUMBER() OVER (ORDER BY FreeSpaceMB DESC, DbName ASC) AS [Row #]
	, a.*	
FROM (
	SELECT	ROUND(s.Size / 1024, 2) AS SizeMB 
			, ROUND(s.[Growth] / 1024, 2) AS GrowthMB
			, ROUND(s.[MaxSize] / 1024, 2) AS MaxSizeMB
			, ROUND(s.FreeSpace / 1024, 2) AS FreeSpaceMB 
			, ROUND(s.UsedSpace / 1024, 2) AS UsedSpaceMB
			, s.DbName
			, d.database_id
			, s.Name AS [Logical Name]
			, [s].[FileGroup]
			, s.FileName AS [Physical Path]
			, d.recovery_model_desc AS [DB Recovery Model]
			, d.log_reuse_wait_desc AS [LOG Reuse Wait]
	FROM	##DbSize s
			JOIN sys.databases d ON d.name = s.DbName
) a

-- =========================================================================================================================
-- Query Filtering.

/* 
CLAUSE FOR FILTERING (WHERE) - BEGIN
*/


/* 
CLAUSE FOR FILTERING (WHERE) - END
*/

---------------------------------------------------------------------------------------------------------------------------
-- Return Results.

SELECT  [ID]
       ,[SizeMB]
       ,[GrowthMB]
	   ,( CASE WHEN [MaxSizeMB] = 0 THEN 'UNLIMITED' ELSE CAST([MaxSizeMB] AS VARCHAR(64)) END ) AS [MaxSizeMB]
	  --,[MaxSizeMB]
       ,[FreeSpaceMB]
	   ,CAST(([FreeSpaceMB] / [SizeMB]) * 100 AS DECIMAL(10,2)) AS [FreeSpace (%)]
       ,[UsedSpaceMB]
	   ,CAST(([UsedSpaceMB] / [SizeMB]) * 100 AS DECIMAL(10,2)) AS [UsedSpace (%)]
       ,[DBID]
       ,[DBName]
       ,[Logical Name]
	   ,[FileGroup] AS [File Group]
       ,[Physical Path]
       ,[DB Recovery Model]
       ,[LOG Reuse Wait] 
FROM @tblResults

/* ===> Query Ordering Filtering <=== */
ORDER BY [DBName], [Logical Name] -- By DB Name and File Logical Name
--ORDER BY [SizeMB] DESC
-- =========================================================================================================================
-- Files size calculation.

SELECT
	SUM(SizeMB) AS Total_SizeMB
	, SUM(FreeSpaceMB) AS Total_FreeSpaceMB
	, SUM(UsedSpaceMB) AS Total_UsedSpaceMB
	, CAST( ((SUM(FreeSpaceMB) / SUM(SizeMB)) * 100.0) AS DECIMAL(10,2) ) AS [% Free]
FROM @tblSums;

-- =========================================================================================================================
-- Files growth resizing.

SELECT
	(
		'ALTER DATABASE [' 
		+ 
		REPLACE([DBName],'''','''''')
		+ '] MODIFY FILE ( NAME = ''' 
		+ [Logical Name] 
		+ ''', FILEGROWTH = '
		+ (
			-- User DBs 
			CASE WHEN [DBID] > 4 THEN 
				(
				    CASE WHEN RIGHT([Physical Path],3) = 'ldf' THEN
					   (
						  CASE WHEN [SizeMB] > 256 AND [GrowthMB] < 256 THEN
							 '256MB'
						  WHEN ([SizeMB] BETWEEN 128 AND 256) AND [GrowthMB] < 128 THEN
							 '128MB'
						  WHEN ([SizeMB] BETWEEN 64 AND 128) AND [GrowthMB] < 64 THEN
							 '64MB'						  
						  WHEN [SizeMB] < 64 AND [GrowthMB] < 32 THEN
							 '32MB'
						  END
					   )
				    ELSE
					   (
						  CASE WHEN [SizeMB] > 512 AND [GrowthMB] < 512 THEN
							 '512MB'						  
						  WHEN ([SizeMB] BETWEEN 256 AND 512) AND [GrowthMB] < 256 THEN
							 '256MB'
						  WHEN ([SizeMB] BETWEEN 128 AND 256) AND [GrowthMB] < 128 THEN
							 '128MB'
						  WHEN ([SizeMB] BETWEEN 64 AND 128) AND [GrowthMB] < 64 THEN
							 '64MB'						  
						  WHEN [SizeMB] < 64 AND [GrowthMB] < 32 THEN
							 '32MB'
						  END
					   )				    
				    END					
				)
			-- Master DB
			WHEN [DBID] = 1 THEN
				(
					CASE WHEN RIGHT([Physical Path],3) = 'ldf' THEN
						'32MB'
					ELSE
						'64MB'
					END
				)
			-- MSDB and Model DB
			WHEN [DBID] IN (3,4) THEN
				(
					CASE WHEN RIGHT([Physical Path],3) = 'ldf' THEN
						'256MB'
					ELSE
						'512MB'
					END
				)
			END
		)
		--+ REVERSE(LEFT(REVERSE([Physical Path]), CHARINDEX('\',REVERSE([Physical Path])) - 1))
		+ ')'
	)	
FROM @tblResults tbl
WHERE EXISTS (
	SELECT 1 FROM sys.[databases] sd
	WHERE [sd].[database_id] = tbl.[DBID]
	AND sd.[is_read_only] = 0
)
-- Remove TempDB
AND [DBID] <> 2

-- Check Space
AND (

	-- MSDB and Model
	[DBID] IN (3,4)
	AND (
		RIGHT([Physical Path],3) = 'ldf'
		AND [GrowthMB] < 256
		OR (
			RIGHT([Physical Path],3) IN ('mdf','ndf')
			AND [GrowthMB] < 512
		)
	)

	-- Master DB
	OR (
		[DBID] = 1
		AND (
			RIGHT([Physical Path],3) IN ('mdf','ndf')
			AND [GrowthMB] < 64
		) 
		OR (
			RIGHT([Physical Path],3) = 'ldf'
			AND [GrowthMB] < 32
		)
	)

	-- User DBs
	OR (
	   [DBID] > 4
	   AND (

		  -- Data Files
		  RIGHT([Physical Path],3) IN ('mdf','ndf')
		  AND (
			 [SizeMB] > 512 AND [GrowthMB] < 512
			 OR ([SizeMB] BETWEEN 256 AND 512 AND [GrowthMB] < 256)
			 OR ([SizeMB] BETWEEN 128 AND 256 AND [GrowthMB] < 128)
			 OR ([SizeMB] BETWEEN 64 AND 128 AND [GrowthMB] < 64)
			 OR ([SizeMB] < 64 AND [GrowthMB] < 32)
		  )

		  -- Log Files
		  OR (	   
			 RIGHT([Physical Path],3) = 'ldf'
			 AND (
				[SizeMB] > 256 AND [GrowthMB] < 256
				OR ([SizeMB] BETWEEN 128 AND 256 AND [GrowthMB] < 128)
				OR ([SizeMB] BETWEEN 64 AND 128 AND [GrowthMB] < 64)
				OR ([SizeMB] < 64 AND [GrowthMB] < 32)
			 )
		  )
	   )
    )
);