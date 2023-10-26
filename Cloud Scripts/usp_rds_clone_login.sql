USE [DBATools];
GO

/* SP "usp_rds_clone_login" Duplicates the Login and duplicates database user for those logins in each database that the login permissions that you're copying from is present*/
IF (OBJECT_ID('dbo.usp_rds_clone_login') IS NULL)
BEGIN
    EXEC ('CREATE PROCEDURE [dbo].[usp_rds_clone_login] AS SELECT 1')
END
GO
ALTER PROCEDURE [dbo].[usp_rds_clone_login]
    @NewLogin SYSNAME,          -- Login Name for the cloned login
    @NewLoginPwd NVARCHAR(MAX), -- Password for the cloned login
    @WindowsAuth BIT,
    @LoginToDuplicate SYSNAME   -- Login name to clone
AS
BEGIN
    /*
    --Usage:
    EXEC    [DB_NAME].[dbo].[usp_rds_clone_login]  @NewLogin='AdminClone'
            ,@NewLoginPwd = 'NewPassword'
            ,@LoginToDuplicate = admin
            , @WindowsAuth  = 0
    */
    SET NOCOUNT ON;
    DECLARE @SQL AS NVARCHAR(MAX);
    CREATE TABLE #DuplicateLogins
    (
        SqlCommand NVARCHAR(MAX)
    );
    DECLARE @DbName AS SYSNAME;
    DECLARE @Database TABLE
    (
        DbName SYSNAME
    );
    SET @DbName = '';

    SET @SQL = '/' + '*' + 'Cloning Process Steps' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;

    SET @SQL = '/' + '*' + '==================================================' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '1 - Create new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '2 - Server role membership for new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '3 - Server level permissions for the new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '4 - Create database user for new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '5 - Database role membership for db user' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '6 - Database level permissions' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    SET @SQL = '/' + '*' + '==================================================' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;

    SET @SQL = '/' + '*' + '1 - Create new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    IF (@WindowsAuth = 1)
    BEGIN
        SET @SQL = 'CREATE LOGIN [' + @NewLogin + '] FROM WINDOWS;';
        INSERT INTO #DuplicateLogins
        (
            SqlCommand
        )
        SELECT @SQL;
    END
    ELSE
    BEGIN
        SET @SQL = 'CREATE LOGIN [' + @NewLogin + '] WITH PASSWORD = N''' + @NewLoginPwd + ''';';
        INSERT INTO #DuplicateLogins
        (
            SqlCommand
        )
        SELECT @SQL;
    END

    SET @SQL = '/' + '*' + '2 - Server role memberships for new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;

    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT 'EXEC sp_addsrvrolemember @loginame = ''' + @NewLogin + ''', @rolename = ''' + R.NAME + ''';' AS [SQL]
    FROM sys.server_role_members AS RM
        INNER JOIN sys.server_principals AS L
            ON RM.member_principal_id = L.principal_id
        INNER JOIN sys.server_principals AS R
            ON RM.role_principal_id = R.principal_id
    WHERE L.NAME = @LoginToDuplicate;

    IF @@ROWCOUNT = 0
    BEGIN
        SET @SQL = '/' + '*' + '---- No Server role memberships found' + '*' + '/';
        INSERT INTO #DuplicateLogins
        (
            SqlCommand
        )
        SELECT @SQL;
    END

    SET @SQL = '/' + '*' + '3 - Server level permissions for the new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT [SQL]
    FROM
    (
        SELECT CASE P.[STATE]
                   WHEN 'W' THEN
                       'USE master;GRANT ' + P.permission_name + ' TO [' + @NewLogin + '] WITH GRANT OPTION;'
                   ELSE
                       'USE master;  ' + P.state_desc + ' ' + P.permission_name + ' TO [' + @NewLogin + '];'
               END AS [SQL]
        FROM sys.server_permissions AS P
            INNER JOIN sys.server_principals AS L
                ON P.grantee_principal_id = L.principal_id
        WHERE L.NAME = @LoginToDuplicate
              AND P.class = 100
              AND P.type <> 'COSQ'
              AND P.state_desc <> 'DENY'
              AND P.permission_name <> 'ALTER ANY CREDENTIAL'
        UNION ALL
        SELECT CASE P.[STATE]
                   WHEN 'W' THEN
                       'GRANT ' + P.permission_name + ' TO [' + @NewLogin + '] ;'
                   ELSE
                       'USE master;  ' + P.state_desc + ' ' + P.permission_name + ' TO [' + @NewLogin + '];'
               END AS [SQL]
        FROM sys.server_permissions AS P
            INNER JOIN sys.server_principals AS L
                ON P.grantee_principal_id = L.principal_id
        WHERE L.NAME = @LoginToDuplicate
              AND P.class = 100
              AND P.type <> 'COSQ'
              AND P.state_desc <> 'DENY'
              AND P.permission_name = 'ALTER ANY CREDENTIAL'
        UNION ALL
        SELECT CASE P.[STATE]
                   WHEN 'W' THEN
                       'USE master; GRANT ' + P.permission_name + ' ON LOGIN::[' + L2.NAME + '] TO [' + @NewLogin
                       + '] WITH GRANT OPTION;' COLLATE DATABASE_DEFAULT
                   ELSE
                       'USE master; ' + P.state_desc + ' ' + P.permission_name + ' ON LOGIN::[' + L2.NAME + '] TO ['
                       + @NewLogin + '];' COLLATE DATABASE_DEFAULT
               END AS [SQL]
        FROM sys.server_permissions AS P
            INNER JOIN sys.server_principals AS L
                ON P.grantee_principal_id = L.principal_id
            INNER JOIN sys.server_principals AS L2
                ON P.major_id = L2.principal_id
        WHERE L.NAME = @LoginToDuplicate
              AND P.state_desc <> 'DENY'
              AND P.class = 101
        UNION ALL
        SELECT CASE P.[STATE]
                   WHEN 'W' THEN
                       'USE master; GRANT ' + P.permission_name + ' ON ENDPOINT::[' + E.NAME + '] TO [' + @NewLogin
                       + '] WITH GRANT OPTION;' COLLATE DATABASE_DEFAULT
                   ELSE
                       'USE master; ' + P.state_desc + ' ' + P.permission_name + ' ON ENDPOINT::[' + E.NAME + '] TO ['
                       + @NewLogin + '];' COLLATE DATABASE_DEFAULT
               END AS [SQL]
        FROM sys.server_permissions AS P
            INNER JOIN sys.server_principals AS L
                ON P.grantee_principal_id = L.principal_id
            INNER JOIN sys.endpoints AS E
                ON P.major_id = E.endpoint_id
        WHERE L.NAME = @LoginToDuplicate
              AND P.class = 105
              AND P.state_desc <> 'DENY'
    ) AS ServerPermission;
    IF @@ROWCOUNT = 0
    BEGIN
        SET @SQL = '/' + '*' + '---- No Server level permissions found' + '*' + '/';
        INSERT INTO #DuplicateLogins
        (
            SqlCommand
        )
        SELECT @SQL;
    END

    --   SELECT * FROM   #DuplicateLogins;

    INSERT INTO @Database
    (
        DbName
    )
    SELECT NAME
    FROM sys.databases
    WHERE state_desc = 'ONLINE'
          AND NAME NOT IN ( 'model', 'rdsadmin_ReportServer', 'rdsadmin_ReportServerTempDB' )
    ORDER BY NAME ASC;

    SET @SQL = '/' + '*' + '4 - Create database user for new login' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;

    WHILE @DbName IS NOT NULL
    BEGIN
        SET @DbName =
        (
            SELECT MIN(DbName)FROM @Database WHERE DbName > @DbName
        );
        SET @SQL = '
INSERT INTO #DuplicateLogins (SqlCommand)
SELECT ''USE [' + @DbName + ']; 
IF EXISTS(SELECT name FROM sys.database_principals 
WHERE name = ' + '''''' + @LoginToDuplicate + '''''' + ')
BEGIN
CREATE USER [' + @NewLogin + '] FROM LOGIN [' + @NewLogin + '];
END;''' ;
        EXECUTE (@SQL);
    END


    SET @SQL = '/' + '*' + '5 - Database role membership for db user' + '*' + '/';
    INSERT INTO #DuplicateLogins
    (
        SqlCommand
    )
    SELECT @SQL;

    SET @DbName = '';

    WHILE @DbName IS NOT NULL
    BEGIN
        SET @DbName =
        (
            SELECT MIN(DbName)
            FROM @Database
            WHERE DbName > @DbName
                  AND DbName NOT IN ( 'model', 'rdsadmin', 'rdsadmin_ReportServer', 'rdsadmin_ReportServerTempDB',
                                      'SSISDB'
                                    )
        );
        SET @SQL = '
