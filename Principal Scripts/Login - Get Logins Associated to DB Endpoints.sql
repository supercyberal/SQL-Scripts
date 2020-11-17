USE [master];

-- List of logins owns.
SELECT SUSER_NAME([principal_id]) AS [endpoint_owner],
       [name] AS [endpoint_name]
FROM [sys].[database_mirroring_endpoints];


-- Change it to SA login.
ALTER AUTHORIZATION ON ENDPOINT::Mirroring TO sa;