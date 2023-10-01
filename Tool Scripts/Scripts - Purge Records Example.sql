SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
GO

/***********************************************************************************************************************************************
# Stored Procedure: spPurgeEventLogs

# Purpose:
- Delete old event log records. Default is 365 days.

# Returns:
N/A

# Parameters: 
@iNumDaysToKeep		- Optional - Number of days to keep in the log. Minimum is 365 days.
@iTotalMinutesToRun - Optional - Total number of minutes for this process to run. Default is 5 and max is 60 minutes.
@iDeleteBatchSize	- Optional - Number of records to be purged per iteration. Default is 1000 records and max is 10000.
@bReturnCount		- Optional. If true (1), then the proc will return the statement counts. Default value is false (0).

# Tables/Views: 
- [dbo].[EventLog]

# Notes:
- ACOSTA - 2013-03-14
***********************************************************************************************************************************************/

CREATE PROCEDURE [dbo].[spPurgeEventLogs]
	@iNumDaysToKeep INT = 365
	, @iTotalMinutesToRun INT = 5
	, @iDeleteBatchSize INT = 1000
	, @bReturnCount BIT = 0
AS
BEGIN
	BEGIN TRY
		-- =====================================================================================================================================
		-- Set the NOCOUNT based on the @bReturnCount variable. This is just for debugging pruposes.
              
		IF @bReturnCount = 0
			SET NOCOUNT ON;

		-- =====================================================================================================================================
		-- Inforce arguments if values aren't passed.

		-- Keep 30 days minumum.
		IF (@iNumDaysToKeep < 30) OR (@iNumDaysToKeep IS NULL)
			SET @iNumDaysToKeep = 30;
                     
		-- =====================================================================================================================================
		-- Local variable declaration and initial values.             
              
		DECLARE 
			@cDelay VARCHAR(20) = '000:00:00.500'    -- delay between each SQL action
			, @iTotalToBeDone INT = 0  -- Total count of records that will be affected
			, @iTotalDone INT = 0      -- Total count of records affected, increments with each SQL action
			, @iResultCount INT        -- Count of records affected by last SQL action (@@ROWCOUNT)
			, @tStart DATETIME = GETDATE()
			, @dStopAtTime DATETIME
			, @nSecondsPerRow DECIMAL(12, 6)
			, @iSecondsToCount INT = 0
			, @iMaxRunMinutesAllowed INT = 60
			, @iDeleteBatchMaxAllowed INT = 10000
			, @iTotalElpasedSeconds INT = 0
			, @dDateToPurge DATETIME = DATEADD(dd,-@iNumDaysToKeep,GETDATE()); -- Date to start purging records

		-- =====================================================================================================================================
		-- Failsafes.
              
		IF @iDeleteBatchSize > @iDeleteBatchMaxAllowed
		BEGIN
			SET @iDeleteBatchSize = @iDeleteBatchMaxAllowed;
			PRINT 'Maximum batch size exceeded and was set to ' + CAST(@iDeleteBatchMaxAllowed AS VARCHAR);
		END

		IF @iTotalMinutesToRun > @iMaxRunMinutesAllowed
		BEGIN
			SET @iTotalMinutesToRun = @iMaxRunMinutesAllowed;
			PRINT 'Maximum run time minutes exceeded and was set to ' + CAST(@iMaxRunMinutesAllowed AS VARCHAR);
		END
                                  
		-- =====================================================================================================================================              
		-- Check to see if we have handheldlog records to be purged.
              
		SELECT
			@iTotalToBeDone = COUNT(*)
		FROM [dbo].[EventLog] el
		WHERE [date] < @dDateToPurge;
              
		-- =====================================================================================================================================
		-- Main block.
              
		IF @iTotalToBeDone > 0
		BEGIN
			------------------------------------------------------------------------------------------------------------------------------------
			-- Calculate and print initial batch operation stats.
                     
			PRINT 'Started at: ' + CAST(@tStart AS VARCHAR);
			PRINT 'Total minutes to run:' + CAST(@iTotalMinutesToRun AS VARCHAR);
			PRINT '# of records to delete in each batch: ' + CAST(@iDeleteBatchSize AS VARCHAR);                     
			PRINT 'Total To Be Done:' + CAST(@iTotalToBeDone AS VARCHAR);              
                     
			SET @iSecondsToCount = DATEDIFF(s, @tStart, GETDATE());
			PRINT 'Seconds to Count Total To Be Done: ' + CAST(@iSecondsToCount AS VARCHAR);

			SET @dStopAtTime = DATEADD(mi, @iTotalMinutesToRun, GETDATE());      -- only run for X minutes
			PRINT 'Run until: ' + CAST(@dStopAtTime AS VARCHAR);
                     
			------------------------------------------------------------------------------------------------------------------------------------
			-- Loop until the stop time has reached.
              
			WHILE ( GETDATE() < @dStopAtTime )
			BEGIN
				PRINT '*Start batch: ' + CAST(GETDATE() AS VARCHAR);
                                  
				--------------------------------------------------------------------------------------------------------------------------------
				-- Purge the data.
                           
				BEGIN TRAN;
                           
				DELETE TOP (@iDeleteBatchSize) FROM [dbo].[EventLog]	--Table to delete from
				WHERE [date] < @dDateToPurge;								--Field to check against
                     
				SET @iResultCount = @@ROWCOUNT;
                           
				COMMIT;                    
                           
				SET @iTotalDone = @iTotalDone + @iResultCount;
                           
				-- If we deleted less than the batch size we are done
				IF @iResultCount < @iDeleteBatchSize
					BREAK;
              
				--------------------------------------------------------------------------------------------------------------------------------
				-- Pause to let other transactions get locks.
                           
				WAITFOR DELAY @cDelay;
			END
                     
			------------------------------------------------------------------------------------------------------------------------------------
			-- Print end batch operation stats.
                
			PRINT 'Ended at: ' + CAST(GETDATE() AS VARCHAR);
			PRINT 'Total Done: ' + CAST(@iTotalDone AS VARCHAR);

			SET @iTotalElpasedSeconds = DATEDIFF(s, @tStart, GETDATE());
			PRINT 'Total time to delete (Seconds): ' + CAST(@iTotalElpasedSeconds AS VARCHAR);
                     
			IF (@iTotalDone <> 0)
				SET @nSecondsPerRow = CAST(@iTotalElpasedSeconds - @iSecondsToCount AS DECIMAL(12,6)) / CAST(@iTotalDone AS DECIMAL(12, 6));
			ELSE
				SET @nSecondsPerRow = 0;

			PRINT 'Estimated total time that would be required: ' + dbo.ConvertSecondsToHHMMSS(@nSecondsPerRow * @iTotalToBeDone);
		END    
	END TRY       
       
	BEGIN CATCH
		-- Rollback any open transaction.
		IF @@TRANCOUNT > 0
			ROLLBACK;

		-- Error messages variables.
		DECLARE 
			@ErrorState INT
			, @ErrorSeverity INT			
			, @ErrorMessage NVARCHAR(4000);

		SELECT 
			@ErrorMessage = ERROR_MESSAGE()
			, @ErrorSeverity = ERROR_SEVERITY()
			, @ErrorState = ERROR_STATE();					
                     
		-- Declare and set sys error info.
		IF @bReturnCount = 1
			SELECT 
				ERROR_PROCEDURE() AS [ERROR_PROCEDURE]
				, ERROR_LINE() AS [ERROR_LINE]
				, ERROR_NUMBER() AS [ERROR_NUMBER]
				, @ErrorSeverity AS [ERROR_SEVERITY]
				, @ErrorState AS [ERROR_STATE]
				, @ErrorMessage AS [ERROR_MESSAGE]
		ELSE
			RAISERROR(@ErrorMessage,@ErrorSeverity,@ErrorState);
	END CATCH
END
GO
