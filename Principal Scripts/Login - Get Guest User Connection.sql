USE [master];
GO

DECLARE @database_name sysname,
    @sqlcmd NVARCHAR(4000);

DECLARE [databases_cursor] CURSOR LOCAL FAST_FORWARD
FOR
    SELECT  [name]
    FROM    [sys].[databases]
    WHERE   [state] IN ( 0 )
            AND [database_id] > 4
    ORDER BY [name];

CREATE TABLE [#guest_users_enabled]
    (
      [database_name] sysname,
      [user_name] sysname,
      [permission_name] NVARCHAR(128),
      [state_desc] NVARCHAR(6)
    );

OPEN [databases_cursor];

FETCH NEXT FROM [databases_cursor] INTO @database_name;

WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @sqlcmd = N'use ' + @database_name + ';

        insert into #guest_users_enabled

        SELECT ''' + @database_name + ''' as database_name, name,

        permission_name, state_desc

        FROM sys.database_principals dpr

        INNER JOIN sys.database_permissions dpe

        ON dpr.principal_id = dpe.grantee_principal_id

        WHERE name = ''guest'' AND permission_name = ''CONNECT''';

        EXEC [sys].[sp_executesql] @sqlcmd;

        FETCH NEXT FROM [databases_cursor] INTO @database_name;

    END;

SELECT  [database_name],
        [user_name],
        [permission_name],
        [state_desc]
FROM    [#guest_users_enabled]
ORDER BY [database_name] ASC;

DROP TABLE [#guest_users_enabled];

CLOSE [databases_cursor];

DEALLOCATE [databases_cursor];

GO