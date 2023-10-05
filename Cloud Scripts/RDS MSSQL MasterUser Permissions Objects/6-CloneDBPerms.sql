USE [DBATools]
GO
/****** Object:  StoredProcedure [dbo].[CloneDBPerms]    Script Date: 10/5/2023 4:57:18 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROC [dbo].[CloneDBPerms] @NewLogin SYSNAME
	,@LoginToClone SYSNAME
	,@DatabaseName SYSNAME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @SQL NVARCHAR(max);
	DECLARE @DbName SYSNAME;
	DECLARE @Database TABLE (DbName SYSNAME)
	SET @DbName = ''
	CREATE TABLE #CloneDbPermissionScript (SqlCommand NVARCHAR(MAX));
	IF @DatabaseName IS NULL
	BEGIN
		INSERT INTO @Database (DbName)
			SELECT [name]
	FROM MASTER.sys.databases
	WHERE HAS_DBACCESS([name]) = 1 AND [name] not in ('model','rdsadmin','rdsadmin_ReportServer','rdsadmin_ReportServerTempDB','SSISDB')
		ORDER BY NAME;
	END
	ELSE
	BEGIN
		INSERT INTO @Database (DbName)
		SELECT @DatabaseName
	END;
	SET @SQL = '/' + '*' + 'BEGIN: CLONE DATABASE PERMISSIONS' + '*' + '/';
	INSERT INTO #CloneDbPermissionScript (SqlCommand)
	SELECT @SQL;
	WHILE @DbName IS NOT NULL
	BEGIN
		SET @DbName = (
				SELECT MIN(DbName)
				FROM @Database
				WHERE DbName > @DbName
				)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON DATABASE::[' + @DbName + '] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON DATABASE::[' + @DbName + '] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	WHERE class = 0
	  AND P.[type] <> ''CO''
	  AND U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON SCHEMA::[''
		 + S.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON SCHEMA::[''
		 + S.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.schemas AS S
		ON S.schema_id = P.major_id
	WHERE class = 3
	  AND U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON OBJECT::[''
		 + S.name + ''].['' + O.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON OBJECT::[''
		 + S.name + ''].['' + O.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.objects AS O
		ON O.object_id = P.major_id
	  JOIN [' + @DbName + '].sys.schemas AS S
		ON S.schema_id = O.schema_id
	WHERE class = 1
	  AND U.name = ''' + @LoginToClone + '''
	  AND P.major_id > 0
	  AND P.minor_id = 0';
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON OBJECT::[''
		 + S.name + ''].['' + O.name + ''] ('' + C.name + '') TO [' + @NewLogin + '] WITH GRANT OPTION;''
		 COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON OBJECT::[''
		 + S.name + ''].['' + O.name + ''] ('' + C.name + '') TO [' + @NewLogin + '];''
		 COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.objects AS O
		ON O.object_id = P.major_id
	  JOIN [' + @DbName + '].sys.schemas AS S
		ON S.schema_id = O.schema_id
	  JOIN [' + @DbName + '].sys.columns AS C
		ON C.column_id = P.minor_id AND o.object_id = C.object_id
	WHERE class = 1
	  AND U.name = ''' + @LoginToClone +
			'''
	  AND P.major_id > 0
	  AND P.minor_id > 0;'
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON ROLE::[''
		 + U2.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON ROLE::[''
		 + U2.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.database_principals AS U2
		ON U2.principal_id = P.major_id
	WHERE class = 4
	  AND U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON SYMMETRIC KEY::[''
		 + K.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON SYMMETRIC KEY::[''
		 + K.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.symmetric_keys AS K
		ON P.major_id = K.symmetric_key_id
	WHERE class = 24
	  AND U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON ASYMMETRIC KEY::[''
		 + K.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON ASYMMETRIC KEY::[''
		 + K.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.asymmetric_keys AS K
		ON P.major_id = K.asymmetric_key_id
	WHERE class = 26
	  AND U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL)
		SET @SQL = 'INSERT INTO #CloneDbPermissionScript(SqlCommand)
	SELECT CASE [state]
	   WHEN ''W'' THEN ''USE [' + @DbName + ']; GRANT '' + permission_name + '' ON CERTIFICATE::[''
		 + C.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
	   ELSE ''USE [' + @DbName + ']; '' + state_desc + '' '' + permission_name + '' ON CERTIFICATE::[''
		 + C.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
	   END AS ''Permission''
	FROM [' + @DbName + '].sys.database_permissions AS P
	  JOIN [' + @DbName + '].sys.database_principals AS U
		ON P.grantee_principal_id = U.principal_id
	  JOIN [' + @DbName + '].sys.certificates AS C
		ON P.major_id = C.certificate_id
	WHERE class = 25
	  AND U.name = ''' + @LoginToClone + ''';';
		EXEC (@SQL)
	END;
	IF EXISTS (
			SELECT COUNT(SqlCommand)
			FROM #CloneDbPermissionScript
			HAVING COUNT(SqlCommand) < 2
			)
	BEGIN
		SET @SQL = '/' + '*' + '---- No Database Permissions To Clone' + '*' + '/';;
		INSERT INTO #CloneDbPermissionScript (SqlCommand)
		SELECT @SQL
	END;
	SET @SQL = '/' + '*' + 'END: CLONE DATABASE PERMISSIONS' + '*' + '/';
	INSERT INTO #CloneDbPermissionScript (SqlCommand)
	SELECT @SQL;
	SELECT SqlCommand
	FROM #CloneDbPermissionScript;
	DROP TABLE #CloneDbPermissionScript;
END;
