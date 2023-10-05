USE [DBATools]
GO
/****** Object:  StoredProcedure [dbo].[CreateUserInDB]    Script Date: 10/5/2023 4:57:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROC [dbo].[CreateUserInDB] @NewLogin SYSNAME
	,@LoginToClone SYSNAME
	,@DatabaseName SYSNAME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @SQL NVARCHAR(MAX);
	DECLARE @DbName SYSNAME;
	DECLARE @Database TABLE (DbName SYSNAME)
	SET @DbName = ''
	CREATE TABLE #CloneDbUserScript (SqlCommand NVARCHAR(MAX));
	IF @DatabaseName IS NULL
	BEGIN
		INSERT INTO @Database (DbName)
		SELECT NAME
		FROM sys.databases
		WHERE state_desc = 'ONLINE' AND NAME NOT IN ('model','rdsadmin_ReportServer','rdsadmin_ReportServerTempDB')
		ORDER BY NAME ASC;
	END
	ELSE
	BEGIN
		INSERT INTO @Database (DbName)
		SELECT @DatabaseName
	END;
	SET @SQL = '/' + '*' + 'BEGIN: CREATE DATABASE USER' + '*' + '/';
	INSERT INTO #CloneDbUserScript (SqlCommand)
	SELECT @SQL;
	WHILE @DbName IS NOT NULL
	BEGIN
		SET @DbName = (
				SELECT MIN(DbName)
				FROM @Database
				WHERE DbName > @DbName
				)
		SET @SQL = '
INSERT INTO #CloneDbUserScript (SqlCommand)
SELECT ''USE [' + @DbName + ']; 
IF EXISTS(SELECT name FROM sys.database_principals 
WHERE name = ' + '''''' + @LoginToClone + '''''' + ')
BEGIN
CREATE USER [' + @NewLogin + '] FROM LOGIN [' + @NewLogin + '];
END;''';
		EXEC (@SQL);
	END;
	IF EXISTS (
			SELECT COUNT(SqlCommand)
			FROM #CloneDbUserScript
			HAVING COUNT(SqlCommand) < 2
			)
	BEGIN
		SET @SQL = '/' + '*' + '---- No Database User To Create' + '*' + '/';;
		INSERT INTO #CloneDbUserScript (SqlCommand)
		SELECT @SQL
	END;
	SET @SQL = '/' + '*' + 'END: CREATE DATABASE USER' + '*' + '/';
	INSERT INTO #CloneDbUserScript (SqlCommand)
	SELECT @SQL;
	SELECT SqlCommand
	FROM #CloneDbUserScript;
	DROP TABLE #CloneDbUserScript;
END;
