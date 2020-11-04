----------------------------------------------------------------------------------------------------------------------------------------------
-- Create Long Running Jobs table
-- Ensure a USE statement has been executed first. 
-- For example in this tip I'm executing it against AdventureWorks2012 database.

SET NOCOUNT ON;

DECLARE @First [smallint]
  , @Last [smallint]
  , @IsUnique [smallint]
  , @HasNonKeyCols [char](1)
  , @TableName [varchar](256)
  , @IndexName [varchar](256)
  , @IndexType [varchar](13)
  , @IndexColumns [varchar](1000)
  , @IncludedColumns [varchar](1000)
  , @IndexColsOrder [varchar](1000)
  , @IncludedColsOrder [varchar](1000) 

DECLARE @Indexes TABLE
    (
      [RowNo] [smallint] IDENTITY(1, 1)
    , [TableName] [varchar](256)
    , [IndexName] [varchar](256)
    , [IsUnique] [smallint]
    , [IndexType] [varchar](13)
    )

DECLARE @AllIndexes TABLE
    (
      [RowNo] [smallint] IDENTITY(1, 1)
    , [TableName] [varchar](256)
    , [IndexName] [varchar](256)
    , [IndexType] [varchar](13)
    , [KeyColumns] [varchar](512)
    , [NonKeyColumns] [varchar](512)
    , [KeyColumnsOrder] [varchar](512)
    , [NonKeyColumnsOrder] [varchar](512)
    , [IsUnique] [char](1)
    , [HasNonKeyColumns] [char](1)
    )

IF OBJECT_ID('Tempdb.dbo.#Temp') IS NOT NULL 
    DROP TABLE #Temp

SELECT  o.[object_id] AS [ObjectID]
      , OBJECT_NAME(o.[object_id]) AS [TableName]
      , i.[index_id] AS [IndexID]
      , i.[name] AS [IndexName]
      , CASE i.[type]
          WHEN 0 THEN 'Heap'
          WHEN 1 THEN 'Clustered'
          WHEN 2 THEN 'Non-Clustered'
          WHEN 3 THEN 'XML'
          ELSE 'Unknown'
        END AS [IndexType]
      , ic.[column_id] AS [ColumnID]
      , c.[name] AS [ColumnName]
      , ic.[is_included_column] [IncludedColumns]
      , i.[is_unique] AS [IsUnique]
INTO    #Temp
FROM    sys.indexes i
INNER JOIN sys.objects o
ON      i.object_id = o.object_id
        AND o.type = 'U'
        AND i.index_id > 0
INNER JOIN sys.index_columns ic
ON      i.index_id = ic.index_id
        AND i.object_id = ic.object_id
INNER JOIN sys.columns c
ON      c.column_id = ic.column_id
        AND c.object_id = ic.object_id

INSERT  INTO @Indexes
        SELECT DISTINCT
                [TableName]
              , [IndexName]
              , [IsUnique]
              , [IndexType]
        FROM    #Temp

SELECT  @First = MIN([RowNo])
FROM    @Indexes
SELECT  @Last = MAX([RowNo])
FROM    @Indexes

WHILE @First <= @Last 
    BEGIN
        SET @IndexColumns = NULL
        SET @IncludedColumns = NULL
        SET @IncludedColsOrder = NULL
        SET @IndexColsOrder = NULL

        SELECT  @TableName = [TableName]
              , @IndexName = [IndexName]
              , @IsUnique = [IsUnique]
              , @IndexType = [IndexType]
        FROM    @Indexes
        WHERE   [RowNo] = @First

        SELECT  @IndexColumns = COALESCE(@IndexColumns + ', ', '')
                + [ColumnName]
        FROM    #Temp
        WHERE   [TableName] = @TableName
                AND [IndexName] = @IndexName
                AND [IncludedColumns] = 0
        ORDER BY [IndexName]
              , [ColumnName]

        SELECT  @IncludedColumns = COALESCE(@IncludedColumns + ', ', '')
                + [ColumnName]
        FROM    #Temp
        WHERE   [TableName] = @TableName
                AND [IndexName] = @IndexName
                AND [IncludedColumns] = 1
        ORDER BY [IndexName]
              , [ColumnName]

        SELECT  @IndexColsOrder = COALESCE(@IndexColsOrder + ', ', '')
                + [ColumnName]
        FROM    #Temp
        WHERE   [TableName] = @TableName
                AND [IndexName] = @IndexName
                AND [IncludedColumns] = 0

        SELECT  @IncludedColsOrder = COALESCE(@IncludedColsOrder + ', ', '')
                + [ColumnName]
        FROM    #Temp
        WHERE   [TableName] = @TableName
                AND [IndexName] = @IndexName
                AND [IncludedColumns] = 1

        SET @HasNonKeyCols = 'N'

        IF @IncludedColumns IS NOT NULL 
            BEGIN
                SET @HasNonKeyCols = 'Y'
            END

        INSERT  INTO @AllIndexes
                (
                  [TableName]
                , [IndexName]
                , [IndexType]
                , [IsUnique]
                , [KeyColumns]
                , [KeyColumnsOrder]
                , [HasNonKeyColumns]
                , [NonKeyColumns]
                , [NonKeyColumnsOrder] 
                )
                SELECT  @TableName
                      , @IndexName
                      , @IndexType
                      , CASE @IsUnique
                          WHEN 1 THEN 'Y'
                          WHEN 0 THEN 'N'
                        END
                      , @IndexColumns
                      , @IndexColsOrder
                      , @HasNonKeyCols
                      , @IncludedColumns
                      , @IncludedColsOrder

        SET @First = @First + 1 

    END
 --End of While block

SELECT  'Listing All Indexes' AS [Comments]

SELECT  [TableName]
      , [IndexName]
      , [IndexType]
      , [KeyColumns]
      , [HasNonKeyColumns]
      , [NonKeyColumns]
      , [KeyColumnsOrder]
      , [NonKeyColumnsOrder]
      , [IsUnique]
FROM    @AllIndexes

SELECT  'Listing Duplicate Indexes' AS [Comments]

SELECT DISTINCT
        a1.[TableName]
      , a1.[IndexName]
      , a1.[IndexType]
      , a1.[KeyColumns]
      , a1.[HasNonKeyColumns]
      , a1.[NonKeyColumns]
      , a1.[KeyColumnsOrder]
      , a1.[NonKeyColumnsOrder]
      , a1.[IsUnique]
FROM    @AllIndexes a1
JOIN    @AllIndexes a2
ON      a1.[TableName] = a2.TableName
        AND a1.[IndexName] <> a2.[IndexName]
        AND a1.[KeyColumns] = a2.[KeyColumns]
        AND ISNULL(a1.[NonKeyColumns], '') = ISNULL(a2.[NonKeyColumns], '')
WHERE   a1.[IndexType] <> 'XML'

SET NOCOUNT OFF;
GO