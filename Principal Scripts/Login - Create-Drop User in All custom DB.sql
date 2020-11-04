/***********************************************************************************************************************************************
Description:	Create or Drop DB users from Login in all custom DBs. Also, has the ability to add to DB role.

Notes:
ACOSTA - 2013-09-19
	Created.

ACOSTA - 2015-01-30
    Added variable @sDBListName to include a list of DBs as an option to the entire DB list.

ACOSTA - 2015-08-14
    Adding model DB as part of DBs to be excluded.
***********************************************************************************************************************************************/

USE master
GO

SET NOCOUNT ON

DECLARE
    @iCount INT
    , @bExecQuery BIT
    , @bDropLogin BIT
    , @bCreateUser BIT    
    , @iTotalDBRoles INT
    , @sSQLStmt NVARCHAR(MAX)
    , @sLoginName VARCHAR(128)
    , @sDBRoleName VARCHAR(128);	

IF OBJECT_ID('TempDB..##DBExclusions') IS NOT NULL
    DROP TABLE ##DBExclusions;

CREATE TABLE ##DBExclusions (
    DBName SYSNAME NOT NULL
);

DECLARE @tblDBRoles TABLE (
    ID INT IDENTITY(1,1)
    , RoleName SYSNAME NOT NULL
);

-- Local variables.
SET @iCount = 1;
SET @iTotalDBRoles = 0;

-- If 0 then statement is printed out to the console, otherwise, it executes.
SET @bExecQuery = 0;

-- Login name with the begining and ending brackets. Ex.: [DOMAIN\account]
SET @sLoginName = '[]'

-- If set to 1, then we create a user in DBs.
SET @bCreateUser = 0;

-- If set to 1, then we drop the login.
SET @bDropLogin = 0;

-- If populated and we're creating a user, then it will apply these DB roles.
-- DB role. Ex.: db_datareader, db_datawriter, db_ddladmin, db_owner.
/*
INSERT @tblDBRoles ([RoleName])
VALUES
    ('')
    -- Add more DB roles.
    --, ('')

SET @iTotalDBRoles = @@ROWCOUNT;
*/

-- Use this to restrict ONLY the DBs that you want.
/*
INSERT ##DBExclusions ([DBName])
VALUES
    ('')
    -- Add more DBs.
    --, ('')
*/

IF @sLoginName IS NOT NULL
BEGIN
    -- Prep login SQL string.
    IF EXISTS (SELECT 1 FROM ##DBExclusions)
	   SET @sSQLStmt = '
USE [?]
IF EXISTS (
    SELECT 1 FROM ##DBExclusions
    WHERE [DBName] = DB_NAME()	
    AND NOT EXISTS (
	   SELECT 1 FROM sys.[databases]
	   WHERE [name] = DB_NAME()
	   AND [is_read_only] = 1
    )
)
BEGIN';
    ELSE	
	   SET @sSQLStmt = '
USE [?]
IF (
	DB_NAME() NOT IN (''master'',''msdb'',''master'',''tempdb'',''AuditLog'',''dbWarden'',''model'')
	AND NOT EXISTS (
		SELECT 1 FROM sys.[databases]
		WHERE [name] = DB_NAME()
		AND [is_read_only] = 1
	)
)
BEGIN';
	
	-- Determine if we need to create or drop a user.
	IF @bCreateUser = 1
	BEGIN
		SET @sSQLStmt = @sSQLStmt + '
	IF NOT EXISTS(SELECT 1 FROM sys.[sysusers] WHERE [name] = ''' + REPLACE(REPLACE(@sLoginName,'[',''),']','') + ''')		
		CREATE USER ' + @sLoginName + ' FROM LOGIN ' + @sLoginName + ';
		';
	END
	ELSE
	BEGIN
		SET @sSQLStmt = @sSQLStmt + '
	IF ((SELECT SUSER_SNAME(sid) FROM sys.database_principals WHERE name = ''dbo'') = ''' + REPLACE(REPLACE(@sLoginName,'[',''),']','') + ''')
		EXEC [sys].[sp_changedbowner] @loginame = ''sa'';
		';

		SET @sSQLStmt = @sSQLStmt + '
	IF EXISTS(SELECT 1 FROM sys.[schemas] WHERE [name] = ''' + REPLACE(REPLACE(@sLoginName,'[',''),']','') + ''')
		DROP SCHEMA ' + @sLoginName + ';

	IF EXISTS(SELECT 1 FROM sys.[sysusers] WHERE [name] = ''' + REPLACE(REPLACE(@sLoginName,'[',''),']','') + ''')
		DROP USER ' + @sLoginName + ';';
	END	

	-- Prep DB role string.
    IF EXISTS (SELECT 1 FROM @tblDBRoles) AND (@bCreateUser = 1)
    BEGIN
	   WHILE @iCount <= @iTotalDBRoles
	   BEGIN
		  SELECT @sDBRoleName = [RoleName] FROM @tblDBRoles WHERE [ID] = @iCount;

		  SET @sSQLStmt = @sSQLStmt + '
    EXEC [sys].[sp_addrolemember] @rolename = ''' + @sDBRoleName + ''', @membername = ''' + REPLACE(REPLACE(@sLoginName,'[',''),']','') + ''';';

		  SET @sDBRoleName = NULL;
		  SET @iCount = @iCount + 1;
	   END
    END

	-- Finalize string.
	SET @sSQLStmt = @sSQLStmt + '
END';

    IF @bExecQuery = 1
	   EXEC [sys].[sp_MSforeachdb] @command1 = @sSQLStmt;
    ELSE	   	   
	   PRINT @sSQLStmt;    

    -- Drop login if true and when deleting DB users.
    IF (@bDropLogin = 1) AND (@bCreateUser = 0) AND EXISTS (SELECT 1 FROM sys.[syslogins] WHERE [name] = REPLACE(REPLACE(@sLoginName,'[',''),']',''))
    BEGIN
	   SET @sSQLStmt = 'DROP LOGIN ' + @sLoginName;

	   IF @bExecQuery = 1
		  EXEC [sys].[sp_executesql] @sSQLStmt;
	   ELSE	   	   
		  PRINT @sSQLStmt;	   
    END
END

-- Drop Temp Table.
IF OBJECT_ID('TempDB..##DBExclusions') IS NOT NULL
    DROP TABLE ##DBExclusions;