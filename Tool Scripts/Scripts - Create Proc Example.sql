USE <DBName>
GO

/***********************************************************************************************************************************************
# Stored Procedure: <TYPE_PROC_NAME>

# Purpose:
<TYPE_DESCRIPTION>

# Returns:
N/A

# Parameters: 
@bDebug - Optional. If true (1), then the proc will return the statement counts. Default value is false (0).

# Tables/Views: 

# Notes:
- ACOSTA - 
***********************************************************************************************************************************************/

CREATE PROCEDURE [dbo].
	, @bDebug BIT = 0
AS
BEGIN
	BEGIN TRY
		-- =====================================================================================================================================
		-- Set the NOCOUNT based on the @bDebug variable. This is just for debugging pruposes.
              
		IF (@bDebug = 0) OR (@bDebug IS NULL)
			SET NOCOUNT ON;

		-- =====================================================================================================================================
		-- Inforce arguments if values aren't passed.
                     
		-- =====================================================================================================================================
		-- Local variable declaration and initial values.
              
		-- =====================================================================================================================================
		-- Main block.		 
	END TRY       
       
	BEGIN CATCH
		-- Rollback any open transaction.
		IF @@TRANCOUNT > 0
			ROLLBACK;
                     
		-- Declare and set sys error info.
		DECLARE
			@cErrorLine INT = ERROR_LINE()
			, @cErrorNumber INT = ERROR_NUMBER()
			, @cErrorMsg NVARCHAR(4000) = ERROR_MESSAGE()
			, @cErrorProc NVARCHAR(128) = ERROR_PROCEDURE();			

		-- Show message for debugging purposes.
		IF @bDebug = 1
			SELECT 
				@cErrorLine AS [ERROR_LINE]
				, @cErrorNumber AS [ERROR_NUMBER]
				, @cErrorProc AS [ERROR_PROCEDURE]
				, @cErrorMsg AS [ERROR_MESSAGE]
		-- Custom erros.
		ELSE IF @cErrorNumber >= 50000
			THROW @cErrorNumber, @cErrorMsg, 1
		-- System errors.
		ELSE
			THROW;
	END CATCH
END
GO
