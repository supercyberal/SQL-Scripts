/***********************************************************************************************************************************************
Description:	Setup OLA Hallengren's maintenance solution to run in async mode with SQL Server BROKER.
				This was a solution that Jonathan Kahayas has developed. Here are more info about it:
				https://www.sqlskills.com/blogs/jonathan/parallel-maintenance/

Notes:			ACOSTA - 2016-12-16
				Created.

				ACOSTA - 2017-08-10
				Addring drop statements.
***********************************************************************************************************************************************/

USE [msdb];
GO

-- =============================================================================================================================================
-- Drop All.

/*

DROP PROCEDURE [dbo].[OlaHallengrenMaintenanceTaskQueue_ActivationProcedure];
DROP SERVICE [OlaHallengrenMaintenanceTaskService];
DROP QUEUE [dbo].[OlaHallengrenMaintenanceTaskQueue];
DROP CONTRACT [OlaHallengrenMaintenanceTaskContract];
DROP MESSAGE TYPE [OlaHallengrenMaintenanceTaskMessage];
GO

*/

-- =============================================================================================================================================
-- Prep Broker settings.

-- Create the message types
CREATE MESSAGE TYPE [OlaHallengrenMaintenanceTaskMessage]
VALIDATION = WELL_FORMED_XML;
GO

-- Create the contract
CREATE CONTRACT [OlaHallengrenMaintenanceTaskContract] ([OlaHallengrenMaintenanceTaskMessage] SENT BY INITIATOR);
GO
 
-- Create the target queue and service
CREATE QUEUE OlaHallengrenMaintenanceTaskQueue;
GO
 
CREATE SERVICE [OlaHallengrenMaintenanceTaskService]
ON QUEUE OlaHallengrenMaintenanceTaskQueue ([OlaHallengrenMaintenanceTaskContract]);
GO

IF OBJECT_ID('OlaHallengrenMaintenanceTaskQueue_ActivationProcedure') IS NOT NULL
BEGIN
    DROP PROCEDURE OlaHallengrenMaintenanceTaskQueue_ActivationProcedure;
END
GO

-- =============================================================================================================================================
-- Procedure to send commands to the queue.

