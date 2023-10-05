USE [DBATools]
GO
/****** Object:  StoredProcedure [dbo].[CloneRDS]    Script Date: 10/5/2023 4:57:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROC [dbo].[CloneRDS] @NewLogin SYSNAME
	,@NewLoginPwd NVARCHAR(MAX) = NULL
	,@WindowsLogin CHAR(1)
	,@LoginToClone SYSNAME
	,@DatabaseName SYSNAME = NULL
AS
BEGIN
	SET NOCOUNT ON;
	IF EXISTS(SELECT [name] FROM tempdb.sys.tables WHERE [name] like '#CloneRDSScript%')
BEGIN
   DROP TABLE #CloneRDSScript;
END;
	CREATE TABLE #CloneRDSScript (SqlCommand NVARCHAR(MAX));
	INSERT INTO #CloneRDSScript
	EXEC [DBATools].dbo.CloneLogin @NewLogin = @NewLogin
		,@NewLoginPwd = @NewLoginPwd
		,@WindowsLogin = @WindowsLogin
		,@LoginToClone = @LoginToClone;
	INSERT INTO #CloneRDSScript
	EXEC [DBATools].dbo.CreateUserInDB @NewLogin = @NewLogin
		,@LoginToClone = @LoginToClone
		,@DatabaseName = @DatabaseName;
	INSERT INTO #CloneRDSScript
	EXEC [DBATools].dbo.GrantUserRoleMembership @NewLogin = @NewLogin
		,@LoginToClone = @LoginToClone
		,@DatabaseName = @DatabaseName;
	INSERT INTO #CloneRDSScript
	EXEC [DBATools].dbo.CloneDBPerms @NewLogin = @NewLogin
		,@LoginToClone = @LoginToClone
		,@DatabaseName = @DatabaseName;
	SELECT SqlCommand
	FROM #CloneRDSScript
	DROP TABLE #CloneRDSScript
END;

