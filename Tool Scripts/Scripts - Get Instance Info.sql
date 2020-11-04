USE master
GO

-- =============================================================================================================================================
-- GET TRACEINFO
-- =============================================================================================================================================

DECLARE @tTrace TABLE (
	TraceFlag INT NOT NULL
	, TrStatus BIT NOT NULL
	, TrGlobal BIT NOT NULL
	, TrSess BIT NOT NULL
)
INSERT @tTrace (
	[TraceFlag]
	, [TrStatus]
	, [TrGlobal]
	, [TrSess]
)
EXEC ('DBCC TRACESTATUS');

-- =============================================================================================================================================
-- GET DEFAULT BACKUP FOLDER
-- =============================================================================================================================================

DECLARE @tBackupFolder TABLE (
	SettingName VARCHAR(64) NOT NULL
	, SettingValue VARCHAR(256) NOT NULL
)
INSERT @tBackupFolder ([SettingName], [SettingValue])
EXEC master.dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE',N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory';

-- =============================================================================================================================================
-- RETURN SETTINGS
-- =============================================================================================================================================

SELECT	 
	ISNULL((
		SELECT [SettingValue] FROM @tBackupFolder
	),'') AS [Backup_Folder]
	, ISNULL((
		SELECT CASE WHEN [name] IS NOT NULL THEN 'Yes' END FROM sys.[databases]
		WHERE [name] = 'dbWarden'
	),'') AS [DBWarden]
	, ISNULL((
		SELECT CASE WHEN [TraceFlag] IS NOT NULL THEN 'Yes' END FROM @tTrace
		WHERE [TraceFlag] = 1118
	),'') AS [Tr_1118]
	, ISNULL((
		SELECT CASE WHEN [TraceFlag] IS NOT NULL THEN 'Yes' END FROM @tTrace
		WHERE [TraceFlag] = 1222
	),'') AS [Tr_1222]
	, ISNULL((
		SELECT CASE WHEN [name] IS NOT NULL THEN 'Yes' END FROM sys.[databases]
		WHERE [name] = 'AuditLog'
	),'') AS [AuditLog]
	, (
		SELECT
			[value]
		FROM sys.[configurations] c
		WHERE [name] = 'cost threshold for parallelism'
	) AS [Cost Threshould of Parallelism]
	, (
		SELECT
			[value]
		FROM sys.[configurations] c
		WHERE [name] = 'max degree of parallelism'
	) AS [Max Degree of Parallelism]
	, (
		SELECT
			[value]
		FROM sys.[configurations] c
		WHERE [name] = 'max server memory (MB)'
	) AS [Max Server Memory]
	, (
		SELECT
			[value]
		FROM sys.[configurations] c
		WHERE [name] = 'min server memory (MB)'
	) AS [Min Server Memory]
	, ISNULL((
		SELECT
			CASE WHEN [value] = 1 THEN 'Yes' END
		FROM sys.[configurations] c
		WHERE [name] = 'backup compression default'
	),'') AS [Backup Compression]