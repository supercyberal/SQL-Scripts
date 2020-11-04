/***********************************************************************************************************************************************
= Script Name: OLLA Job Drop and Creation.sql

= Purpose:
Drops and re-creates olla's maintenance jobs.

= Notes:
- ACOSTA - 2013-02-14 = Created.

- ACOSTA - 2013-02-18
	Changed "Output File" job command directory to point to MaintenanceHistory folder.
	Added the ability to create the output directory.
	Added the 12 months FULL backup job creation.

- ACOSTA - 2013-03-20
	Added Powershell delete step to job "Output File Cleanup".

- ACOSTA - 2013-04-17
	Added a backup directory variable.
	Changed backup jobs to use backup variable for destination.
***********************************************************************************************************************************************/

USE [msdb]
GO

DECLARE 
	-- System Related Variables
	@jobId BINARY(16)
	, @cDBName sysname
	, @iCount INT
	, @iCountTotalJobs INT
	, @ReturnCode INT
	, @cOutputFileName NVARCHAR(max)
	, @cServerName sysname
	, @cMaintDirectoryName sysname
	, @cBackupDirectoryName sysname
	, @iOutputFileNameSize INT
	, @cSrvVersion NVARCHAR(max)
	, @cSrvEdition NVARCHAR(max)
	, @cSQLCmmd NVARCHAR(max)
	, @bCreateOutputFileCleanupPOSHStep BIT
	, @cOperatorName NVARCHAR(256) 

	/*Custom Variables*/
	, @bCreateBackupJobs BIT
    , @bCreate12MonthsFullBackupJob BIT
	, @bLOGBackupEnable BIT;
	