CREATE PROCEDURE OlaHallengrenMaintenanceTaskQueue_ActivationProcedure
AS
BEGIN
	DECLARE @conversation_handle UNIQUEIDENTIFIER;
	DECLARE @message_body XML;
	DECLARE @message_type_name SYSNAME;
	DECLARE @Command NVARCHAR(MAX);
	DECLARE @ID INT
	DECLARE @DBName SYSNAME;
	DECLARE @ObjectName SYSNAME;
	DECLARE @CommandType NVARCHAR(60);
	DECLARE @Retry INT;
	DECLARE @FQN NVARCHAR(400);
 
	WHILE (1=1)
	BEGIN
		BEGIN TRANSACTION;
 
		WAITFOR
		( RECEIVE TOP(1)
			@conversation_handle = conversation_handle,
			@message_body = message_body,
			@message_type_name = message_type_name
		  FROM OlaHallengrenMaintenanceTaskQueue
		), TIMEOUT 5000;
 
		IF (@@ROWCOUNT = 0)
		BEGIN
			ROLLBACK TRANSACTION;
			BREAK;
		END
 
		IF @message_type_name = N'OlaHallengrenMaintenanceTaskMessage'
		BEGIN
            SELECT  @ID = @message_body.[value]('(CommandLogID)[1]', 'int'),
                    @Retry = ISNULL(@message_body.[value]('(CommandLogID/@retry)[1]', 'int'), 0);
        
            SELECT  @Command = [Command],
                    @ObjectName = [ObjectName],
                    @DBName = [DatabaseName],
                    @FQN = QUOTENAME([DatabaseName]) + '.' + QUOTENAME([SchemaName]) + '.' + QUOTENAME([ObjectName]),
                    @CommandType = [CommandType]
            FROM    [master].[dbo].[CommandLog]
            WHERE   [ID] = @ID;
 
			--  Check for Index rebuilds if one is already running and requeue the request after waiting.
			IF @CommandType = 'ALTER_INDEX'
			BEGIN
				-- Check if we have an incompatible lock that would lead to a failed execution 
				IF EXISTS (
					SELECT 1
					FROM sys.dm_tran_locks AS tl
					WHERE (
						request_mode = 'SCH-M' 
						OR
						-- Concurrent maintenance task doing UpdateStats?
						(
							request_mode = 'LCK_M_SCH_S' 
							AND EXISTS (
								SELECT 1 FROM sys.dm_exec_sessions AS s 
								WHERE is_user_process = 1 AND tl.request_session_id = s.session_id
							)
						)
					)
					AND resource_associated_entity_id = OBJECT_ID(@FQN)
					AND resource_database_id = DB_ID(@DBName) 
				)
				BEGIN
					-- Wait for 5 seconds times the number of retrys to do an incremental backoff
					-- This will eventually cause all queue readers to die off and serial execution of tasks
					DECLARE @Delay NVARCHAR(8) = CAST(DATEADD(ss, @Retry*5, CAST('00:00:00'AS TIME)) AS VARCHAR)
					WAITFOR DELAY @Delay
 
					-- Increment retry count in the message
					SELECT @message_body = N'<CommandLogID retry="'+CAST(@Retry+1 AS NVARCHAR)+'">'+CAST(@id AS NVARCHAR)+N'</CommandLogID>';
 
					-- Send the message back to the queue for later processing
					;SEND ON CONVERSATION @conversation_handle
                    MESSAGE TYPE [OlaHallengrenMaintenanceTaskMessage] (@message_body);
 
					GOTO SkipThisRun
				END
			END
 
			UPDATE master.dbo.CommandLog
			SET StartTime = GETDATE()
			WHERE ID = @ID;
 
			BEGIN TRY 
				EXECUTE(@Command);
 
				UPDATE master.dbo.CommandLog
				SET EndTime = GETDATE()
				WHERE ID = @ID;
			END TRY

			BEGIN CATCH
				UPDATE master.dbo.CommandLog
				SET EndTime = GETDATE(),
					ErrorMessage = ERROR_MESSAGE(),
					ErrorNumber = ERROR_NUMBER()
				WHERE ID = @ID;
			END CATCH
 
			END CONVERSATION @conversation_handle;
		END
 
		-- If end dialog message, end the dialog
		ELSE IF @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog'
		BEGIN
		   END CONVERSATION @conversation_handle;
		END
 
		-- If error message, log and end conversation
		ELSE IF @message_type_name = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error'
		BEGIN
			DECLARE @error INT;
			DECLARE @description NVARCHAR(4000);
 
			-- Pull the error code and description from the doc
			WITH XMLNAMESPACES ('http://schemas.microsoft.com/SQL/ServiceBroker/Error' AS ssb)
			SELECT
				@error = @message_body.value('(//ssb:Error/ssb:Code)[1]', 'INT'),
				@description = @message_body.value('(//ssb:Error/ssb:Description)[1]', 'NVARCHAR(4000)');
         
			RAISERROR(N'Received error Code:%i Description:"%s"', 16, 1, @error, @description) WITH LOG;
 
			-- Now that we handled the error logging cleanup
			END CONVERSATION @conversation_handle;
		END
		  
		SkipThisRun:   
		COMMIT TRANSACTION;
	END
END
GO

-- =============================================================================================================================================
-- Alter the target queue to specify internal activation.

ALTER QUEUE OlaHallengrenMaintenanceTaskQueue
WITH ACTIVATION
( STATUS = ON,
PROCEDURE_NAME = OlaHallengrenMaintenanceTaskQueue_ActivationProcedure,
MAX_QUEUE_READERS = 10,
EXECUTE AS SELF
);
GO

-- =============================================================================================================================================
-- This code needs to go into a Job to be executed.

USE [msdb]
GO

DECLARE @MaxID INT;
SELECT  @MaxID = MAX([ID])
FROM    [master].[dbo].[CommandLog];
 
