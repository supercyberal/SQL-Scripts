:CONNECT AM1CLDB951\FINDATA

IF OBJECT_ID('TempDB..#ErrorLog') IS NOT NULL
	DROP TABLE #ErrorLog;

CREATE TABLE #ErrorLog (
	ID INT IDENTITY(1,1) NOT NULL PRIMARY KEY CLUSTERED
	, LogDate DATETIME2 NOT NULL
	, ProcInfo NVARCHAR(64) NOT NULL
	, [Text] NVARCHAR(MAX) NULL
);

INSERT [#ErrorLog] ( [LogDate], [ProcInfo], [Text] )
EXEC [sys].[xp_readerrorlog] 0

SELECT TOP 200 * FROM [#ErrorLog] AS [el]
ORDER BY [el].[ID] DESC;

IF OBJECT_ID('TempDB..#ErrorLog') IS NOT NULL
	DROP TABLE #ErrorLog;
GO
