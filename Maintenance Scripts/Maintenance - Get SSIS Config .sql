USE HKSSIS
GO

DECLARE
	@cConfigFilter NVARCHAR(256)
	, @cPackSource NVARCHAR(256)
	, @uExecID UNIQUEIDENTIFIER;


/*

UPDATE [dbo].[SSISConfigurations]
SET [ConfiguredValue] = '\\QFLNETAPP2\iManage_Reports\'
WHERE [ConfigurationFilter] = 'iManage_Alert_Report'
AND [PackagePath] = '\Package.Variables[User::FilePath].Properties[Value]'

*/

/*

--Get distinct filters from the log.

SELECT DISTINCT 
	[ConfigurationFilter] 
FROM dbo.SSISConfigurations

SELECT DISTINCT 
	[source] 
FROM dbo.sysssislog
WHERE [event] = 'PackageStart'

*/

SET @cConfigFilter = 'BitLocker_Import';
SET @cPackSource = 'BitLocker_Import_Pck';

SELECT * FROM dbo.SSISConfigurations
WHERE ConfigurationFilter = @cConfigFilter

SELECT TOP 1
	@uExecID = executionid
FROM dbo.sysssislog
CROSS APPLY (
	SELECT 
		MAX(id) AS MaxID
	FROM dbo.sysssislog
	WHERE event = 'PackageStart'
	AND source = @cPackSource
) tbl
WHERE id = [tbl].[MaxID]

SELECT * FROM dbo.sysssislog
WHERE executionid = @uExecID;
