USE master
GO
	
/*==============================================================================================================================================
# Stored Procedure: spInstanceInitSettings

# Purpose:
Responsible for creating instance initialization settings.

# Returns:
N/A

# Parameters: 
N/A

# Tables/Views: 
N/A

# Notes:
- ACOSTA - 2013-11-11
	Created.
==============================================================================================================================================*/

IF OBJECT_ID('spInstanceInitSettings') IS NOT NULL
    DROP PROCEDURE spInstanceInitSettings;
GO
		
CREATE PROC [dbo].[spInstanceInitSettings]
AS
BEGIN
	BEGIN TRY
		-- Turn trace flag 1118 ON for tempdb extent allocation.
		DBCC TRACEON (1118, -1);
		
		-- Settings needed if tool "dbWarden" exists in Instance.
		IF EXISTS (SELECT 1 FROM sys.[databases] WHERE [name] = 'dbWarden')
		BEGIN
			-- Turn trace flag 1222 ON to track deadlock details.
			DBCC TRACEON (1222, -1);
		END
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
END
GO

-- Make sure that this is turned on when the instance starts up.
EXEC [sys].[sp_configure] @configname = 'show advanced option', @configvalue = 1
GO
RECONFIGURE
GO

EXEC [sys].[sp_configure] @configname = 'scan for startup procs', @configvalue = 1
GO
RECONFIGURE
GO

-- Associate master proc spInstanceInitSettings.
EXEC [sys].[sp_procoption] 
	@ProcName = N'spInstanceInitSettings', -- nvarchar(776)
    @OptionName = 'startup', -- varchar(35)
    @OptionValue = 'on' -- varchar(12)
GO

EXEC [sys].[sp_configure] @configname = 'show advanced option', @configvalue = 0
GO
RECONFIGURE
GO