INSERT INTO #DuplicateLogins (SqlCommand)
SELECT ''USE [' + @DbName + ']; EXEC sp_addrolemember @rolename = '''''' + R.name
+ '''''', @membername = ''''' + @NewLogin + ''''';''
FROM [' + @DbName + '].sys.database_principals AS U
JOIN [' + @DbName + '].sys.database_role_members AS RM
ON U.principal_id = RM.member_principal_id
JOIN [' + @DbName + '].sys.database_principals AS R
ON RM.role_principal_id = R.principal_id
WHERE U.name = ''' + @LoginToDuplicate + ''';';
        EXECUTE (@SQL);
    END

END


SET @SQL = '/' + '*' + '6 - Database level permissions' + '*' + '/';
INSERT INTO #DuplicateLogins
(
    SqlCommand
)
SELECT @SQL;
SET @DBName = ''
WHILE @DBName IS NOT NULL
BEGIN
    SET @DBName =
    (
        SELECT MIN(DbName)
        FROM @Database
        WHERE DbName > @DBName
              AND DbName NOT IN ( 'model', 'rdsadmin', 'rdsadmin_ReportServer', 'rdsadmin_ReportServerTempDB', 'SSISDB' )
    );
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName + ']; GRANT '' + permission_name + '' ON DATABASE::[' + @DBName + '] TO ['
          + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName + ']; '' + state_desc + '' '' + permission_name + '' ON DATABASE::[' + @DBName
          + '] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
    WHERE class = 0
      AND P.[type] <> ''CO''
      AND U.name = ''' + @LoginToDuplicate + ''';';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON SCHEMA::[''
         + S.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON SCHEMA::[''
         + S.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName
          + '].sys.schemas AS S
        ON S.schema_id = P.major_id
    WHERE class = 3
      AND U.name = ''' + @LoginToDuplicate + ''';';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON OBJECT::[''
         + S.name + ''].['' + O.name + ''] TO [' + @NewLogin
          + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON OBJECT::[''
         + S.name + ''].['' + O.name + ''] TO [' + @NewLogin
          + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName + '].sys.objects AS O
        ON O.object_id = P.major_id
      JOIN [' + @DBName
          + '].sys.schemas AS S
        ON S.schema_id = O.schema_id
    WHERE class = 1
      AND U.name = ''' + @LoginToDuplicate + '''
      AND P.major_id > 0
      AND P.minor_id = 0';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON OBJECT::[''
         + S.name + ''].['' + O.name + ''] ('' + C.name + '') TO [' + @NewLogin
          + '] WITH GRANT OPTION;''
         COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON OBJECT::[''
         + S.name + ''].['' + O.name + ''] ('' + C.name + '') TO [' + @NewLogin
          + '];''
         COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName + '].sys.objects AS O
        ON O.object_id = P.major_id
      JOIN [' + @DBName + '].sys.schemas AS S
        ON S.schema_id = O.schema_id
      JOIN [' + @DBName
          + '].sys.columns AS C
        ON C.column_id = P.minor_id AND O.object_id = C.object_id
    WHERE class = 1
      AND U.name = ''' + @LoginToDuplicate + '''
      AND P.major_id > 0
      AND P.minor_id > 0;';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON ROLE::[''
         + U2.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON ROLE::[''
         + U2.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName
          + '].sys.database_principals AS U2
        ON U2.principal_id = P.major_id
    WHERE class = 4
      AND U.name = ''' + @LoginToDuplicate + ''';';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON SYMMETRIC KEY::[''
         + K.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON SYMMETRIC KEY::[''
         + K.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName
          + '].sys.symmetric_keys AS K
        ON P.major_id = K.symmetric_key_id
    WHERE class = 24
      AND U.name = ''' + @LoginToDuplicate + ''';';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON ASYMMETRIC KEY::[''
         + K.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON ASYMMETRIC KEY::[''
         + K.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName
          + '].sys.asymmetric_keys AS K
        ON P.major_id = K.asymmetric_key_id
    WHERE class = 26
      AND U.name = ''' + @LoginToDuplicate + ''';';
    EXECUTE (@SQL);
    SET @SQL
        = 'INSERT INTO #DuplicateLogins(SqlCommand)
    SELECT CASE [state]
       WHEN ''W'' THEN ''USE [' + @DBName
          + ']; GRANT '' + permission_name + '' ON CERTIFICATE::[''
         + C.name + ''] TO [' + @NewLogin + '] WITH GRANT OPTION;'' COLLATE DATABASE_DEFAULT
       ELSE ''USE [' + @DBName
          + ']; '' + state_desc + '' '' + permission_name + '' ON CERTIFICATE::[''
         + C.name + ''] TO [' + @NewLogin + '];'' COLLATE DATABASE_DEFAULT
       END AS ''Permission''
    FROM [' + @DBName + '].sys.database_permissions AS P
      JOIN [' + @DBName
          + '].sys.database_principals AS U
        ON P.grantee_principal_id = U.principal_id
      JOIN [' + @DBName
          + '].sys.certificates AS C
        ON P.major_id = C.certificate_id
    WHERE class = 25
      AND U.name = ''' + @LoginToDuplicate + ''';';
    EXECUTE (@SQL);
END

SELECT SqlCommand AS [--SqlCommand]
FROM #DuplicateLogins