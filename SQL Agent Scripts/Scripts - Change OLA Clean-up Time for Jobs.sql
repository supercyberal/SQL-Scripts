-- ====> TO DO <=====
-- Change Dev/QA Backup retention to 3 days.

SELECT 'ALTER DATABASE [' + [d].[name] + '] SET RECOVERY SIMPLE;', * FROM [sys].[databases] AS [d]
WHERE [d].[recovery_model_desc] <> 'SIMPLE'
GO

-- ============================================================================
-- Check Locations.

SELECT
	[s2].[name]
	--, CHARINDEX('@CleanupTime = ',[s].[command])
	--, CHARINDEX(',',[s].[command],CHARINDEX('@CleanupTime = ',[s].[command]))
	, SUBSTRING(
		[s].[command]
		, CHARINDEX('@Directory = ',[s].[command])
		, ( CHARINDEX(',',[s].[command],CHARINDEX('@Directory = ',[s].[command])) - CHARINDEX('@Directory = ',[s].[command]) )
	)
	, [s].[command] 
FROM [msdb]..[sysjobsteps] AS [s]
JOIN [msdb]..[sysjobs] AS [s2]
	ON [s2].[job_id] = [s].[job_id]
WHERE [s].[command] LIKE '%@Directory =%'
--AND [s2].[enabled] = 1
AND [s2].[name] LIKE '%FULL%'
OR [s2].[name] LIKE '%- LOG%'
GO
SELECT
	[s2].[name]
	--, CHARINDEX('@CleanupTime = ',[s].[command])
	--, CHARINDEX(',',[s].[command],CHARINDEX('@CleanupTime = ',[s].[command]))
	, SUBSTRING(
		[s].[command]
		, CHARINDEX('@CleanupTime = ',[s].[command])
		, ( CHARINDEX(',',[s].[command],CHARINDEX('@CleanupTime = ',[s].[command])) - CHARINDEX('@CleanupTime = ',[s].[command]) )
	)
	, [s].[command] 
FROM [msdb]..[sysjobsteps] AS [s]
JOIN [msdb]..[sysjobs] AS [s2]
	ON [s2].[job_id] = [s].[job_id]
WHERE [s].[command] LIKE '%@CleanupTime =%'
--AND [s2].[enabled] = 1
AND [s2].[name] LIKE '%FULL%'
OR [s2].[name] LIKE '%- LOG%'
GO
EXECUTE [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory'
GO

-- ============================================================================

DECLARE 
	@cDirName NVARCHAR(2049) = N'\\wcnet\firm\Groups\GTS\SQLBK\' + LEFT(@@SERVERNAME,3) + '\NonProd'
	, @cClenupTime NVARCHAR(16) = '72'

BEGIN TRAN

-- Backup Path
EXEC [master]..[xp_instance_regwrite] N'HKEY_LOCAL_MACHINE', N'Software\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', REG_SZ, @cDirName

-- Directory
UPDATE [s]
SET [s].[command] = REPLACE(
						[s].[command]
						, (
							SUBSTRING(
								[s].[command]
								, CHARINDEX('@Directory = ',[s].[command])
								, ( CHARINDEX(',',[s].[command],CHARINDEX('@Directory = ',[s].[command])) - CHARINDEX('@Directory = ',[s].[command]) )
							)
						)
						, '@Directory = N''' + @cDirName + ''''
					)
FROM [msdb]..[sysjobsteps] AS [s]
WHERE [s].[command] LIKE '%@Directory =%'
AND EXISTS (
	SELECT 1 FROM [msdb]..[sysjobs] AS [s2]
	WHERE (
		[s2].[name] LIKE '%FULL%'
		AND [s2].[name] LIKE '%FULL%'
		OR [s2].[name] LIKE '%- LOG%'
	)
	--AND [s2].[enabled] = 1
	AND [s2].[job_id] = [s].[job_id]
);

-- CleanupTime
UPDATE [s]
SET [s].[command] = REPLACE(
						[s].[command]
						, (
							SUBSTRING(
								[s].[command]
								, CHARINDEX('@CleanupTime = ',[s].[command])
								, ( CHARINDEX(',',[s].[command],CHARINDEX('@CleanupTime = ',[s].[command])) - CHARINDEX('@CleanupTime = ',[s].[command]) )
							)
						)
						, '@CleanupTime = ' + @cClenupTime
					)
FROM [msdb]..[sysjobsteps] AS [s]
WHERE [s].[command] LIKE '%@CleanupTime =%'
AND EXISTS (
	SELECT 1 FROM [msdb]..[sysjobs] AS [s2]
	WHERE (
		[s2].[name] LIKE '%FULL%'
		AND [s2].[name] LIKE '%FULL%'
		OR [s2].[name] LIKE '%- LOG%'
	)
	--AND [s2].[enabled] = 1
	AND [s2].[job_id] = [s].[job_id]
);

-- COMMIT
-- ROLLBACK

-- ============================================================================
GO

-- COMMIT
-- ROLLBACK