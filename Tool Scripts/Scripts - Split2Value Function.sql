USE master
GO

/***********************************************************************************************************************************************
= Function: Split2Value

= Purpose:
Returns a table from a string list defined by the passed delimiter. This is compatible with SQL-Server 2008+.

= Returns:
Table @TableOfValues.

= Parameters:
- @Delimiter	- Required. List delimiter.
- @List			- Required. List to be scanned.

= Tables/Views:
N/A

= Used Functions/Procs:
N/A

= Notes:
- ACOSTA - 2013-03-07 = Created
***********************************************************************************************************************************************/


CREATE FUNCTION [dbo].[Split2Value] (@Delimiter VARCHAR(5), @List VARCHAR(MAX))
RETURNS @TableOfValues TABLE (
	RowID INT IDENTITY(1, 1)
	, [Value] VARCHAR(MAX)
)
AS
BEGIN
	-- =========================================================================================================================================
	-- Variable declaration and initial values.

	DECLARE	
		@LenString INT = 0;

	-- =========================================================================================================================================
	-- Main block.

	WHILE LEN(@List) > 0
	BEGIN
		-- Get the last character location for each element.
		SET @LenString = (
			CASE CHARINDEX(@Delimiter, @List)
				WHEN 0 THEN LEN(@List)
			ELSE 
				(CHARINDEX(@Delimiter,@List) - 1)
			END 
		);

		-- Insert value into table.
		INSERT INTO @TableOfValues ([Value])
		SELECT 
			SUBSTRING(@List, 1, @LenString)
		WHERE @LenString > 0;

		-- Remove already add element from list.
		SET @List = ( 
			CASE (LEN(@List) - @LenString)
				WHEN 0 THEN ''
			ELSE 
				RIGHT(@List,LEN(@List) - @LenString - 1)
			END 
		); 
	END 

	RETURN;
END