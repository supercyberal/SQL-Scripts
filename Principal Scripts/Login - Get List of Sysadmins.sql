SELECT
	@@SERVERNAME AS ServerName
	, SERVERPROPERTY('Edition') AS Edition
	, SERVERPROPERTY('ProductVersion') AS [Version]
	, SERVERPROPERTY('MachineName') AS [Machine Name]
	, name
	, isntgroup
	, isntuser
FROM sys.syslogins
WHERE sysadmin = 1;

SELECT (
    CASE WHEN IS_SRVROLEMEMBER('sysadmin') = 1 THEN
	   'YEAP!!! I got SYSADMIN'
    ELSE
	   'Nope!!! I aint got SYSADMIN'
    END
) AS [Am I Super]