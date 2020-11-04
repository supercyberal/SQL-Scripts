/*
Get server scope login info
*/

SELECT
    [srvprin].[name] [server_principal]
    , [srvprin].[type_desc] [principal_type]
    , [srvperm].[permission_name]
    , [srvperm].[state_desc]
    , [srvprin].[type]
FROM [sys].[server_permissions] srvperm

INNER JOIN [sys].[server_principals] srvprin
    ON [srvperm].[grantee_principal_id] = [srvprin].[principal_id]

WHERE
    [srvprin].[type] IN ( 'S', 'U', 'G' )

ORDER BY
    [server_principal]
    , [permission_name]; 