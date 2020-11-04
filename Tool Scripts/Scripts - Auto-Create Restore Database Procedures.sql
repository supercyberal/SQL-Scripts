USE [master]
GO

IF NOT EXISTS ( SELECT  1
                FROM    [sys].[schemas] [s]
                WHERE   [s].[name] = 'dr' )
    EXEC ('CREATE SCHEMA dr AUTHORIZATION dbo');
GO

IF EXISTS ( SELECT  1
            FROM    [INFORMATION_SCHEMA].[ROUTINES] [r]
            WHERE   [r].[ROUTINE_SCHEMA] = 'dr'
                    AND [r].[ROUTINE_NAME] = 'GenerateRestoreCommands' )
    DROP PROCEDURE [dr].[GenerateRestoreCommands]; 
GO

CREATE PROCEDURE [dr].[GenerateRestoreCommands]
	@BackupType CHAR(1)
	, @DBName SYSNAME = NULL
	, @bPrintResults BIT = 1
/*
Purpose: 
Generates RESTORE DB commands from existing backup history in msdb.
Copy and paste the output into an SSMS window.
 
Inputs:
@BackupType :  valid values are 'D' (Full Backup) or 'I' (Differential Backup)
@DBName : name of the database (NULL for all db's).

History:
11/06/2014 DMason Created
2017-04-14 - ACOSTA = Added argument @bPrintResults to determine if we the results are printed or selected.
*/
AS
BEGIN
	SET NOCOUNT ON;

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Initial checks.

	IF @BackupType NOT IN ('D', 'I')
	BEGIN
		RAISERROR('Invalid value for input parameter @BackupType.  Valid values are ''D'' (Full Backup) or ''I'' (Differential Backup)', 16, 1);
		RETURN;
	END

	IF @bPrintResults IS NULL
		SET @bPrintResults = 1;

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Temp objects.

	IF OBJECT_ID('TempDB..#LastFullBackups') IS NOT NULL
		DROP TABLE [#LastFullBackups];

	CREATE TABLE [#LastFullBackups] (
		[Database_Name] NVARCHAR(128) NOT NULL
		, [Backup_Finish_Date] DATETIME NULL
	);

	IF OBJECT_ID('TempDB..#Commands') IS NOT NULL
		DROP TABLE [#Commands];

	CREATE TABLE [#Commands] (
		[Database_Name] NVARCHAR(128) NOT NULL
		, [Command] NVARCHAR(MAX) NULL
		, [CmdOrder] NUMERIC(3,1) NULL
	);

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Prep temp objects.

	INSERT INTO [#LastFullBackups] (
		[Database_Name]
		, [Backup_Finish_Date]
	)
    SELECT  [bs].[database_name]
			, MAX([bs].[backup_finish_date]) [Backup_Finish_Date]    
    FROM    [msdb].[dbo].[backupset] [bs]
            JOIN [master].[sys].[databases] [d] ON [d].[name] = [bs].[database_name]
    WHERE   [bs].[type] = @BackupType
            AND [bs].[database_name] = COALESCE(@DBName, [bs].[database_name])
    GROUP BY [bs].[database_name];

	-- RESTORE DB:  one row per db.
	INSERT INTO [#Commands] (
		[Database_Name]
		, [Command]
		, [CmdOrder]
	)
    SELECT  [database_name]
			, 'RESTORE DATABASE ' + [database_name] AS [Command]
			, CAST(1 AS NUMERIC(3, 1)) AS [CmdOrder]    
    FROM    [#LastFullBackups];

	--FROM:  one row per db.
	INSERT INTO [#Commands] (
		[Database_Name]
		, [Command]
		, [CmdOrder]
	)
    SELECT  [database_name]
			, 'FROM' AS [Command]
			, 2 AS [CmdOrder]
    FROM    [#LastFullBackups];

	--DISK =:  one row per backup file per db.
	;WITH BackupFileCount AS
	(
        SELECT  [bs].[database_name]
				,MAX([bmf].[family_sequence_number]) [FileCount]
        FROM    [msdb].[dbo].[backupset] [bs]
                JOIN [#LastFullBackups] [lfb] 
					ON [lfb].[database_name] = [bs].[database_name]
                    AND [lfb].[Backup_Finish_Date] = [bs].[backup_finish_date]
                JOIN [msdb].[dbo].[backupmediafamily] [bmf] 
					ON [bmf].[media_set_id] = [bs].[media_set_id]
		--AND Mirror = 1
        GROUP BY [bs].[database_name]
	)
	INSERT INTO [#Commands] (
		[Database_Name]
		, [Command]
		, [CmdOrder]
	)
    SELECT  [bs].[database_name]
			, (
				CHAR(9) + 'DISK = ''' + [bmf].[physical_device_name] + ''''
				+ (
					CASE WHEN [bmf].[family_sequence_number] = [bfc].[FileCount] 
						THEN ''
					ELSE 
						','
					END
				)
			)
			, 3
    FROM    [msdb].[dbo].[backupset] [bs]
            JOIN [#LastFullBackups] [lfb] 
				ON [lfb].[database_name] = [bs].[database_name]
                AND [lfb].[Backup_Finish_Date] = [bs].[backup_finish_date]
            JOIN [msdb].[dbo].[backupmediafamily] [bmf] 
				ON [bmf].[media_set_id] = [bs].[media_set_id]
            JOIN [BackupFileCount] [bfc] 
				ON [bfc].[database_name] = [bs].[database_name];
	--AND Mirror = 1

	--WITH:  one row per db.
	INSERT INTO [#Commands] (
		[Database_Name]
		, [Command]
		, [CmdOrder]
	)
    SELECT  [database_name]
			, 'WITH ' AS [Command]
            , 4 AS [CmdOrder]
    FROM    [#LastFullBackups];

	IF @BackupType = 'D'
	BEGIN
		--Comment:  one row per db.
		INSERT INTO [#Commands] (
			[Database_Name]
			, [Command]
			, [CmdOrder]
		)
        SELECT  [database_name]
				, CHAR(9) + '--TODO: replace the source database file paths below with the database file paths for the target.' AS [Command]
				, 4.5 AS [CmdOrder]
        FROM    [#LastFullBackups];

		--MOVE:  one row per logical filename per db.
		INSERT INTO [#Commands] (
			[Database_Name]
			, [Command]
			, [CmdOrder]
		)
        SELECT  [bs].[database_name]
				, CHAR(9) + 'MOVE ''' + [bf].[logical_name] + ''' TO ''' + [bf].[physical_name] + ''','				
				, 5
        FROM    [msdb].[dbo].[backupset] [bs]
                JOIN [#LastFullBackups] [lfb] 
					ON [lfb].[database_name] = [bs].[database_name]
                    AND [lfb].[Backup_Finish_Date] = [bs].[backup_finish_date]
                JOIN [msdb].[dbo].[backupfile] [bf] 
					ON [bf].[backup_set_id] = [bs].[backup_set_id];
	END

	--REPLACE, NORECOVERY:  one row per db.
	INSERT INTO [#Commands] (
		[Database_Name]
		, [Command]
		, [CmdOrder]
	)
    SELECT  [database_name]
			, CHAR(9) + 'REPLACE, NORECOVERY, STATS = 5' + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10) AS [Command]
			, 6 AS [CmdOrder]
    FROM    [#LastFullBackups];

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Main.

    DECLARE @Tsql VARCHAR(MAX);
    SET @Tsql = '';

	--Copy and paste this output into an SSMS window.
    SELECT  @Tsql = @Tsql + [Command] + CHAR(13) + CHAR(10)
    FROM    [#Commands]
    ORDER BY 
		[Database_Name]
        , [CmdOrder];

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Drop temp objects.
	
	IF OBJECT_ID('TempDB..#LastFullBackups') IS NOT NULL
		DROP TABLE [#LastFullBackups];

	IF OBJECT_ID('TempDB..#Commands') IS NOT NULL
		DROP TABLE [#Commands];

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Proc results.

	IF @bPrintResults = 1
		PRINT @Tsql;
	ELSE
		SELECT @Tsql;
END
GO

IF EXISTS ( SELECT  1
            FROM    [INFORMATION_SCHEMA].[ROUTINES] [r]
            WHERE   [r].[ROUTINE_SCHEMA] = 'dr'
                    AND [r].[ROUTINE_NAME] = 'GenerateRestoreCommands_Log' )
    DROP PROCEDURE [dr].[GenerateRestoreCommands_Log]; 
GO

CREATE PROCEDURE [dr].[GenerateRestoreCommands_Log]
	@DBName SYSNAME = NULL
	, @bPrintResults BIT = 1
/*
Purpose: 
Generates RESTORE DB commands for transaction logs from existing backup history in msdb.
Copy and paste the output into an SSMS window.
 
Inputs:
@DBName : name of the database (NULL for all db's).

History:
11/06/2014 DMason Created
2017-04-14 - ACOSTA = Added argument @bPrintResults to determine if we the results are printed or selected.
*/
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Tsql VARCHAR(MAX);
	SET @Tsql = '';

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Initial checks.

	IF @bPrintResults IS NULL
		SET @bPrintResults = 1;

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Main.

	;WITH LastFullOrDiffBackups AS
	(
		SELECT  [bs].[database_name]
				, MAX([bs].[backup_finish_date]) [LastBackup]
		FROM    [msdb].[dbo].[backupset] [bs]
				JOIN [master].[sys].[databases] [d] 
					ON [d].[name] = [bs].[database_name]
					AND [d].[name] = COALESCE(@DBName, [d].[name])
		WHERE   [bs].[type] IN ( 'D', 'I' )
		GROUP BY [bs].[database_name]
	)
	--One row per transaction log backup per db.
	--(assumes trx logs are backed up to a single file on disk).
    SELECT  @Tsql = @Tsql + 'RESTORE DATABASE ' + [bs].[database_name] + CHAR(13) + CHAR(10) + CHAR(9) + 'FROM DISK = '''
            + [bmf].[physical_device_name] + '''' + CHAR(13) + CHAR(10) + 'WITH REPLACE, NORECOVERY ' + CHAR(13) + CHAR(10)
            + CHAR(13) + CHAR(10)
    FROM    [msdb].[dbo].[backupset] [bs]
            JOIN [LastFullOrDiffBackups] [lfodb] 
				ON [lfodb].[database_name] = [bs].[database_name]
                AND [bs].[backup_finish_date] > [lfodb].[LastBackup]
            JOIN [msdb].[dbo].[backupmediafamily] [bmf] 
				ON [bmf].[media_set_id] = [bs].[media_set_id]
	--AND Mirror = 1
    ORDER BY 
		[bs].[database_name]
        , [bs].[backup_finish_date];

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Proc results.

	IF @bPrintResults = 1
		PRINT @Tsql;
	ELSE
		SELECT @Tsql;
END
GO

IF EXISTS ( SELECT  1
            FROM    [INFORMATION_SCHEMA].[ROUTINES] [r]
            WHERE   [r].[ROUTINE_SCHEMA] = 'dr'
                    AND [r].[ROUTINE_NAME] = 'GenerateRestoreCommands_All' )
    DROP PROCEDURE [dr].[GenerateRestoreCommands_All]; 
GO

CREATE PROCEDURE [dr].[GenerateRestoreCommands_All]
	@DBName SYSNAME
	, @bPrintResults BIT = 1
	, @bUseOutVariable BIT = 0
	, @cStmtOut VARCHAR(MAX) OUT
/*
Purpose: 
Generates RESTORE DB commands for a single database.
The resulting output will restore the most recent FULL backup,
followed by the most recent DIFFERENTIAL backup (if availabel),
followed by the most recent LOG backups (if available).
Copy and paste the output into an SSMS window.
 
Inputs:
@DBName : name of the database (NULL for all db's).

History:
11/06/2014 DMason Created

2017-04-14 - ACOSTA
- Added argument @bPrintResults to determine if we the results are printed or selected.
- Added argument @bUseOutVariable and @cStmtOut to have results be stored on output variable.
*/
AS
BEGIN
	SET NOCOUNT ON;

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Initial values and checks.

	IF @bPrintResults IS NULL
		SET @bPrintResults = 1;

	IF @bUseOutVariable IS NULL
		SET @bUseOutVariable = 0;

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Local variables.

	DECLARE @tblResult TABLE (
		ID INT IDENTITY(1,1) PRIMARY KEY CLUSTERED
		, ProcResults VARCHAR(MAX)
	);

	DECLARE @cResults VARCHAR(MAX) = '';

	--------------------------------------------------------------------------------------------------------------------------------------------
	-- Main.

	IF @bPrintResults = 1
	BEGIN
		EXEC [dr].[GenerateRestoreCommands] @BackupType = 'D', @DBName = @DBName, @bPrintResults = @bPrintResults;
		EXEC [dr].[GenerateRestoreCommands] @BackupType = 'I', @DBName = @DBName, @bPrintResults = @bPrintResults;
		EXEC [dr].[GenerateRestoreCommands_Log] @DBName = @DBName, @bPrintResults = @bPrintResults;	    
	END
	ELSE
	BEGIN
	    INSERT @tblResult ( [ProcResults] )
		EXEC [dr].[GenerateRestoreCommands] @BackupType = 'D', @DBName = @DBName, @bPrintResults = @bPrintResults;

		INSERT @tblResult ( [ProcResults] )
		EXEC [dr].[GenerateRestoreCommands] @BackupType = 'I', @DBName = @DBName, @bPrintResults = @bPrintResults;
		
		INSERT @tblResult ( [ProcResults] )
		EXEC [dr].[GenerateRestoreCommands_Log] @DBName = @DBName, @bPrintResults = @bPrintResults;

		SELECT @cResults += ISNULL([tr].[ProcResults],'') FROM @tblResult AS [tr];

		IF @bUseOutVariable = 1
			SET @cStmtOut = @cResults;
		ELSE
			SELECT @cResults;
	END
END
GO 