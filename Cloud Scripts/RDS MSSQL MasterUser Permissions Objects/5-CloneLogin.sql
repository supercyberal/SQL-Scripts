USE [DBATools]
GO
/****** Object:  StoredProcedure [dbo].[CloneLogin]    Script Date: 10/5/2023 4:57:20 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE [dbo].[CloneLogin] @NewLogin SYSNAME
	,@NewLoginPwd NVARCHAR(MAX) = NULL
	,@WindowsLogin CHAR(1)
	,@LoginToClone SYSNAME
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @SQL NVARCHAR(MAX);
	CREATE TABLE #CloneLoginScript (SqlCommand NVARCHAR(MAX));
	SET @SQL = '/' + '*' + 'BEGIN: CLONE SERVER LOGIN' + '*' + '/';
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT @SQL;
	SET @SQL = '/' + '*' + 'CREATE SERVER LOGIN' + '*' + '/';
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT @SQL;
	IF (@WindowsLogin = 'T')
	BEGIN
		SET @SQL = 'CREATE LOGIN [' + @NewLogin + '] FROM WINDOWS;'
		INSERT INTO #CloneLoginScript (SqlCommand)
		SELECT @SQL
	END
	ELSE
	BEGIN
		SET @SQL = 'CREATE LOGIN [' + @NewLogin + '] WITH PASSWORD = N''' + @NewLoginPwd + ''';';
		INSERT INTO #CloneLoginScript (SqlCommand)
		SELECT @SQL
	END
	SET @SQL = '/' + '*' + 'CLONE SERVER ROLES' + '*' + '/';
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT @SQL
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT 'EXEC sp_addsrvrolemember @loginame = ''' + @NewLogin + ''', @rolename = ''' + R.NAME + ''';' AS 'SQL'
	FROM sys.server_role_members AS RM
	JOIN sys.server_principals AS L ON RM.member_principal_id = L.principal_id
	JOIN sys.server_principals AS R ON RM.role_principal_id = R.principal_id
	WHERE L.NAME = @LoginToClone;
	IF @@ROWCOUNT = 0
	BEGIN
		SET @SQL = '/' + '*' + '---- No Server Roles To Clone' + '*' + '/';;
		INSERT INTO #CloneLoginScript (SqlCommand)
		SELECT @SQL
	END
	SET @SQL = '/' + '*' + 'CLONE SERVER PERMISSIONS' + '*' + '/';
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT @SQL;
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT [SQL]
	FROM (
		SELECT CASE P.[STATE]
				WHEN 'W'
					THEN 'USE master;GRANT ' + P.permission_name + ' TO [' + @NewLogin + '] WITH GRANT OPTION;'
				ELSE 'USE master;  ' + P.state_desc + ' ' + P.permission_name + ' TO [' + @NewLogin + '];'
				END AS [SQL]
		FROM sys.server_permissions AS P
		JOIN sys.server_principals AS L ON P.grantee_principal_id = L.principal_id
		WHERE L.NAME = @LoginToClone
			AND P.class = 100
			AND P.type <> 'COSQ'
			AND P.state_desc <> 'DENY'
			AND P.permission_name <> 'ALTER ANY CREDENTIAL'
		UNION ALL
		SELECT CASE P.[STATE]
				WHEN 'W'
					THEN 'GRANT ' + P.permission_name + ' TO [' + @NewLogin + '] ;'
				ELSE 'USE master;  ' + P.state_desc + ' ' + P.permission_name + ' TO [' + @NewLogin + '];'
				END AS [SQL]
		FROM sys.server_permissions AS P
		JOIN sys.server_principals AS L ON P.grantee_principal_id = L.principal_id
		WHERE L.NAME = @LoginToClone
			AND P.class = 100
			AND P.type <> 'COSQ'
			AND P.state_desc <> 'DENY'
			AND P.permission_name ='ALTER ANY CREDENTIAL'
		UNION ALL
		SELECT CASE P.[STATE]
				WHEN 'W'
					THEN 'USE master; GRANT ' + P.permission_name + ' ON LOGIN::[' + L2.NAME + '] TO [' + @NewLogin + '] WITH GRANT OPTION;' COLLATE DATABASE_DEFAULT
				ELSE 'USE master; ' + P.state_desc + ' ' + P.permission_name + ' ON LOGIN::[' + L2.NAME + '] TO [' + @NewLogin + '];' COLLATE DATABASE_DEFAULT
				END AS [SQL]
		FROM sys.server_permissions AS P
		JOIN sys.server_principals AS L ON P.grantee_principal_id = L.principal_id
		JOIN sys.server_principals AS L2 ON P.major_id = L2.principal_id
		WHERE L.NAME = @LoginToClone
		AND P.state_desc <> 'DENY'
		AND P.class = 101
		UNION ALL
		SELECT CASE P.[STATE]
				WHEN 'W'
					THEN 'USE master; GRANT ' + P.permission_name + ' ON ENDPOINT::[' + E.NAME + '] TO [' + @NewLogin + '] WITH GRANT OPTION;' COLLATE DATABASE_DEFAULT
				ELSE 'USE master; ' + P.state_desc + ' ' + P.permission_name + ' ON ENDPOINT::[' + E.NAME + '] TO [' + @NewLogin + '];' COLLATE DATABASE_DEFAULT
				END AS [SQL]
		FROM sys.server_permissions AS P
		JOIN sys.server_principals AS L ON P.grantee_principal_id = L.principal_id
		JOIN sys.endpoints AS E ON P.major_id = E.endpoint_id
		WHERE L.NAME = @LoginToClone
			AND P.class = 105
			AND P.state_desc <> 'DENY'
		) AS ServerPermission;
	IF @@ROWCOUNT = 0
	BEGIN
		SET @SQL = '/' + '*' + '---- No Server Permissions To Clone' + '*' + '/';;
		INSERT INTO #CloneLoginScript (SqlCommand)
		SELECT @SQL
	END
	SET @SQL = '/' + '*' + 'END: CLONE SERVER LOGIN' + '*' + '/';
	INSERT INTO #CloneLoginScript (SqlCommand)
	SELECT @SQL;
	SELECT *
	FROM #CloneLoginScript
END;
