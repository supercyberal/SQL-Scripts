/*=============================================================================================================================================
Author:		 Alvaro Costa
Date:		 2014-11-20
Description:	 Use this script to move Table or Index from one FileGroup to another. Here's
=============================================================================================================================================*/

-- Change to the DB of your choice.
USE [SQLSentry]
GO

SET NOCOUNT ON;

-- =============================================================================================================================================
-- Local Variables and Temp Objects.

DECLARE 
    @iCount INT = 1
	, @bExecScript BIT = 0
    , @iTotalRecords INT = 0
    , @cSQLStmt NVARCHAR(MAX)
    , @cDBName SYSNAME = DB_NAME();

IF OBJECT_ID('TempDB..#tblObjects') IS NOT NULL
    DROP TABLE #tblObjects;

CREATE TABLE #tblObjects (
    Id INT IDENTITY(1,1) NOT NULL
    , SchemaName SYSNAME NOT NULL
    , TableName SYSNAME NOT NULL
    , IndexName SYSNAME NULL
    , OrigFileGroup SYSNAME NOT NULL
    , DestFileGroup SYSNAME NOT NULL
    , ObjType NVARCHAR(60) NOT NULL
);

DECLARE @tFileGroupMigration TABLE (
    Id INT IDENTITY(1,1)    
    , OrigFileGroup SYSNAME NOT NULL
    , DestFileGroup SYSNAME NOT NULL
);

-- =============================================================================================================================================
-- Populate Temp Objects.

INSERT @tFileGroupMigration ( [OrigFileGroup], [DestFileGroup] )
VALUES 
    ('PRIMARY', 'DataPrimary')

INSERT [#tblObjects] ( 
    [SchemaName]
    , [TableName]
    , [IndexName]
    , [OrigFileGroup]
    , [DestFileGroup]
    , [ObjType]
)
SELECT TOP 1
    OBJECT_SCHEMA_NAME(t.object_id) AS schema_name
    , t.name AS table_name    
    , i.name AS index_name
    , [tt].[OrigFileGroup] AS [Original FileGroup]     
    , [tt].[DestFileGroup] AS [Destination FileGroup]
    , [i].[type_desc]
FROM
    sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
JOIN sys.filegroups ds
    ON i.data_space_id = ds.data_space_id
JOIN @tFileGroupMigration tt
    ON [tt].[OrigFileGroup] = [ds].[name]
--WHERE [i].[type_desc] <> 'HEAP'
ORDER BY 
	[i].[type_desc] DESC
	, OBJECT_SCHEMA_NAME(t.object_id)
	, [t].[name];

SET @iTotalRecords = @@ROWCOUNT;
SELECT * FROM [#tblObjects] AS [to]

-- =============================================================================================================================================
-- Main.

WHILE @iCount <= @iTotalRecords
BEGIN
    SELECT
	   @cSQLStmt = (
		  CASE WHEN [ObjType] = 'NONCLUSTERED' THEN
			 'EXEC [dbo].[MoveIndexToFileGroup] @DBName = ''' 
			 + @cDBName + 
			 ''', @SchemaName = ''' 
			 + [SchemaName] + 
			 ''', @ObjectNameList = ''' 
			 + [TableName] + 
			 ''', @IndexName = ''' 
			 + [IndexName] + 
			 ''', @FileGroupName = ''' 
			 + [DestFileGroup] 
			 + ''';'
		  WHEN [ObjType] IN ('HEAP','CLUSTERED') THEN
			 'EXEC [dbo].[MoveTableToDiffFileGroup] @TableName = ''' 
			 + [TableName] + 
			 ''', @TableSchemaName = ''' 
			 + [SchemaName] + 
			 ''', @SourceFileGroup = ''' 
			 + [OrigFileGroup] + 
			 ''', @TargetFileGroup = ''' 
			 + [DestFileGroup] + 
			 ''', @MovePKAndAllUniqueConstraints = 1, @MoveAllNonClusteredIndexes = 0;'
		  END
	   )
    FROM [#tblObjects]
    WHERE [Id] = @iCount;

    -- Execute statement.
	IF @bExecScript = 1
		EXEC [sys].[sp_executesql] @cSQLStmt;
	ELSE
		PRINT @cSQLStmt;
    
    -- Reset variables.
    SET @cSQLStmt = NULL;
    SET @iCount += 1;
END

-- =============================================================================================================================================
-- Clean-up Temp Objects.

IF OBJECT_ID('TempDB..#tblObjects') IS NOT NULL
    DROP TABLE #tblObjects;

-- =============================================================================================================================================
-- Check Changes

/*

SELECT
    OBJECT_SCHEMA_NAME(t.object_id) AS schema_name
    , t.name AS table_name    
    , i.name AS index_name
    , [ds].[name]
FROM
    sys.tables t
JOIN sys.indexes i
    ON t.object_id = i.object_id
JOIN sys.filegroups ds
    ON i.data_space_id = ds.data_space_id
WHERE 1 = 1

-- Check Table
AND t.[name] IN ('')

-- Check Index Name
AND [i].[name] IN ('')

*/
