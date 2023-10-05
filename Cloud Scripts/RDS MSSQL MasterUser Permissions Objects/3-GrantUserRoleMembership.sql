USE [DBATools]
GO
/****** Object:  StoredProcedure [dbo].[GrantUserRoleMembership]    Script Date: 10/5/2023 4:57:28 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROC [dbo].[GrantUserRoleMembership] @NewLogin SYSNAME
	,@LoginToClone SYSNAME
	,@DatabaseName SYSNAME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @DbName SYSNAME;
	DECLARE @Database TABLE (DbName SYSNAME)
	SET @DbName = ''
	CREATE TABLE #CloneRoleMembershipScript (SqlCommand NVARCHAR(MAX));
	IF @DatabaseName IS NULL
	BEGIN
		INSERT INTO @Database (DbName)
			SELECT [name]
	FROM MASTER.sys.databases
	WHERE HAS_DBACCESS([name]) = 1 AND name not in ('model','rdsadmin','rdsadmin_ReportServer','rdsadmin_ReportServerTempDB','SSISDB')
		ORDER BY NAME ASC;
	END
	ELSE
	BEGIN
		INSERT INTO @Database (DbName)
		SELECT @DatabaseName
	END;
	SET @SQL = '/' + '*' + 'BEGIN: CLONE DATABASE ROLE MEMBERSHIP' + '*' + '/';
	INSERT INTO #CloneRoleMembershipScript (SqlCommand)
	SELECT @SQL;
	WHILE @DbName IS NOT NULL
	BEGIN
		SET @DbName = (
				SELECT MIN(DbName)
				FROM @Database
				WHERE DbName > @DbName and DbName not in ('model','rdsadmin','rdsadmin_ReportServer','rdsadmin_ReportServerTempDB','SSISDB')
				)
		SET @SQL = '
INSERT INTO #CloneRoleMembershipScript (SqlCommand)
SELECT ''USE [' + @DBName + ']; EXEC sp_addrolemember @rolename = '''''' + r.name
+ '''''', @membername = ''''' + @NewLogin + ''''';''
FROM [' + @DBName + '].sys.database_principals AS U
JOIN [' + @DBName + '].sys.database_role_members AS RM
ON U.principal_id = RM.member_principal_id
JOIN [' + @DBName + '].sys.database_principals AS R
ON RM.role_principal_id = R.principal_id
WHERE U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL);
	END;
	IF EXISTS (
			SELECT COUNT(SqlCommand)
			FROM #CloneRoleMembershipScript
			HAVING COUNT(SqlCommand) < 2
			)
	BEGIN
		SET @SQL = '/' + '*' + '---- No Database Roles To Clone' + '*' + '/';;
		INSERT INTO #CloneRoleMembershipScript (SqlCommand)
		SELECT @SQL
	END;
	SET @SQL = '/' + '*' + 'END: CLONE DATABASE ROLE MEMBERSHIP' + '*' + '/';
	INSERT INTO #CloneRoleMembershipScript (SqlCommand)
	SELECT @SQL;
	SELECT SqlCommand
	FROM #CloneRoleMembershipScript;
	DROP TABLE #CloneRoleMembershipScript;
END;