SELECT  @MaxID = ISNULL(@MaxID, 0);
 
-- Load new tasks into the Command Log

-- All Index and Stats Maintenance
EXECUTE [master].[dbo].[IndexOptimize] 
	@Databases = 'USER_DATABASES'
	, @FragmentationLow = 'INDEX_REBUILD_OFFLINE'
	, @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
	, @FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
	, @FragmentationLevel1 = 10
    , @FragmentationLevel2 = 40
	, @UpdateStatistics = 'ALL'
	, @OnlyModifiedStatistics = 'Y'
	, @LOBCompaction = 'Y'
	, @LogToTable = 'Y'
	, @LockTimeout = 600
	, @PadIndex = 'Y'
	, @SortInTempdb = 'Y'
	, @Execute = 'N';

-- Only Index Maintenace.
/*
EXECUTE [master].[dbo].[IndexOptimize] 
	@Databases = 'USER_DATABASES'
	, @FragmentationLow = 'INDEX_REBUILD_OFFLINE'
	, @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
	, @FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
	, @FragmentationLevel1 = 10
    , @FragmentationLevel2 = 40
	, @LOBCompaction = 'Y'
	, @LogToTable = 'Y'
	, @LockTimeout = 600
	, @PadIndex = 'Y'
	, @SortInTempdb = 'Y'
	, @Execute = 'N';

-- Only Stats Maintenace.
EXECUTE [master].[dbo].[IndexOptimize] 
	@Databases = 'USER_DATABASES'
	, @FragmentationLow = NULL
	, @FragmentationMedium = NULL
	, @FragmentationHigh = NULL
	, @UpdateStatistics = 'ALL'
	, @OnlyModifiedStatistics = 'Y'
	, @LogToTable = 'Y'
	, @LockTimeout = 600
	, @SortInTempdb = 'Y'
	, @Execute = 'N';
*/

DECLARE @NewMaxID INT;
SELECT  @NewMaxID = MAX([ID])
FROM    [master].[dbo].[CommandLog];
 
USE [msdb];
 
DECLARE @id INT;
 
-- Don't submit commands  in exact command order or parallel processing
-- of indexes/stats on same object will occur and could block
DECLARE [command_cursor] CURSOR FAST_FORWARD LOCAL
FOR
SELECT  [t].[ID]
FROM    ( SELECT    ROW_NUMBER() OVER ( PARTITION BY [ObjectName] ORDER BY COALESCE([IndexName], [StatisticsName]), [CommandType] ) AS [Ranking],
                    [ID]
            FROM      [master].[dbo].[CommandLog]
            WHERE     [ID] > @MaxID
                    AND [ID] <= @NewMaxID
        ) AS [t]
ORDER BY [t].[Ranking];
 
OPEN [command_cursor];
 
FETCH NEXT FROM [command_cursor]
INTO @id;
 
WHILE @@FETCH_STATUS = 0
BEGIN 
	-- Begin a conversation and send a request message
    DECLARE @conversation_handle UNIQUEIDENTIFIER;
    DECLARE @message_body XML;
 
    BEGIN TRANSACTION;
 
    BEGIN DIALOG @conversation_handle
	FROM SERVICE [OlaHallengrenMaintenanceTaskService]
	TO SERVICE N'OlaHallengrenMaintenanceTaskService'
	ON CONTRACT [OlaHallengrenMaintenanceTaskContract]
	WITH ENCRYPTION = OFF;
 
    SELECT  @message_body = N'<CommandLogID>' + CAST(@id AS NVARCHAR) + N'</CommandLogID>';
 
    SEND ON CONVERSATION @conversation_handle
	MESSAGE TYPE [OlaHallengrenMaintenanceTaskMessage]
	(@message_body);
 
    COMMIT TRANSACTION;
 
	-- Get the next command to run
    FETCH NEXT FROM [command_cursor] INTO @id;
END;

CLOSE [command_cursor];
DEALLOCATE [command_cursor];
GO