-- Specify your Database Name
USE <DB_NAME>
GO

/*
@ViewOnly = 1 allows you to run this script as a test only and review proposed actions.
@ViewOnly = 0 will perform either a reorg or rebuild, based on range of fragmentation value.
*/

-- Declare variables
SET NOCOUNT ON
DECLARE @tablename VARCHAR(128)
DECLARE @execstr VARCHAR(255)
DECLARE @objectid INT
DECLARE @indexid INT
DECLARE @frag DECIMAL
DECLARE @maxreorg DECIMAL
DECLARE @maxrebuild DECIMAL
DECLARE @IdxName VARCHAR(128)
DECLARE @ViewOnly BIT
DECLARE @ReorgOptions VARCHAR(255)
DECLARE @RebuildOptions VARCHAR(255)

-- Set to 1 to view proposed actions, set to 0 to Execute proposed actions:
SET @ViewOnly = 1

-- Decide on the maximum fragmentation to allow for a reorganize.
-- AVAILABLE OPTIONS: http://technet.microsoft.com/en-us/library/ms188388(SQL.90).aspx
SET @maxreorg = 20.0
SET @ReorgOptions = 'LOB_COMPACTION=ON'
-- Decide on the maximum fragmentation to allow for a rebuild.
SET @maxrebuild = 40.0



--NOTE: SQL Server will retain existing options if they are not specified.
--If you are running SQL Server Enterprise or Developer then you may inlude the ONLINE = ON option above.
SET @RebuildOptions = 'SORT_IN_TEMPDB=OFF, STATISTICS_NORECOMPUTE=OFF, ALLOW_ROW_LOCKS=ON, ALLOW_PAGE_LOCKS=ON'


-- Declare a cursor.
DECLARE tables CURSOR
FOR
    SELECT  '[' + CAST(TABLE_SCHEMA AS VARCHAR(100)) + ']' + '.' + '['
            + CAST(TABLE_NAME AS VARCHAR(100)) + ']' AS Table_Name
    FROM    INFORMATION_SCHEMA.TABLES
    WHERE   TABLE_TYPE = 'BASE TABLE'
--You may use the line below to specify a table.
--AND Table_Name = 'Results'


-- Create the temporary table.
IF EXISTS ( SELECT  name
            FROM    tempdb.dbo.sysobjects
            WHERE   name LIKE '#fraglist%' )
    DROP TABLE #fraglist

CREATE TABLE #fraglist
    (
     ObjectName CHAR(255)
    ,ObjectId INT
    ,IndexId INT
    ,LogicalFrag NVARCHAR(255)
    ,IndexName CHAR(255)
    )

-- Open the cursor.
OPEN tables

-- Loop through all the tables in the database.
FETCH NEXT
FROM tables
INTO @tablename

WHILE @@FETCH_STATUS = 0
    BEGIN
-- Display the dmv info of all indexes of the table
        INSERT  INTO #fraglist
                SELECT  @tablename
                       ,CAST(o.Object_Id AS NUMERIC) AS ObjectId
                       ,CAST(ips.Index_Id AS NUMERIC) AS IndexId
                       ,avg_fragmentation_in_percent AS LogicalFrag
                       ,i.name AS IndexName
                FROM    sys.dm_db_index_physical_stats(DB_ID(),
                                                       OBJECT_ID(''
                                                              + @tablename
                                                              + ''), NULL,
                                                       NULL, NULL) ips
                        JOIN sys.objects o ON o.object_id = ips.object_id
                        JOIN sys.indexes i ON ips.index_id = i.index_id
                                              AND ips.object_id = i.object_id
                ORDER BY ips.index_id 





        FETCH NEXT
FROM tables
INTO @tablename
    END

-- Close and deallocate the cursor.
CLOSE tables
DEALLOCATE tables


-- Declare the cursor for the list of indexes to be defragged.
DECLARE indexes CURSOR
FOR
    SELECT  ObjectName
           ,ObjectId
           ,IndexId
           ,LogicalFrag
           ,IndexName
    FROM    #fraglist
    WHERE   ((LogicalFrag >= @maxreorg)
             OR (LogicalFrag >= @maxrebuild)
            )
            AND INDEXPROPERTY(ObjectId, IndexName, 'IndexDepth') > 0

-- Open the cursor.
OPEN indexes

-- Loop through the indexes.
FETCH NEXT
FROM indexes
INTO @tablename, @objectid, @indexid, @frag, @IdxName

WHILE @@FETCH_STATUS = 0
    BEGIN
        IF (@frag >= @maxrebuild)
            BEGIN
                IF (@ViewOnly = 1)
                    BEGIN
                        PRINT 'Fragmentation at '
                            + RTRIM(CONVERT(VARCHAR(15), @frag)) + '%' + ' '
                            + 'WOULD be executing ALTER INDEX ' + '['
                            + RTRIM(@IdxName) + ']' + ' ON '
                            + RTRIM(@tablename) + ' REBUILD WITH ( '
                            + @RebuildOptions + ' )'
                    END
                ELSE
                    BEGIN
                        PRINT 'Fragmentation at '
                            + RTRIM(CONVERT(VARCHAR(15), @frag)) + '%' + ' '
                            + 'Now executing ALTER INDEX ' + '['
                            + RTRIM(@IdxName) + ']' + ' ON '
                            + RTRIM(@tablename) + ' REBUILD WITH ( '
                            + @RebuildOptions + ' )'
                        SELECT  @execstr = 'ALTER INDEX ' + '['
                                + RTRIM(@IdxName) + ']' + ' ON '
                                + RTRIM(@tablename) + ' REBUILD WITH ( '
                                + @RebuildOptions + ' )'
                        EXEC (@execstr)
                    END
            END
-- Determine if fragmentation surpasses the defined threshold for reorganizing:
        ELSE
            IF (@frag >= @maxreorg)
                BEGIN
                    IF (@ViewOnly = 1)
                        BEGIN
                            PRINT 'Fragmentation at '
                                + RTRIM(CONVERT(VARCHAR(15), @frag)) + '%'
                                + ' ' + 'WOULD be executing ALTER INDEX '
                                + '[' + RTRIM(@IdxName) + ']' + ' ON '
                                + RTRIM(@tablename) + ' REORGANIZE WITH ( '
                                + @ReorgOptions + ' )'
                        END
                    ELSE
                        BEGIN
                            PRINT 'Fragmentation at '
                                + RTRIM(CONVERT(VARCHAR(15), @frag)) + '%'
                                + ' ' + 'Now executing ALTER INDEX ' + '['
                                + RTRIM(@IdxName) + ']' + ' ON '
                                + RTRIM(@tablename) + ' REORGANIZE WITH ( '
                                + @ReorgOptions + ' )'
                            SELECT  @execstr = 'ALTER INDEX ' + '['
                                    + RTRIM(@IdxName) + ']' + ' ON '
                                    + RTRIM(@tablename)
                                    + ' REORGANIZE WITH ( ' + @ReorgOptions
                                    + ' )'
                            EXEC (@execstr)
                        END
                END

        FETCH NEXT
FROM indexes
INTO @tablename, @objectid, @indexid, @frag, @IdxName
    END

-- Close and deallocate the cursor.
CLOSE indexes
DEALLOCATE indexes

-- Delete the temporary table.
DROP TABLE #fraglist
GO