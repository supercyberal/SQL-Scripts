-- =============================================================================================================================================
-- 1. Check server collation and version settings.

SELECT
    SERVERPROPERTY('ProductVersion ') AS ProductVersion	
	, SERVERPROPERTY('PRODUCTUPDATELEVEL') AS ProductUpdateLevel
    , SERVERPROPERTY('Edition') AS SQLEdition
    , SERVERPROPERTY('ProductLevel') AS ProductLevel
    , SERVERPROPERTY('ResourceVersion') AS ResourceVersion
    , SERVERPROPERTY('ResourceLastUpdateDateTime') AS ResourceLastUpdateDateTime
    , SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS MachineName
    , SERVERPROPERTY('Collation') AS Collation
    , GETDATE() AS SystemDateTime
	, @@VERSION AS [Version];
GO

-- =============================================================================================================================================
-- 2. Check number of available schedulers.

SELECT * FROM sys.[dm_os_schedulers]
WHERE [scheduler_id] <= 255
--AND [is_online] = 1
GO

-- =============================================================================================================================================
-- 2. Check how many NUMA nodes we have on the instance.

SELECT * FROM [sys].[dm_os_nodes] AS [don]
-- Remove DAC.
WHERE [don].[node_id] <> 64
GO

SELECT * FROM sys.[dm_os_memory_nodes] AS [domn]
-- Remove DAC.
WHERE [domn].[memory_node_id] <> 64
GO

-- =============================================================================================================================================
-- 3. Check physical RAM.

SELECT
    CAST([total_physical_memory_kb] / 1024. AS DECIMAL(10,2)) AS [Physical RAM (MB)]
    , * 
FROM [sys].[dm_os_sys_memory]

-- 2005
SELECT
    CAST([dosi].[physical_memory_in_bytes] / 1024. / 1024. AS DECIMAL(10,2)) AS [Physical RAM (MB)]
    , * 
FROM [sys].[dm_os_sys_info] AS [dosi]
GO

-- =============================================================================================================================================
-- 4. Last date when SQL was restarted.

SELECT
    [sqlserver_start_time]
FROM [sys].[dm_os_sys_info]
GO

-- =============================================================================================================================================
-- 5. Check configurations.

DECLARE @tblSettings TABLE (
    SettingName NVARCHAR(35)
);

INSERT @tblSettings ( [SettingName] ) VALUES ( N'backup compression default' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'backup checksum default' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'cost threshold for parallelism' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'max degree of parallelism' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'min degree of parallelism' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'max server memory (MB)' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'min server memory (MB)' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'Ole Automation Procedures' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'optimize for ad hoc workloads' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'max worker threads' );
INSERT @tblSettings ( [SettingName] ) VALUES ( N'xp_cmdshell' );

SELECT * FROM sys.[configurations] conf
WHERE EXISTS (
    SELECT 1 FROM @tblSettings tbl
    WHERE [conf].[name] LIKE '%' + [tbl].[SettingName] + '%'
)
ORDER BY [name];
GO

-- =============================================================================================================================================
-- 6. Setup MAXDOP

/*

EXEC [sys].[sp_configure] @configname = 'show advanced options', @configvalue = 1;
RECONFIGURE WITH OVERRIDE;

EXEC [sys].[sp_configure] @configname = 'max degree of parallelism', @configvalue = 4;
RECONFIGURE WITH OVERRIDE;

EXEC [sys].[sp_configure] @configname = 'show advanced options', @configvalue = 0
RECONFIGURE WITH OVERRIDE;

*/
GO

-- =============================================================================================================================================
-- 7. Check listening TCP port.

SELECT local_tcp_port, @@SPID, [auth_scheme], [net_transport]
FROM   sys.dm_exec_connections
WHERE  session_id = @@SPID
GO

-- =============================================================================================================================================
-- 8. Check system DBs file path.

SELECT
    [name]
    , [physical_name] AS current_file_location
	, CAST( ([size] * 8) / 1024. AS DECIMAL(10,2) ) AS [Size (MB)]
FROM
    [sys].[master_files]
WHERE
    [database_id] IN ( 
	   DB_ID('master')
	   , DB_ID('model')
	   , DB_ID('msdb')
	   , DB_ID('tempdb') 
    )
ORDER BY
    [name];
GO

-- =============================================================================================================================================
-- 9. Check trace flags.

DBCC TRACESTATUS
GO

-- =============================================================================================================================================
-- 10. Check DBs owner info as well as DB settings.

