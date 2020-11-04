-- =============================================================================================================================================
-- Build the sp_detach_db:

SELECT
	'EXEC [sys].[sp_detach_db] @dbname = ''' + [d].[name] + ''', @skipchecks = N''true'', @keepfulltextindexfile = N''true'';'
	, * 
FROM sys.[databases] AS [d]
WHERE [d].[database_id] > 4;

-- =============================================================================================================================================
-- Build the sp_attach_db: 
-- (I preach everyone against using cursor... so I don't) 

SET NOCOUNT ON  
DECLARE     @cmd        VARCHAR(MAX), 
            @dbname     VARCHAR(200), 
            @prevdbname VARCHAR(200) 

SELECT @cmd = '', @dbname = ';', @prevdbname = '' 

IF OBJECT_ID('TempDB..#Attach') IS NOT NULL
	DROP TABLE #Attach;

CREATE TABLE #Attach 
    (Seq        INT IDENTITY(1,1) PRIMARY KEY, 
     dbname     SYSNAME NULL, 
     fileid     INT NULL, 
     filename   VARCHAR(1000) NULL, 
     TxtAttach  VARCHAR(MAX) NULL 
) 

INSERT INTO [#Attach]
SELECT DISTINCT DB_NAME(dbid) AS dbname, fileid, filename, CONVERT(VARCHAR(MAX),'') AS TxtAttach 
FROM master.dbo.sysaltfiles 
WHERE dbid IN (
			SELECT dbid FROM master.dbo.sysaltfiles  
            --WHERE SUBSTRING(filename,1,1) IN ('E','F')
			) 
            AND DATABASEPROPERTYEX( DB_NAME(dbid) , 'Status' ) = 'ONLINE' 
            AND DB_NAME(dbid) NOT IN ('master','tempdb','msdb','model')
ORDER BY dbname, fileid, filename;

UPDATE [a]
SET 
	@cmd = TxtAttach =   
            CASE WHEN dbname <> @prevdbname THEN 
				CONVERT(VARCHAR(200),'CREATE DATABASE [' + dbname + '] ON ')
            ELSE 
				@cmd 
            END 
			+ '(FILENAME = N''' + [filename] +'''),'			
			, @prevdbname = CASE WHEN dbname <> @prevdbname THEN dbname ELSE @prevdbname END
			, @dbname = dbname 
FROM [#Attach] AS [a] 
WITH (INDEX(0),TABLOCKX) 
OPTION (MAXDOP 1) 

SELECT 
	LEFT(TxtAttach, LEN([x].[TxtAttach]) - 1)
	+ ' FOR ATTACH WITH ENABLE_BROKER;'
FROM 
(SELECT dbname, MAX(TxtAttach) AS TxtAttach FROM #Attach  
 GROUP BY dbname) AS x 