USE [WhiteCaseDBInventory]
GO

SET NOCOUNT ON;

-- Generate Values.
SELECT DISTINCT
	'<value version="5" type="database">' 
	+ CHAR(13)
	+ CHAR(9) + '<name>master</name>'
	+ CHAR(13)
	+ CHAR(9) + '<server>' + [vsr].[Connection Name] + '</server>'
	+ CHAR(13)
	+ CHAR(9) + '<integratedSecurity>True</integratedSecurity>'
	+ CHAR(13)
	+ CHAR(9) + '<connectionTimeout>15</connectionTimeout>'
	+ CHAR(13)
	+ CHAR(9) + '<protocol>-1</protocol>'
	+ CHAR(13)
	+ CHAR(9) + '<packetSize>4096</packetSize>'
	+ CHAR(13)
	+ CHAR(9) + '<encrypted>False</encrypted>'
	+ CHAR(13)
	+ CHAR(9) + '<selected>True</selected>'
	+ CHAR(13)
	+ CHAR(9) + '<cserver>' + [vsr].[Connection Name] + '</cserver>'
	+ CHAR(13)
	+ '</value>'
FROM [dbo].[vwSQLReport] AS [vsr]
WHERE [vsr].[Active] = 'True'
--AND [vsr].[Location] = 'LOCAL OFFICE'
--AND [vsr].[Location] = 'AMERICAS'
--AND [vsr].[Location] = 'EMEA'
--AND [vsr].[Location] = 'ASIAPAC'
AND [vsr].[Server Type] = 'Production'
--AND [vsr].[Server Type] = 'Development'
--AND [vsr].[Server Type] = 'QA'
--AND [vsr].[Version] LIKE '1[3,4]%'
AND (
	[vsr].[Edition] NOT LIKE 'Express%'
	AND [vsr].[Edition] NOT LIKE 'Developer%'
	AND [vsr].[Edition] NOT LIKE 'Desktop%'
	AND [vsr].[Edition] NOT LIKE 'Unknow%'
)
AND [vsr].[Location] <> 'DMZ'
AND [vsr].[Server Type] NOT IN ('Laptop','Desktop');

-- To use for a New GUID.
SELECT NEWID();