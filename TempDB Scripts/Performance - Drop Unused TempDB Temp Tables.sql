USE [tempdb]
GO

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[TempTableToKeep]') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
    DROP TABLE [dbo].[TempTableToKeep]
GO

CREATE TABLE [dbo].[TempTableToKeep] (
    [TempTable] [varchar] (100) /*COLLATE SQL_Latin1_General_CP1_CI_AS*/ NOT NULL ,
    [DateToDelete] [datetime] NOT NULL
) ON [PRIMARY]
GO

/*
IF EXISTS (SELECT name FROM sysobjects WHERE name = N'sp_DropTempTables' AND type = 'P')
    DROP PROCEDURE sp_DropTempTables
GO

CREATE PROCEDURE sp_DropTempTables
*/

DECLARE
    @cSQL NVARCHAR(2000) = ''
    , @bExecQuery BIT = 0
    , @iHourBacksToCheck INT = 12        

SELECT 
    @cSQL += N'DROP TABLE [tempdb].[dbo].[' + [tdb].[name] + '];' + CHAR(13)
    --, tdb.*
FROM [dbo].[TempTableToKeep] ttk
RIGHT OUTER JOIN [tempdb].[dbo].[sysobjects] tdb
    ON [ttk].[TempTable] = [tdb].[name]
WHERE [tdb].[crdate] < DATEADD(hh, -@iHourBacksToCheck, GETDATE())
AND [tdb].[type] = 'U'
AND (
    [ttk].[DateToDelete] < GETDATE()    
    OR ( [ttk].[DateToDelete] IS NULL )
);

-- Print or execute
IF @bExecQuery = 1
    EXEC [sys].[sp_executesql] @cSQL;
ELSE
    PRINT @cSQL;

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id(N'[dbo].[TempTableToKeep]') AND OBJECTPROPERTY(id, N'IsUserTable') = 1)
    DROP TABLE [dbo].[TempTableToKeep]
GO