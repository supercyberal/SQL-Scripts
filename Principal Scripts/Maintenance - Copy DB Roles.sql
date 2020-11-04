DECLARE @RoleName VARCHAR(50) = '';

DECLARE @Script VARCHAR(MAX) = 'CREATE ROLE ' + QUOTENAME(@RoleName) + ';' + CHAR( 13 );

SELECT  @Script += 'GRANT ' + [prm].[permission_name] + ' ON ' + QUOTENAME(SCHEMA_NAME([o].[schema_id])) + '.' + QUOTENAME([o].[name]) + ' TO ' + QUOTENAME([rol].[name]) + ';' + CHAR( 13 ) COLLATE Latin1_General_CI_AS
FROM    [sys].[database_permissions]     prm
        JOIN [sys].[database_principals] rol
            ON [prm].[grantee_principal_id] = [rol].[principal_id]
		JOIN [sys].[objects] AS [o]
			ON [o].[object_id] = [prm].[major_id]
WHERE   [rol].[name] = @RoleName;

PRINT @Script;
