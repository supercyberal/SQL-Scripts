/***********************************************************************************************************************************************
Decription:	Find out what sessions are connected to DBs.

Notes:		2014-05-07
			Created.
***********************************************************************************************************************************************/

USE [master]
GO

IF OBJECT_ID('TempDB..#MySessions') IS NOT NULL
	DROP TABLE #MySessions;

CREATE TABLE #MySessions (
	SPID VARCHAR(512) NULL
	, [Status] VARCHAR(512) NULL
	, [Login] VARCHAR(512) NULL
	, [HostName] VARCHAR(512) NULL
	, [BlkBy] VARCHAR(512) NULL
	, [DBName] VARCHAR(512) NULL
	, [Cmd] VARCHAR(512) NULL
	, [CPUTime] VARCHAR(512) NULL
	, [DiskIO] VARCHAR(512) NULL
	, [LstBatch] VARCHAR(512) NULL
	, [Program] VARCHAR(512) NULL
	, SPID2 VARCHAR(512) NULL
	, Req VARCHAR(512) NULL
);

INSERT #MySessions (
	[SPID]
	,[Status]
	,[Login]
	,[HostName]
	,[BlkBy]
	,[DBName]
	,[Cmd]
	,[CPUTime]
	,[DiskIO]
	,[LstBatch]
	,[Program]
	,[SPID2]
	,[Req]
)
EXEC [sys].[sp_who2] 


SELECT * FROM [#MySessions] ms

