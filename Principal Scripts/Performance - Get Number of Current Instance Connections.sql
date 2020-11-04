/***********************************************************************************************************************************************
Description:	Get number of connections in instance.

Notes:			ACOSTA - 2014-01-03
				Created.
***********************************************************************************************************************************************/

USE [master]
GO
SELECT 
    DB_NAME([s].[dbid]) AS DBName
    , COUNT([s].[dbid]) AS NumberOfConnections
	, [s].[hostname] AS ServerName
    , [s].[loginame] AS LoginName
FROM
    [sys].[sysprocesses] s
WHERE 
    [dbid] > 0
GROUP BY 
    [dbid]
	, [loginame]
	, [s].[hostname]
ORDER BY
	DB_NAME([dbid])
	, [ServerName];
	