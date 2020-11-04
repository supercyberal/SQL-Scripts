USE [master]
GO

/***********************************************************************************************************************************************
# Stored Procedure: spKillSessions

# Purpose:
- Kills any

# Returns:
N/A

# Parameters: 
@DBName		- Optional - Number of days to keep in the log. Minimum is 365 days.
@bDebug		- Optional - If true (1), then the proc will return the statement counts. Default value is false (0).

# Tables/Views: 
- [sys].[sysprocesses]

# Notes:	ACOSTA - 2017-04-18
			Created.
***********************************************************************************************************************************************/

CREATE PROCEDURE [dbo].[spKillSessions]
	@DBName SYSNAME
	, @bDebug BIT = 0
AS
BEGIN
	BEGIN TRY
		-- =====================================================================================================================================
		-- Set the NOCOUNT based on the @bDebug variable. This is just for debugging pruposes.
              
		IF @bDebug = 0
			SET NOCOUNT ON;

		-- =====================================================================================================================================
		-- Argument checks.

		IF @DBName IS NULL
			THROW 51000, 'Argument @DBName is null.', 1;

		IF NOT EXISTS (SELECT 1 FROM [sys].[databases] AS [d] WHERE [d].[name] = @DBName)
			THROW 51000, 'Database doesn''t exist in this instance.', 1;

		-- =====================================================================================================================================
		-- Local variable declaration and initial values.             
              
		DECLARE @cSQL NVARCHAR(1024) = '';
		             
		-- =====================================================================================================================================
		-- Main block.

		SELECT
			@cSQL += 'KILL ' + CAST([s].[spid] AS NVARCHAR(8)) + ';' + NCHAR(13)
		FROM [sys].[sysprocesses] AS [s]
		WHERE [s].[dbid] = DB_ID(@DBName)
		-- Only user defined sessions.
		AND [s].[spid] > 50
		-- Any open session but itself.
		AND [s].[spid] <> @@SPID;

		-- Kill the sessions.
		EXEC [sys].[sp_executesql] @cSQL;
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
		IF @bDebug = 1
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
