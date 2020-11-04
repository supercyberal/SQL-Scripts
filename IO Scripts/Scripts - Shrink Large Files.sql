USE <DB_NAME>
GO
DECLARE @from INT;
DECLARE @leap INT;
DECLARE @to INT;
DECLARE @datafile VARCHAR(128);
DECLARE @cmd VARCHAR(512);
/*settings*/
SET @from = 0; /*Current size in MB*/
SET @to = 0; /*Goal size in MB*/
SET @datafile = '<DataFile_Name>'; /*Datafile name*/
SET @leap = 1024; /*Size of leaps in MB*/
PRINT '--- SATS SHRINK SCRIPT START ---';
WHILE (( @from - @leap ) > @to )
BEGIN
    SET @from = @from - @leap;
    SET @cmd = 'DBCC SHRINKFILE (' + @datafile + ', ' + CAST(@from AS VARCHAR(20)) + ')';
    PRINT @cmd;
    EXEC ( @cmd );
    PRINT '==>    SATS SHRINK SCRIPT - ' + CAST(( @from - @to ) AS VARCHAR(20)) + 'MB LEFT';
END;
SET @cmd = 'DBCC SHRINKFILE (' + @datafile + ', ' + CAST(@to AS VARCHAR(20)) + ')';
PRINT @cmd;
EXEC ( @cmd );
PRINT '--- SATS SHRINK SCRIPT COMPLETE ---';
GO