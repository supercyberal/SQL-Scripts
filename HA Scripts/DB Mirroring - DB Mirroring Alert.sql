/***********************************************************************************************************************************************
Description:	Database Mirroring Alerts
				Reference article: http://www.mssqltips.com/sqlservertip/1859/monitoring-sql-server-database-mirroring-with-email-alerts/

Notes:
ACOSTA - 2013-09-23
	Created.
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
	, @cMaintDirectoryName sysname	
	, @iOutputFileNameSize INT
	, @cOperatorName NVARCHAR(256)
	
SET	@iCount = 1;
SET @iCountTotalJobs = 0;
SET @ReturnCode = 0;
SET @cMaintDirectoryName = 'G:\Maintenance_History';
SET @iOutputFileNameSize = (SELECT CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'output_file_name');

/*Custom Variables*/

-- Set which operator to be notified.
SET @cOperatorName = N'IT-Databases';

-----------------------------------------------------------------------------------------------------------------------------------------------
-- Job Creation

DECLARE @tblJobs TABLE (
	Id INT IDENTITY(1,1) NOT NULL
	, JobName sysname NOT NULL
);
INSERT INTO @tblJobs (JobName) VALUES ('DBA Maint - DB Mirroring Alert');

SELECT @iCountTotalJobs = COUNT(*) FROM @tblJobs tj;

WHILE @iCount <= @iCountTotalJobs
BEGIN
	SELECT @cDBName = JobName FROM @tblJobs tj WHERE Id = @iCount;

	IF EXISTS(SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @cDBName)
		EXEC msdb.dbo.sp_delete_job @job_name = @cDBName, @delete_unused_schedule=1;	

	SET @iCount = @iCount + 1;
END

BEGIN TRY
	BEGIN TRANSACTION;

	IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Database Maintenance' AND category_class=1)
	BEGIN
		EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Database Maintenance';
	END
	
	SET @ReturnCode = NULL;
	SET @cOutputFileName = @cMaintDirectoryName + '\DBMirrorAlert_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt';	 

	IF LEN(@cOutputFileName) > @iOutputFileNameSize
		RAISERROR('Output file name is too large. Segment - CommandLog Cleanup Job.',16,1);

	EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Maint - DB Mirroring Alert', 
			@enabled=1, 
			@notify_level_eventlog=2, 
			@notify_level_email=2, 
			@notify_level_netsend=0, 
			@notify_level_page=0, 
			@delete_level=0, 
			@description=N'No description available.', 		
			@category_name=N'Database Maintenance', 
			@owner_login_name=N'sa', 
			@notify_email_operator_name=@cOperatorName, 
			@job_id = @jobId OUTPUT

	EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run Script', 
			@step_id=1, 
			@cmdexec_success_code=0, 
			@on_success_action=1, 
			@on_success_step_id=0, 
			@on_fail_action=2, 
			@on_fail_step_id=0, 
			@retry_attempts=0, 
			@retry_interval=0, 
			@os_run_priority=0, @subsystem=N'TSQL', 
			@command=N'IF OBJECT_ID(''TempDB..#Databases'') IS NOT NULL
	DROP TABLE #Databases;

CREATE TABLE #Databases (
	DBID INT NOT NULL
	, mirroring_state_desc VARCHAR(30) NULL

	PRIMARY KEY CLUSTERED (DBID)
);

DECLARE 
	@DbId INT
	, @DbMirrored INT
	, @State VARCHAR(30)	
	, @String VARCHAR(100)
	, @EmailSubject VARCHAR(64);

SET @EmailSubject = ''DBA ALERT - Database Mirroring - ['' + @@SERVERNAME + '']'';
 
-- get status for mirrored databases
INSERT #Databases
	SELECT  database_id
			,mirroring_state_desc
	FROM    sys.database_mirroring
	WHERE   mirroring_role_desc IN (''PRINCIPAL'', ''MIRROR'')
			AND mirroring_state_desc NOT IN (''SYNCHRONIZED'', ''SYNCHRONIZING'');
 
