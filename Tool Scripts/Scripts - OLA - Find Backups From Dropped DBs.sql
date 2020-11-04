DECLARE @Directories TABLE (subdirectory nvarchar(max), depth int)

DECLARE @Directory nvarchar(4000)

SET @Directory = 'F:\Backups' + '\' + REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$')
--SELECT @Directory

INSERT INTO @Directories (subdirectory, depth)
EXECUTE [master].dbo.xp_dirtree @Directory

SELECT subdirectory
FROM @Directories
WHERE depth = 1
EXCEPT
SELECT REPLACE(name,' ','')
FROM sys.databases
