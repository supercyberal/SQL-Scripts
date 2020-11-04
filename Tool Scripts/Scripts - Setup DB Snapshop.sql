USE [<DB-Name>]
GO

SET NOCOUNT ON;

-- =============================================================================================================================================
-- Variable declaration.

DECLARE
    -- Flag to execute or show SQL statement.
    @bExecuteSQL BIT = 0

    -- Snapshot DB name to be created.
    , @cDBSnapName SYSNAME = DB_NAME() + N'_Snapshot'

    -- Snapshot DB file extension.
    , @cDBSnapExtName SYSNAME = 'snap'

    -- Variable that holds the dynamic SQL statement.
    , @cSQLStmt NVARCHAR(2048) = '';

-- =============================================================================================================================================
-- Main Script

IF ISNULL(DB_ID(@cDBSnapName),0) > 0
	SET @cSQLStmt = N'DROP DATABASE [' + @cDBSnapName + '];
	' + NCHAR(13);

IF @@ROWCOUNT > 0
    SET @cSQLStmt += N'
CREATE DATABASE [' + @cDBSnapName + '] ON ';
ELSE
    SET @cSQLStmt = N'
CREATE DATABASE [' + @cDBSnapName + '] ON ';

SELECT
    @cSQLStmt += N'
( NAME = ' + [name] + ', FILENAME = ''' + LEFT([filename], LEN([filename]) - 4 ) + '.' + @cDBSnapExtName + ''' ),'
FROM [sys].[sysfiles]
WHERE [status] = 2;

-- Remove last comma from the file creation.
SET @cSQLStmt = LEFT(@cSQLStmt, LEN(@cSQLStmt) - 1);

SET @cSQLStmt += NCHAR(13) + N'AS SNAPSHOT OF [' + DB_NAME() + '];';

-- =============================================================================================================================================
-- Execute SQL statement.

IF @bExecuteSQL = 1
    EXEC [sys].[sp_executesql] @cSQLStmt;
ELSE
    SELECT @cSQLStmt;