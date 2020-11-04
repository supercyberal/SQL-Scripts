/***********************************************************************************************************************************************
Description:	Returns a table from a list delimited value.

Notes:			ACOSTA - 2014-03-04
				Created.
***********************************************************************************************************************************************/

USE master
GO

IF EXISTS (SELECT 1 FROM sys.[objects] WHERE [type] = 'TF' AND [name] = 'fn_List2Table')
	DROP FUNCTION [dbo].[fn_List2Table];
GO	

CREATE FUNCTION dbo.fn_List2Table (
	@List VARCHAR(MAX)
	, @Delim CHAR
)
RETURNS @ParsedList TABLE (item VARCHAR(MAX))
AS
BEGIN
    DECLARE 
		@item VARCHAR(MAX)
        ,@Pos INT

    SET @List = LTRIM(RTRIM(@List)) + @Delim
    SET @Pos = CHARINDEX(@Delim, @List, 1)

    WHILE @Pos > 0
    BEGIN
        SET @item = LTRIM(RTRIM(LEFT(@List, @Pos - 1)))

        IF @item <> ''
        BEGIN
            INSERT  INTO @ParsedList (item)
            VALUES  (CAST(@item AS VARCHAR(MAX)))
        END

        SET @List = RIGHT(@List, LEN(@List) - @Pos)
        SET @Pos = CHARINDEX(@Delim, @List, 1)
    END

    RETURN
END
GO