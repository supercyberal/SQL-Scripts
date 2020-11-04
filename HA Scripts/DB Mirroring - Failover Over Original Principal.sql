/*
Scripted provided by @SQLSoldier
http://www.sqlsoldier.com/wp/sqlserver/databasemirroringautomation
*/

USE master
GO

IF EXISTS ( SELECT  1
            FROM    Information_schema.Routines
            WHERE   Routine_Name = 'dba_FailoverMirrorToOriginalPrincipal'
                    AND Routine_Schema = 'dbo'
                    AND Routine_Type = 'Procedure' )
    DROP PROCEDURE dbo.dba_FailoverMirrorToOriginalPrincipal
Go

CREATE PROCEDURE dbo.dba_FailoverMirrorToOriginalPrincipal	
	@DBName SYSNAME = NULL -- database to fail back; all applicable databases if null
	, @Debug BIT = 0 -- 0 = Execute it, 1 = Output SQL that would be executed
AS
BEGIN
    DECLARE
		@SQL NVARCHAR(200)
		, @MaxID INT
        , @CurrID INT;

    DECLARE @MirrDBs TABLE (
		MirrDBID INT IDENTITY(1, 1) NOT NULL PRIMARY KEY
        , DBName SYSNAME NOT NULL
	);

    SET NOCOUNT ON;

	-- If database is in the principal role
	-- and is in a synchronized state,
	-- fail database back to original principal
    INSERT INTO @MirrDBs (DBName)
	SELECT DB_NAME(database_id)    
    FROM    sys.database_mirroring
    WHERE   mirroring_role = 1 -- Principal partner
            AND mirroring_state = 4 -- Synchronized
            AND mirroring_safety_level = 2 -- Safety full
            AND (
				database_id = DB_ID(@DBName)
                OR @DBName IS NULL
			);

	-- Set the variables appropriatelly.
	SET @CurrID = 1;

    SELECT  @MaxID = MAX(MirrDBID)
    FROM    @MirrDBs;

    WHILE @CurrID <= @MaxID
    BEGIN
        SELECT  @DBName = DBName
        FROM    @MirrDBs
        WHERE   MirrDBID = @CurrID
	
        SET @SQL = 'ALTER DATABASE ' + QUOTENAME(@DBName) + ' SET PARTNER FAILOVER;'

        IF @Debug = 0            
			EXEC sp_executesql @SQL;
        ELSE
            PRINT @SQL;
	
        SET @CurrID = @CurrID + 1
    END

    SET NOCOUNT OFF;
END
GO

-- =============================================================================================================================================
-- JOB CREATION
-- =============================================================================================================================================

USE [msdb]
GO

IF EXISTS (SELECT 1 FROM [msdb]..[sysjobs] WHERE [name] = 'DBA Mirroring - Failover Mirror To Original Principal')
	EXEC msdb.dbo.sp_delete_job 
		@job_name = 'DBA Mirroring - Failover Mirror To Original Principal'
		, @delete_unused_schedule = 1;
GO

/****** Object:  Job [DBA Mirroring - Failover Mirror To Original Principal]    Script Date: 12/05/2013 14:52:03 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [Maintenance Jobs]    Script Date: 12/05/2013 14:52:03 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'Maintenance Jobs' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'Maintenance Jobs'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'DBA Mirroring - Failover Mirror To Original Principal', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'This is to make sure that Mirroring is always failing to the Original DB server.', 
		@category_name=N'Maintenance Jobs', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [Run FailOver Proc]    Script Date: 12/05/2013 14:52:03 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Run FailOver Proc', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.dba_FailoverMirrorToOriginalPrincipal;', 
		@database_name=N'master', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Run Every 2 Hours', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=8, 
		@freq_subday_interval=2, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20130214, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'c91bcf80-ed6a-4b04-8fef-c0afaa8dbdf3'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:

GO