-- iterate through mirrored databases and send email alert
WHILE EXISTS (SELECT TOP 1 DBID FROM #Databases WHERE mirroring_state_desc IS NOT NULL)
BEGIN
	SELECT TOP 1 
		@DbId = DBID
		, @State = mirroring_state_desc
	FROM #Databases;

	SET @String = ''Host: '' + @@SERVERNAME + ''.'' + CAST(DB_NAME(@DbId) AS VARCHAR) + '' - DB Mirroring is '' + @State + '' - Notify DBA''

	EXEC msdb.dbo.sp_send_dbmail
		@profile_name = ''Primary''		
		, @recipients = ''IT-Databases@hklaw.com''
		, @subject = @EmailSubject
		, @body_format = ''HTML''
		, @body = @String;

	DELETE FROM #Databases WHERE DBID = @DbId;
END
 
--also alert if there is no mirroring just in case there should be mirroring :)
SELECT  @DbMirrored = COUNT(*)
FROM    sys.database_mirroring
WHERE   mirroring_state IS NOT NULL;

IF @DbMirrored = 0
BEGIN
	SET @String = ''Host: ''+ @@SERVERNAME + '' - No databases are mirrored on this server - Notify DBA''

	EXEC msdb.dbo.sp_send_dbmail
		@profile_name = ''Primary''		
		, @recipients = ''IT-Databases@hklaw.com''
		, @subject = @EmailSubject
		, @body_format = ''HTML''
		, @body = @String;
END', 
			@database_name=N'master', 
			@output_file_name=@cOutputFileName, 
			@flags=0

	EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1;

	EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every 10 Minutes', 
			@enabled=1, 
			@freq_type=4, 
			@freq_interval=1, 
			@freq_subday_type=4, 
			@freq_subday_interval=10, 
			@freq_relative_interval=0, 
			@freq_recurrence_factor=0, 
			@active_start_date=20130924, 
			@active_end_date=99991231, 
			@active_start_time=0, 
			@active_end_time=235959
			
	EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = @@SERVERNAME;

	COMMIT;
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

-----------------------------------------------------------------------------------------------------------------------------------------------
-- Code Creation.
/*

USE master
GO

IF OBJECT_ID('TempDB..#Databases') IS NOT NULL
	DROP TABLE #Databases;

CREATE TABLE #Databases (
	DBID INT NOT NULL
	, mirroring_state_desc VARCHAR(30) NULL

	PRIMARY KEY CLUSTERED (DBID)
);

DECLARE 
	@DbId INT
	, @DbMirrored INT
	, @State VARCHAR(30)	
	, @String VARCHAR(100)
	, @EmailSubject VARCHAR(64);

SET @EmailSubject = 'DBA ALERT - Database Mirroring - [' + @@SERVERNAME + ']';
 
-- get status for mirrored databases
INSERT #Databases
    SELECT  database_id
           ,mirroring_state_desc
    FROM    sys.database_mirroring
    WHERE   mirroring_role_desc IN ('PRINCIPAL', 'MIRROR')
            AND mirroring_state_desc NOT IN ('SYNCHRONIZED', 'SYNCHRONIZING');
 
-- iterate through mirrored databases and send email alert
WHILE EXISTS (SELECT TOP 1 DBID FROM #Databases WHERE mirroring_state_desc IS NOT NULL)
BEGIN
	SELECT TOP 1 
		@DbId = DBID
		, @State = mirroring_state_desc
	FROM #Databases;

	SET @String = 'Host: ' + @@SERVERNAME + '.' + CAST(DB_NAME(@DbId) AS VARCHAR) + ' - DB Mirroring is ' + @State + ' - Notify DBA'

	EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'Primary'		
		, @recipients = 'IT-Databases@hklaw.com'
		, @subject = @EmailSubject
		, @body_format = 'HTML'
		, @body = @String;

	DELETE FROM #Databases WHERE DBID = @DbId;
END
 
--also alert if there is no mirroring just in case there should be mirroring :)
SELECT  @DbMirrored = COUNT(*)
FROM    sys.database_mirroring
WHERE   mirroring_state IS NOT NULL;

IF @DbMirrored = 0
BEGIN
	SET @String = 'Host: '+ @@SERVERNAME + ' - No databases are mirrored on this server - Notify DBA'

	EXEC msdb.dbo.sp_send_dbmail
		@profile_name = 'Primary'		
		, @recipients = 'IT-Databases@hklaw.com'
		, @subject = @EmailSubject
		, @body_format = 'HTML'
		, @body = @String;
END

*/