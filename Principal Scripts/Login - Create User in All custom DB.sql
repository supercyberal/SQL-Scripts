/***********************************************************************************************************************************************
Description:	Create or Drop DB users from Login in all custom DBs. Also, has the ability to add to DB role.

Notes:
ACOSTA - 2013-09-19
	Created.
***********************************************************************************************************************************************/

USE master
GO

DECLARE
	@sLoginName VARCHAR(128)
	, @sDBRoleName VARCHAR(128)
	, @bCreateUser BIT
	, @bDropLogin BIT
	, @sSQLStmt VARCHAR(max);

-- Login name with the begining and ending brackets. Ex.: [DOMAIN\account]
SET @sLoginName = NULL

-- DB role. Ex.: db_datareader, db_datawriter, db_ddladmin, db_owner.
SET @sDBRoleName = NULL

-- If set to 1, then we create a user and possible DB role association, if set to 0, than we delete from DBs.
SET @bCreateUser = 1;

-- If set to, then we drop the login.
SET @bDropLogin = 0;

IF @sLoginName IS NOT NULL
BEGIN
	-- Prep login SQL string.
	SET @sSQLStmt = '
USE [?]
IF (
	DB_NAME() NOT IN (''master'',''msdb'',''master'',''tempdb'',''AuditLog'',''DBA_Work_DB'',''dbWarden'')
	AND NOT EXISTS (
		SELECT 1 FROM sys.[databases]
		WHERE [name] = DB_NAME()
		AND [is_read_only] = 1
	)
)
BEGIN'
	
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
	IF (@sDBRoleName IS NOT NULL) AND (@bCreateUser = 1)		
		SET @sSQLStmt = @sSQLStmt +	'
	EXEC [sys].[sp_addrolemember] @rolename = ''' + @sDBRoleName + ''', @membername = ''' + REPLACE(REPLACE(@sLoginName,'[',''),']','') + ''';';	

	-- Finalize string.
	SET @sSQLStmt = @sSQLStmt + '
END';

	--PRINT @sSQLStmt
	EXEC [sys].[sp_MSforeachdb] @sSQLStmt;	

	-- Drop login if true and when deleting DB users.
	IF (@bDropLogin = 1) AND (@bCreateUser = 0)
	BEGIN
		SET @sSQLStmt = 'DROP LOGIN ' + @sLoginName;

		--PRINT @sSQLStmt
		EXEC (@sSQLStmt);
	END
END