SELECT
    SUSER_SNAME([owner_sid]) AS DBOwner
	, [name] AS DBName
    , (
	   CASE WHEN [compatibility_level] <> [cl].[MasterCompLevel] THEN
	   (
		  'USE [master]'
		  + CHAR(13)
		  + 'ALTER DATABASE [' + [name] + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;' 
		  + CHAR(13) 
		  + 'ALTER DATABASE [' + [name] + '] SET COMPATIBILITY_LEVEL = ' + CAST([cl].[MasterCompLevel] AS VARCHAR(4)) + ';'
		  + CHAR(13) 
		  + 'ALTER DATABASE [' + [name] + '] SET MULTI_USER;'
		  + CHAR(13)
	   ) 
	   END
    ) AS Change_DB_Compatibility
    , (
	   CASE WHEN SUSER_SNAME([owner_sid]) <> 'sa' THEN
	   (
		  'USE [' + [name] + ']'
		  + CHAR(13)
		  + 'EXEC [sys].[sp_changedbowner] @loginame = ''sa'';'
	   )
	   END
    ) AS Change_DB_Ownership
    , (
	   CASE WHEN [page_verify_option_desc] <> 'CHECKSUM' THEN
	   (
		  'USE [master]'
		  + CHAR(13)
		  + 'ALTER DATABASE [' + [name] + '] SET PAGE_VERIFY CHECKSUM;'
	   )
	   END
    ) AS Change_Page_Verification
	, (
		CASE WHEN [is_auto_shrink_on] = 1 THEN
		(
		  'USE [master]'
		  + CHAR(13)
		  + 'ALTER DATABASE [' + [name] + '] SET AUTO_SHRINK OFF;'
		)
		END
	) AS Auto_Shrink_Info
	, (
		CASE WHEN [is_auto_close_on] = 1 THEN
		(
		  'USE [master]'
		  + CHAR(13)
		  + 'ALTER DATABASE [' + [name] + '] SET AUTO_CLOSE OFF;'
		)
		END
	) AS Auto_Close_Info
	, (
		CASE WHEN [is_auto_create_stats_on] = 0 THEN
		(
		  'USE [master]'
		  + CHAR(13)
		  + 'ALTER DATABASE [' + [name] + '] SET AUTO_CREATE_STATISTICS ON;'
		)
		END
	) AS Auto_Create_Stats_Info
	, (
		CASE WHEN [is_auto_update_stats_on] = 0 THEN
		(
		  'USE [master]'
		  + CHAR(13)
		  + 'ALTER DATABASE [' + [name] + '] SET AUTO_UPDATE_STATISTICS ON;'
		)
		END
	) AS Auto_Create_Stats_Info
    , *
FROM sys.[databases]
CROSS APPLY (
    SELECT		
	    MAX([compatibility_level]) AS MasterCompLevel
    FROM [sys].[databases]
    WHERE [name] IN ( 'master','msdb' )
) cl
WHERE [database_id] > 4;
GO

-- =============================================================================================================================================
-- 11. Get list of sysadmin logins

SELECT * FROM [sys].[syslogins] AS [s]
WHERE [s].[sysadmin] = 1;
GO

-- =============================================================================================================================================
-- 12. Get current traces.

SELECT * FROM [sys].[traces] AS [t]
GO

-- =============================================================================================================================================
-- 13. SQL 2016 ONLY - Fix to remove extra TempDB files.
GO

/*

CHECKPOINT
GO
DBCC SHRINKFILE(temp2,EMPTYFILE);
DBCC SHRINKFILE(temp3,EMPTYFILE);
DBCC SHRINKFILE(temp4,EMPTYFILE);
DBCC SHRINKFILE(temp5,EMPTYFILE);
DBCC SHRINKFILE(temp6,EMPTYFILE);
DBCC SHRINKFILE(temp7,EMPTYFILE);
DBCC SHRINKFILE(temp8,EMPTYFILE);
GO
USE [master]
GO
ALTER DATABASE [tempdb] REMOVE FILE temp2;
ALTER DATABASE [tempdb] REMOVE FILE temp3;
ALTER DATABASE [tempdb] REMOVE FILE temp4;
ALTER DATABASE [tempdb] REMOVE FILE temp5;
ALTER DATABASE [tempdb] REMOVE FILE temp6;
ALTER DATABASE [tempdb] REMOVE FILE temp7;
ALTER DATABASE [tempdb] REMOVE FILE temp8;
GO

*/
GO

-- =============================================================================================================================================
-- 14. Set backup and maintenance jobs schedule.

GO

-- Backup/Restore example using Ola's solution.
/*

-- Ola Script to backup DBs.
EXEC [master].[dbo].[DatabaseBackup] 
    @Databases = N'DBName_Here', -- nvarchar(max)

    -- AMERICAS
    @Directory = N'\\am1_sqldumpserver\sqldump', -- nvarchar(max)

    -- EMEA
    @Directory = N'\\em1_sqldumpserver\sqldump', -- nvarchar(max)

    -- ASIAPAC
    @Directory = N'\\ap1_sqldumpserver\sqldump', -- nvarchar(max)

    @BackupType = N'FULL', -- nvarchar(max)
    @Verify = N'Y', -- nvarchar(max)    
    @Compress = N'Y', -- nvarchar(max)
    --@CopyOnly = N'Y', -- nvarchar(max)    
    @CheckSum = N'Y';
GO

-- Restore DB script


-- Put DBs in Single User.
/*
ALTER DATABASE [Collections] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
*/

DECLARE @BackupFile NVARCHAR(MAX) = 'D:\Program Files\Microsoft SQL Server\MSSQL11.WCDATA\MSSQL\Backup\LCRUpgrade\AM1FNDB002_Collections_FULL_COPY_ONLY_20150129_180114.bak'
-- =======> PREP VARIABLE <=======

RESTORE 
--FILELISTONLY
DATABASE [DBName_Here]
FROM DISK = @BackupFile
WITH
    FILE = 1
    -- Move Files
    /*
    , MOVE 'CollectionsPrimary' TO 'E:\Program Files\Microsoft SQL Server\MSSQL11.WCDATA\MSSQL\Data\Collections_Test_Primary.MDF'
    , MOVE 'CollectionsData1' TO 'E:\Program Files\Microsoft SQL Server\MSSQL11.WCDATA\MSSQL\Data\Collections_Test_Data1.NDF'
    , MOVE 'CollectionsIndexes1' TO 'E:\Program Files\Microsoft SQL Server\MSSQL11.WCDATA\MSSQL\Data\Collections_Test_Indexes1.NDF'
    , MOVE 'CollectionsLog1' TO 'F:\Program Files\Microsoft SQL Server\MSSQL11.WCDATA\MSSQL\Data\Collections_Test_Log1.LDF'
    */
    , REPLACE
    , RECOVERY
    , STATS = 5
GO

*/