USE [WhiteCaseDBInventory]
GO

/*
DON'T FORGET TO SAVE THE RESULTS INTO EXCEL PRIOR TO SAVING INTO CONFLUENCE
*/

SET NOCOUNT ON;

DECLARE @tblEditions TABLE (
	Edition VARCHAR(64) NOT NULL
);

INSERT @tblEditions
(
    [Edition]
)
VALUES
('Enterprise')
, ('Standard');

DECLARE @tblPatchKBs TABLE (
	Build SMALLINT NOT NULL
	, KBFile VARCHAR(512) NOT NULL
)

INSERT @tblPatchKBs
(
    [Build],
    [KBFile]
)
VALUES
(   
	11, -- Build - smallint
    '\\Wcnet\firm\Applications\GTS\Software\Microsoft\SQL\Patches\SQLServer2012-KB4532098-x64.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances' -- KBFile - varchar(512)
)
, (   
	12, -- Build - smallint
    '\\Wcnet\firm\Applications\GTS\Software\Microsoft\SQL\Patches\SQLServer2014-KB4535288-x64.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances' -- KBFile - varchar(512)
)
, (   
	13, -- Build - smallint
    '\\Wcnet\firm\Applications\GTS\Software\Microsoft\SQL\Patches\SQLServer2016-KB4536648-x64.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances' -- KBFile - varchar(512)
)
, (   
	14, -- Build - smallint
    '\\Wcnet\firm\Applications\GTS\Software\Microsoft\SQL\Patches\SQLServer2017-KB4541283-x64.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances' -- KBFile - varchar(512)
)
, (   
	15, -- Build - smallint
    '\\Wcnet\firm\Applications\GTS\Software\Microsoft\SQL\Patches\SQLServer2019-KB4548597-x64.exe /q /IAcceptSQLServerLicenseTerms /Action=Patch /AllInstances' -- KBFile - varchar(512)
)

;WITH cteSelectedSrvs AS (
	SELECT
		[vsr].[Machine Name] AS Machine
		, [vsr].[Version]
		, [vsr].[Server Type] AS Environment
		, [vsr].[Edition]
	FROM [dbo].[vwSQLReport] AS [vsr]
	WHERE [vsr].[Active] = 'True'
	UNION
	SELECT
		[vscr].[Machine Name] AS Machine
		, [vscr].[Component Version] AS [Version]
		, [vscr].[Server Type] AS Environment
		, [vscr].[Component Edition] AS [Edition]
	FROM [dbo].[vwSQLCompReport] AS [vscr]
	WHERE [vscr].[Active] = 'True'
)
, ctePatching AS (
	SELECT
		[c].[Machine],
        MIN([c].[Version]) OVER (PARTITION BY [c].[Machine]) AS [Version],
		[c].[Environment]
	FROM [cteSelectedSrvs] AS c
	WHERE EXISTS (
		SELECT 1 FROM @tblEditions AS [te]
		WHERE [c].[Edition] LIKE '%' + [te].[Edition] + '%'
	)
)
, cteResults AS (
	SELECT
		[c].[Machine],
        [c].[Version],
        [c].[Environment],
		[dbo].[fnNeedsPatching]([c].[Version]) AS NeedsPatching
	FROM [ctePatching] AS c
)
SELECT DISTINCT
	[c].[Machine] AS [Server Name]
	, '' AS [Patching Day]
	, '' AS [Successfully Patched]
	, ISNULL(SUBSTRING([apps].[AppName],2,LEN([apps].[AppName])),'N/A') AS AppName
	--, [c].[Version] AS [Build]
	, [tpkb].[KBFile]
FROM [cteResults] AS c
JOIN @tblPatchKBs AS [tpkb]
	ON [tpkb].[Build] = CAST( LEFT([c].[Version],2) AS SMALLINT )
OUTER APPLY (
	SELECT
		' * ' + [vscai].[App Name] AS [text()]
	FROM [dbo].[vwSASCatalogAppInfo] AS [vscai]
	WHERE [vscai].[Machine Name] = [c].[Machine]
	FOR XML PATH('')
) apps (AppName)
WHERE [c].[Environment] = 'Production'
AND [c].[NeedsPatching] LIKE 'Yes%'
AND [c].[Version] LIKE '1[1-5]%'
ORDER BY [c].[Machine];
