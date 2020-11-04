
/*SQL Differential Backup Size Prediction - */

IF ISNULL(OBJECT_ID('tempdb.dbo.##showFileStats'), 1) <> 1
    DROP TABLE ##showFileStats
           
CREATE TABLE ##showFileStats
    (
     fileID INT
    ,fileGroup INT
    ,totalExtents BIGINT
    ,usedExtents BIGINT
    ,logicalFileName VARCHAR(500)
    ,filePath VARCHAR(1000)
    )

IF ISNULL(OBJECT_ID('tempdb.dbo.##DCM'), 1) <> 1
    DROP TABLE ##DCM
           
CREATE TABLE ##DCM
    (
     parentObject VARCHAR(5000)
    ,[object] VARCHAR(5000)
    ,field VARCHAR(5000)
    ,value VARCHAR(5000)
    )
           
/*we need to get a list of all the files in the database.  each file needs to be looked at*/          
INSERT  INTO ##showFileStats
        EXEC ('DBCC SHOWFILESTATS with tableresults'
            )

DECLARE @currentFileID INT
   ,@totalExtentsOfFile BIGINT
   ,@dbname VARCHAR(100)
   ,@SQL VARCHAR(200)
   ,@currentDCM BIGINT
   ,@step INT
           
SET @dbname = DB_NAME()
SET @step = 511232

DECLARE myCursor SCROLL CURSOR
FOR
    SELECT  fileID
           ,totalExtents
    FROM    ##showFileStats

OPEN myCursor
FETCH NEXT FROM myCursor INTO @currentFileID, @totalExtentsOfFile

/*look at each differential change map page in each data file of the database and put the output into ##DCM*/
WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @currentDCM = 6
        WHILE @currentDCM <= @totalExtentsOfFile * 8
            BEGIN 
                SET @SQL = 'dbcc page(' + @dbname + ', '
                    + CAST(@currentFileID AS VARCHAR) + ', '
                    + CAST(@currentDCM AS VARCHAR) + ', 3) WITH TABLERESULTS'
                INSERT  INTO ##DCM
                        EXEC (@SQL
                            )
                SET @currentDCM = @currentDCM + @step
            END
           
        FETCH NEXT FROM myCursor INTO @currentFileID, @totalExtentsOfFile
    END
CLOSE myCursor
DEALLOCATE myCursor

/*remove all unneeded rows from our results table*/
DELETE  FROM ##DCM
WHERE   value = 'NOT CHANGED'
        OR parentObject NOT LIKE 'DIFF_MAP%'
--SELECT * FROM ##DCM

/*sum the extentTally column*/
SELECT  SUM(extentTally) AS totalChangedExtents
       ,SUM(extentTally) / 16 AS 'diffPrediction(MB)'
       ,SUM(extentTally) / 16 / 1024 AS 'diffPrediction(GB)'
FROM    /*create extentTally column*/
        (SELECT extentTally = CASE WHEN secondChangedExtent > 0
                                   THEN CAST(secondChangedExtent AS BIGINT)
                                        - CAST(firstChangedExtent AS BIGINT)
                                        + 1
                                   ELSE 1
                              END
         FROM   /*parse the 'field' column to give us the first and last extents of the range*/
                (SELECT (SUBSTRING(field, (SELECT   CHARINDEX(':', field, 0)
                                          ) + 1,
                                   (CHARINDEX(')', field, 0)) - (CHARINDEX(':',
                                                              field, 0)) - 1))
                        / 8 AS firstChangedExtent
                       ,secondChangedExtent = CASE WHEN CHARINDEX(':', field,
                                                              CHARINDEX(':',
                                                              field, 0) + 1) > 0
                                                   THEN (SUBSTRING(field,
                                                              (CHARINDEX(':',
                                                              field,
                                                              CHARINDEX(':',
                                                              field, 0) + 1)
                                                              + 1),
                                                              (CHARINDEX(')',
                                                              field,
                                                              CHARINDEX(')',
                                                              field, 0) + 1))
                                                              - (CHARINDEX(':',
                                                              field,
                                                              CHARINDEX(':',
                                                              field, 0) + 1))
                                                              - 1)) / 8
                                                   ELSE ''
                                              END
                 FROM   ##DCM
                ) parsedFieldColumn
        ) extentTallyColumn