SET	@iCount = 1;
SET @iCountTotalJobs = 0;
SET @ReturnCode = 0;
SET @cServerName = UPPER(REPLACE(@@SERVERNAME,'\','_'));
SET @cMaintDirectoryName = 'D:\Maintenance_History';
SET @cBackupDirectoryName = 'D:\Backup'
SET @iOutputFileNameSize = (SELECT CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'output_file_name');
SET @cSrvVersion = CAST(SERVERPROPERTY('productversion') AS NVARCHAR(max));
SET @cSrvEdition = CAST(SERVERPROPERTY ('edition') AS NVARCHAR(max));
SET @bCreateOutputFileCleanupPOSHStep = 1;

/*Custom Variables*/

-- Set which operator to be notified.
SET @cOperatorName = N'IT-Databases';

-- Set this to 1 (True) if you want backup jobs to be created.
SET @bCreateBackupJobs = 1;

-- Determines if we need to enable the log backup job. Only set this to 1 if a prod environment.
SET @bLOGBackupEnable = 1;

-- Set this to 1 (true) if you want a 12 months full backup being taken at the last day of the month to be created.
SET @bCreate12MonthsFullBackupJob = 0;

-- Make sure to set xp_cmdshell to active.
IF @bCreateOutputFileCleanupPOSHStep = 1
BEGIN
	EXEC sys.sp_configure @configname = 'show advanced options', @configvalue = 1;
	RECONFIGURE;

	EXEC sys.sp_configure @configname = 'xp_cmdshell', @configvalue = 1;
	RECONFIGURE;

	EXEC sys.sp_configure @configname = 'show advanced options', @configvalue = 0;
	RECONFIGURE;	
END

BEGIN TRY
	-- =============================================================================================================================================
	-- Required initial checks.

	IF @iOutputFileNameSize IS NULL OR @iOutputFileNameSize = 0
		RAISERROR('Output File Size not set',16,1);

	-- Create output file directory.
	DECLARE @DirectoryInfo TABLE (FileExists BIT, FileIsADirectory BIT, ParentDirectoryExists BIT);
	INSERT INTO @DirectoryInfo (FileExists, FileIsADirectory, ParentDirectoryExists)
	EXECUTE [master].dbo.xp_fileexist @cMaintDirectoryName;

	IF EXISTS (SELECT 1 FROM @DirectoryInfo WHERE FileIsADirectory = 0)
		EXEC master..xp_create_subdir @cMaintDirectoryName;

	-- =============================================================================================================================================
	-- Firt drop the jobs.

	DECLARE @tblJobs TABLE (
		Id INT IDENTITY(1,1) NOT NULL
		, JobName sysname NOT NULL
	);
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - CommandLog Cleanup');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseBackup - SYSTEM_DATABASES - FULL');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseBackup - USER_DATABASES - DIFF');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseBackup - USER_DATABASES - FULL');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseBackup - USER_DATABASES - LOG');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseIntegrityCheck - SYSTEM_DATABASES');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - DatabaseIntegrityCheck - USER_DATABASES');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - IndexOptimize - USER_DATABASES');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - Output File Cleanup');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - sp_delete_backuphistory');
	INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - OLA - sp_purge_jobhistory');

	--Original's from OLA
	INSERT INTO @tblJobs (JobName) VALUES ('CommandLog Cleanup');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseBackup - SYSTEM_DATABASES - FULL');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseBackup - USER_DATABASES - DIFF');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseBackup - USER_DATABASES - FULL');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseBackup - USER_DATABASES - LOG');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseIntegrityCheck - SYSTEM_DATABASES');
	INSERT INTO @tblJobs (JobName) VALUES ('DatabaseIntegrityCheck - USER_DATABASES');
	INSERT INTO @tblJobs (JobName) VALUES ('IndexOptimize - USER_DATABASES');
	INSERT INTO @tblJobs (JobName) VALUES ('Output File Cleanup');
	INSERT INTO @tblJobs (JobName) VALUES ('sp_delete_backuphistory');
	INSERT INTO @tblJobs (JobName) VALUES ('sp_purge_jobhistory');

	SELECT @iCountTotalJobs = COUNT(*) FROM @tblJobs tj;

	WHILE @iCount <= @iCountTotalJobs
	BEGIN
		SELECT @cDBName = JobName FROM @tblJobs tj WHERE Id = @iCount;

		IF EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @cDBName)
			EXEC msdb.dbo.sp_delete_job @job_name = @cDBName, @delete_unused_schedule=1;	

		SET @iCount = @iCount + 1;
	END

	-- =============================================================================================================================================
	-- Now recreate them all.

	BEGIN TRANSACTION;

	IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
	BEGIN
		EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance';
	END

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- CommandLog Cleanup Job.
	
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\CommandLogCleanup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - CommandLog Cleanup Job.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - CommandLog Cleanup', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: http://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName, 
			@job_id = @jobId OUTPUT;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'CommandLog Cleanup', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'CmdExec', 
			@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "DELETE FROM [dbo].[CommandLog] WHERE DATEDIFF(dd,StartTime,GETDATE()) > 30" -b', 
			@output_file_name=@cOutputFileName, 
			@flags=0;

	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Saturday @ 2 AM', 
			@enabled=1, 
			@freq_type=8, 
			@freq_interval=64, 
			@freq_subday_type=1, 
			@freq_subday_interval=0, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=1, 
			@active_start_date=20130207, 
			@active_end_date=99991231, 
			@active_start_time=20000, 
			@active_end_time=235959;
			
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

	IF @bCreateBackupJobs = 1
	BEGIN
		IF @bCreate12MonthsFullBackupJob = 1
		BEGIN
			----------------------------------------------------------------------------------------------------------------------------------------
			-- DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months.
			        
			SET @jobId = NULL;
			SET @ReturnCode = NULL;
			SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';
			
			IF LEN(@cOutputFileName) > @iOutputFileNameSize
				RAISERROR('Output file name is too large. Segment - DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months',16,1);

			-- Dont use compression if version is equal to "Standard" and less than 10.5
			IF (@cSrvEdition LIKE 'Standard%') AND (CAST(LEFT(@cSrvVersion,4) AS REAL) < 10.5)				
				SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = N''' + @cBackupDirectoryName + '\FULL12MO\'', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 8765, @CheckSum = ''Y'', @LogToTable = ''Y''" -b'
			ELSE
				SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = N''' + @cBackupDirectoryName + '\FULL12MO\'', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 8765, @Compress=''Y'', @CheckSum = ''Y'', @LogToTable = ''Y''" -b';

			EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months', 
					@enabled=1, 
					@notify_level_eventlog=2, 
					@notify_level_email=2, 
					@notify_level_netsend=0, 
					@notify_level_page=0, 
					@delete_level=0, 
					@description=N'Source: http://ola.hallengren.com', 
					@category_name=N'Database Maintenance', 
					@owner_login_name=N'sa', 
					@notify_email_operator_name=@cOperatorName,
					@job_id = @jobId OUTPUT;

			EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months', 
					@step_id=1, 
					@cmdexec_success_code=0, 
					@on_success_action=1, 
					@on_success_step_id=0, 
					@on_fail_action=2, 
					@on_fail_step_id=0, 
					@retry_attempts=0, 
					@retry_interval=0, 
					@os_run_priority=0, @subsystem=N'CmdExec', 
					@command=@cSQLCmmd, 
					@output_file_name=@cOutputFileName, 
					@flags=0;

			-- Dont use compression if version is equal to "Standard" and less than 10.5
			IF (@cSrvEdition LIKE 'Standard%') AND (CAST(LEFT(@cSrvVersion,4) AS REAL) < 10.5)
			BEGIN
				EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months', 
						@step_id=1, 
						@cmdexec_success_code=0, 
						@on_success_action=1, 
						@on_success_step_id=0, 
						@on_fail_action=2, 
						@on_fail_step_id=0, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0, @subsystem=N'CmdExec', 
						@command=@cSQLCmmd, 
						@output_file_name=@cOutputFileName, 
						@flags=0;
			END
			ELSE
			BEGIN      
				EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - SYSTEM_DATABASES - FULL - 12 Months', 
						@step_id=1, 
						@cmdexec_success_code=0, 
						@on_success_action=1, 
						@on_success_step_id=0, 
						@on_fail_action=2, 
						@on_fail_step_id=0, 
						@retry_attempts=0, 
						@retry_interval=0, 
						@os_run_priority=0, @subsystem=N'CmdExec', 
						@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = N''\\peakbackup01\SQLBackups\FULL12MO\'', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 8765, @Compress=''Y'', @CheckSum = ''Y'', @LogToTable = ''Y''" -b', 
						@output_file_name=@cOutputFileName, 
						@flags=0;		
			END

			EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

			EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run @ Last Day of Every Month', 
					@enabled=1, 
					@freq_type=32, 
					@freq_interval=8, 
					@freq_subday_type=1, 
					@freq_subday_interval=0, 
					@freq_relative_interval=16, 
					@freq_recurrence_factor=1, 
					@active_start_date=20130218, 
					@active_end_date=99991231, 
					@active_start_time=30000, 
					@active_end_time=235959;
				
			EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;
		END 
		 
		--------------------------------------------------------------------------------------------------------------------------------------------
		-- DatabaseBackup - SYSTEM_DATABASES - FULL.

		SET @jobId = NULL;
		SET @ReturnCode = NULL;		
		SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

		IF LEN(@cOutputFileName) > @iOutputFileNameSize
			RAISERROR('Output file name is too large. Segment - DatabaseBackup - SYSTEM_DATABASES - FULL.',16,1);

		-- Dont use compression if version is equal to "Standard" and less than 10.5
		IF (@cSrvEdition LIKE 'Standard%') AND (CAST(LEFT(@cSrvVersion,4) AS REAL) < 10.5)
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 168, @CheckSum = ''Y'', @LogToTable = ''Y''" -b';
		ELSE
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''SYSTEM_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 168, @Compress=''Y'', @CheckSum = ''Y'', @LogToTable = ''Y''" -b';

		EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseBackup - SYSTEM_DATABASES - FULL', 
				@enabled=1, 
				@notify_level_eventlog=2, 
				@notify_level_email=2, 
				@notify_level_netsend=0, 
				@notify_level_page=0, 
				@delete_level=0, 
				@description=N'Source: http://ola.hallengren.com', 
				@category_name=N'Database Maintenance', 
				@owner_login_name=N'sa', 
				@notify_email_operator_name=@cOperatorName,
				@job_id = @jobId OUTPUT;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - SYSTEM_DATABASES - FULL', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'CmdExec', 
				@command=@cSQLCmmd, 
				@output_file_name=@cOutputFileName, 
				@flags=0;

		EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Sunday @ 3 AM', 
				@enabled=1, 
				@freq_type=8, 
				@freq_interval=1, 
				@freq_subday_type=1, 
				@freq_subday_interval=0, 
				@freq_relative_interval=0, 
				@freq_recurrence_factor=1, 
				@active_start_date=20130207, 
				@active_end_date=99991231, 
				@active_start_time=30000, 
				@active_end_time=235959;
				
		EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

		--------------------------------------------------------------------------------------------------------------------------------------------
		-- DatabaseBackup - USER_DATABASES - DIFF.

		SET @jobId = NULL;
		SET @ReturnCode = NULL;
		SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

		IF LEN(@cOutputFileName) > @iOutputFileNameSize
			RAISERROR('Output file name is too large. Segment - DatabaseBackup - USER_DATABASES - DIFF.',16,1);

		-- Dont use compression if version is equal to "Standard" and less than 10.5
		IF (@cSrvEdition LIKE 'Standard%') AND (CAST(LEFT(@cSrvVersion,4) AS REAL) < 10.5)
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''DIFF'', @Verify = ''Y'', @CleanupTime = 168, @CheckSum = ''Y'', @LogToTable = ''Y''" -b';
		ELSE
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''DIFF'', @Verify = ''Y'', @CleanupTime = 168, @Compress=''Y'', @CheckSum = ''Y'', @LogToTable = ''Y''" -b';

		EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseBackup - USER_DATABASES - DIFF', 
				@enabled=1, 
				@notify_level_eventlog=2, 
				@notify_level_email=2, 
				@notify_level_netsend=0, 
				@notify_level_page=0, 
				@delete_level=0, 
				@description=N'Source: http://ola.hallengren.com', 
				@category_name=N'Database Maintenance', 
				@owner_login_name=N'sa', 
				@notify_email_operator_name=@cOperatorName,
				@job_id = @jobId OUTPUT;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - USER_DATABASES - DIFF', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'CmdExec', 
				@command=@cSQLCmmd, 
				@output_file_name=@cOutputFileName, 
				@flags=0;	            

		EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run From Monday To Saturday @ 3 AM', 
				@enabled=1, 
				@freq_type=8, 
				@freq_interval=126, 
				@freq_subday_type=1, 
				@freq_subday_interval=0, 
				@freq_relative_interval=0, 
				@freq_recurrence_factor=1, 
				@active_start_date=20130207, 
				@active_end_date=99991231, 
				@active_start_time=30000, 
				@active_end_time=235959;
				
		EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

		--------------------------------------------------------------------------------------------------------------------------------------------
		-- DatabaseBackup - USER_DATABASES - FULL.
		
		SET @jobId = NULL;
		SET @ReturnCode = NULL;
		SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';
		
		IF LEN(@cOutputFileName) > @iOutputFileNameSize
			RAISERROR('Output file name is too large. Segment - DatabaseBackup - USER_DATABASES - FULL.',16,1);

		-- Dont use compression if version is equal to "Standard" and less than 10.5
		IF (@cSrvEdition LIKE 'Standard%') AND (CAST(LEFT(@cSrvVersion,4) AS REAL) < 10.5)
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 168, @CheckSum = ''Y'', @LogToTable = ''Y''" -b';
		ELSE
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''FULL'', @Verify = ''Y'', @CleanupTime = 168, @Compress=''Y'', @CheckSum = ''Y'', @LogToTable = ''Y''" -b';

		EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseBackup - USER_DATABASES - FULL', 
				@enabled=1, 
				@notify_level_eventlog=2, 
				@notify_level_email=2, 
				@notify_level_netsend=0, 
				@notify_level_page=0, 
				@delete_level=0, 
				@description=N'Source: http://ola.hallengren.com', 
				@category_name=N'Database Maintenance', 
				@owner_login_name=N'sa', 
				@notify_email_operator_name=@cOperatorName,
				@job_id = @jobId OUTPUT;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - USER_DATABASES - FULL', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'CmdExec', 
				@command=@cSQLCmmd, 
				@output_file_name=@cOutputFileName, 
				@flags=0;

		EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Sunday @ 3 AM', 
				@enabled=1, 
				@freq_type=8, 
				@freq_interval=1, 
				@freq_subday_type=1, 
				@freq_subday_interval=0, 
				@freq_relative_interval=0, 
				@freq_recurrence_factor=1, 
				@active_start_date=20130207, 
				@active_end_date=99991231, 
				@active_start_time=30000, 
				@active_end_time=235959;
				
		EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

		--------------------------------------------------------------------------------------------------------------------------------------------
		-- DatabaseBackup - USER_DATABASES - LOG.

		SET @jobId = NULL;
		SET @ReturnCode = NULL;
		SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseBackup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

		IF LEN(@cOutputFileName) > @iOutputFileNameSize
			RAISERROR('Output file name is too large. Segment - DatabaseBackup - USER_DATABASES - LOG.',16,1);

		-- Dont use compression if version is equal to "Standard" and less than 10.5
		IF (@cSrvEdition LIKE 'Standard%') AND (CAST(LEFT(@cSrvVersion,4) AS REAL) < 10.5)
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''LOG'', @Verify = ''Y'', @CleanupTime = 24, @CheckSum = ''Y'', @LogToTable = ''Y''" -b';
		ELSE
			SET @cSQLCmmd = 'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseBackup] @Databases = ''USER_DATABASES'', @Directory = N''' + @cBackupDirectoryName + ''', @BackupType = ''LOG'', @Verify = ''Y'', @CleanupTime = 24, @Compress=''Y'', @CheckSum = ''Y'', @LogToTable = ''Y''" -b';

		EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseBackup - USER_DATABASES - LOG', 
				@enabled=@bLOGBackupEnable, 
				@notify_level_eventlog=2, 
				@notify_level_email=2, 
				@notify_level_netsend=0, 
				@notify_level_page=0, 
				@delete_level=0, 
				@description=N'Source: http://ola.hallengren.com', 
				@category_name=N'Database Maintenance', 
				@owner_login_name=N'sa', 
				@notify_email_operator_name=@cOperatorName,
				@job_id = @jobId OUTPUT;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseBackup - USER_DATABASES - LOG', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'CmdExec', 
				@command=@cSQLCmmd, 
				@output_file_name=@cOutputFileName, 
				@flags=0;

		EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every 5 Mins', 
				@enabled=1, 
				@freq_type=4, 
				@freq_interval=1, 
				@freq_subday_type=4, 
				@freq_subday_interval=5, 
				@freq_relative_interval=0, 
				@freq_recurrence_factor=0, 
				@active_start_date=20130214, 
				@active_end_date=99991231, 
				@active_start_time=0, 
				@active_end_time=235959;
				
		EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

		--------------------------------------------------------------------------------------------------------------------------------------------
		-- sp_delete_backuphistory.

		SET @jobId = NULL;
		SET @ReturnCode = NULL;
		SET @cOutputFileName = @cMaintDirectoryName + '\sp_delete_backuphistory_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

		IF LEN(@cOutputFileName) > @iOutputFileNameSize
			RAISERROR('Output file name is too large. Segment - sp_delete_backuphistory.',16,1);

		EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - sp_delete_backuphistory', 
				@enabled=1, 
				@notify_level_eventlog=2, 
				@notify_level_email=2, 
				@notify_level_netsend=0, 
				@notify_level_page=0, 
				@delete_level=0, 
				@description=N'Source: http://ola.hallengren.com', 
				@category_name=N'Database Maintenance', 
				@owner_login_name=N'sa', 
				@notify_email_operator_name=@cOperatorName,
				@job_id = @jobId OUTPUT;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sp_delete_backuphistory', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, @subsystem=N'CmdExec', 
				@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d msdb -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate" -b', 
				@output_file_name=@cOutputFileName, 
				@flags=0;

		EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

		EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every 2 Months @ 1 AM', 
				@enabled=1, 
				@freq_type=16, 
				@freq_interval=1, 
				@freq_subday_type=1, 
				@freq_subday_interval=0, 
				@freq_relative_interval=0, 
				@freq_recurrence_factor=2, 
				@active_start_date=20130207, 
				@active_end_date=99991231, 
				@active_start_time=10000, 
				@active_end_time=235959;
				
		EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;
	END  

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- Output File Cleanup.

	SET @jobId = NULL;
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\OutputFileCleanup_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - Output File Cleanup.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - Output File Cleanup', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: http://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName,
			@job_id = @jobId OUTPUT;

	IF @bCreateOutputFileCleanupPOSHStep = 1 AND (CAST(LEFT(@cSrvVersion,4) AS REAL) > 9)
	BEGIN
		SET @cSQLCmmd = N'--Script to delete the old files
DECLARE 
	@pscmd VARCHAR(1000)
	, @targetpath VARCHAR(8000)
	, @olddays INT
	, @extension VARCHAR(5)
	, @cmdstring VARCHAR(1000);

--assigning value to parameters, you can customize as per your need
SET @targetpath = ''' + @cMaintDirectoryName + ''';
SET @olddays = -30; --pass the days with negative values 
SET @extension = ''txt'';
SET @pscmd = ''"& Get-ChildItem '' + QUOTENAME(@targetpath,'''''''') + '' | where { $_.lastWriteTime -lt ((Get-Date).AddDays(''+ CAST(@olddays as varchar) +'')) -and ($_.Extension -match '' + QUOTENAME(@extension,'''''''') + '') } | Remove-Item -force"'';
SET @cmdstring = '' ""powershell.exe" ''+ @pscmd;

EXEC master..xp_cmdshell @cmdstring;';  
    
		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Output File Cleanup - POSH Version', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, 
				@subsystem=N'TSQL', 
				@command=@cSQLCmmd, 
				@database_name=N'master',
				@output_file_name=@cOutputFileName ,
				@flags=0;
	END
	ELSE
	BEGIN
		-- This uses CmdExec
		EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Output File Cleanup', 
				@step_id=1, 
				@cmdexec_success_code=0, 
				@on_success_action=1, 
				@on_success_step_id=0, 
				@on_fail_action=2, 
				@on_fail_step_id=0, 
				@retry_attempts=0, 
				@retry_interval=0, 
				@os_run_priority=0, 
				@subsystem=N'CmdExec', 
				--@command=N'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "\\peakbackup01\SQLBackups" /m *_*_*_*.txt /d -30 2^>^&1'') do if EXIST "\\peakbackup01\SQLBackups"\%v echo del "\\peakbackup01\SQLBackups"\%v& del "\\peakbackup01\SQLBackups"\%v"', 
				@command=N'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "\\peakbackup01\SQLBackups\Maintenance_Results_History" /m *_*_*_*.txt /d -30 2^>^&1'') do if EXIST "\\peakbackup01\SQLBackups\Maintenance_Results_History"\%v echo del "\\peakbackup01\SQLBackups\Maintenance_Results_History"\%v& del "\\peakbackup01\SQLBackups\Maintenance_Results_History"\%v"',
				@output_file_name=@cOutputFileName, 
				@flags=0;	
	END  
	
	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Sunday @ 3 AM', 
			@enabled=1, 
			@freq_type=8, 
			@freq_interval=1, 
			@freq_subday_type=1, 
			@freq_subday_interval=0, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=1, 
			@active_start_date=20130207, 
			@active_end_date=99991231, 
			@active_start_time=30000, 
			@active_end_time=235959;
				
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;    

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- DatabaseIntegrityCheck - SYSTEM_DATABASES.

	SET @jobId = NULL;
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseIntegrityCheck_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - DatabaseIntegrityCheck - SYSTEM_DATABASES.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseIntegrityCheck - SYSTEM_DATABASES', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: http://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName,
			@job_id = @jobId OUTPUT;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseIntegrityCheck - SYSTEM_DATABASES', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'CmdExec', 
			@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''SYSTEM_DATABASES'', @LogToTable = ''Y''" -b', 
			@output_file_name=@cOutputFileName, 
			@flags=0;

	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Day @ 1 AM', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=1, 
			@freq_subday_interval=0, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20130207, 
			@active_end_date=99991231, 
			@active_start_time=10000, 
			@active_end_time=235959;
			
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- DatabaseIntegrityCheck - USER_DATABASES.

	SET @jobId = NULL;
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\DatabaseIntegrityCheck_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - DatabaseIntegrityCheck - USER_DATABASES.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - DatabaseIntegrityCheck - USER_DATABASES', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: http://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName,
			@job_id = @jobId OUTPUT;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'DatabaseIntegrityCheck - USER_DATABASES', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'CmdExec', 
			@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE [dbo].[DatabaseIntegrityCheck] @Databases = ''USER_DATABASES'', @LogToTable = ''Y''" -b', 
			@output_file_name=@cOutputFileName, 
			@flags=0;

	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Day @ 1 AM', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=1, 
			@freq_subday_interval=0, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20130207, 
			@active_end_date=99991231, 
			@active_start_time=10000, 
			@active_end_time=235959;
			
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- IndexOptimize - USER_DATABASES.

	SET @jobId = NULL;
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\IndexOptimize_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - IndexOptimize - USER_DATABASES.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - IndexOptimize - USER_DATABASES', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: http://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName,
			@job_id = @jobId OUTPUT;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'IndexOptimize - USER_DATABASES', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'CmdExec', 
			@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d master -Q "EXECUTE dbo.IndexOptimize @Databases = ''USER_DATABASES'', @FragmentationLow = NULL, @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'', @FragmentationLevel1 = 5, @FragmentationLevel2 = 30, @UpdateStatistics = ''ALL'', @LOBCompaction = ''Y'', @LogToTable = ''Y'' " -b', 
			@output_file_name=@cOutputFileName, 
			@flags=0;

	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every Day @ 2 AM', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=1, 
			@freq_subday_interval=0, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20130207, 
			@active_end_date=99991231, 
			@active_start_time=20000, 
			@active_end_time=235959;
			
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- sp_purge_jobhistory.

	SET @jobId = NULL;
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\sp_purge_jobhistory_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - sp_purge_jobhistory.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - OLA - sp_purge_jobhistory', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'Source: http://ola.hallengren.com', 
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName,
			@job_id = @jobId OUTPUT;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'sp_purge_jobhistory', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'CmdExec', 
			@command=N'sqlcmd -E -S $(ESCAPE_SQUOTE(SRVR)) -d msdb -Q "DECLARE @CleanupDate datetime SET @CleanupDate = DATEADD(dd,-30,GETDATE()) EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate" -b', 
			@output_file_name=@cOutputFileName, 
			@flags=0;

	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every 2 Months @ 2 AM', 
			@enabled=1, 
			@freq_type=16, 
			@freq_interval=1, 
			@freq_subday_type=1, 
			@freq_subday_interval=0, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=2, 
			@active_start_date=20130207, 
			@active_end_date=99991231, 
			@active_start_time=20000, 
			@active_end_time=235959;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

	COMMIT TRANSACTION;
END TRY

BEGIN CATCH
	-- Rollback any open transaction.
	IF @@TRANCOUNT > 0
		ROLLBACK;
			
	-- Declare and set sys error info.
	SELECT
		ERROR_PROCEDURE() AS [ERROR_PROCEDURE]
		, ERROR_LINE() AS [ERROR_LINE]
		, ERROR_NUMBER() AS [ERROR_NUMBER]
		, ERROR_MESSAGE() AS [ERROR_MESSAGE]
END CATCH
GO


