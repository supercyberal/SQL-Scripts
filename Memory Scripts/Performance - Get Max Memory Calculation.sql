--Based on Jonathan Kehayias' blog post:
--http://www.sqlskills.com/blogs/jonathan/how-much-memory-does-my-sql-server-actually-need/

IF OBJECT_ID('tempdb..#mem') IS NOT NULL
   DROP TABLE #mem
GO

DECLARE
    @memInMachine DECIMAL(9, 2)
    , @memOsBase DECIMAL(9, 2)
    , @memOs4_16GB DECIMAL(9, 2)
    , @memOsOver_16GB DECIMAL(9, 2)
    , @memOsTot DECIMAL(9, 2)
    , @memForSql DECIMAL(9, 2)
    , @memForSQlMin DECIMAL(9, 2)
    , @CurrentMem DECIMAL(9, 2)
    , @sql NVARCHAR(4000)
    , @bPreview BIT;

CREATE TABLE #mem ( mem DECIMAL(9, 2) );

--Get current mem setting----------------------------------------------------------------------------------------------

SET @bPreview = 1;
SET @CurrentMem = (
                    SELECT
                        CAST(value AS INT) / 1024.
                    FROM
                        sys.configurations
                    WHERE
                        name = 'max server memory (MB)'
                  );


--Get memory in machine------------------------------------------------------------------------------------------------

IF CAST(LEFT(CAST(SERVERPROPERTY('ResourceVersion') AS VARCHAR(20)), 1) AS INT) = 9
    SET @sql = 'SELECT physical_memory_in_bytes/(1024*1024*1024.) FROM sys.dm_os_sys_info'
ELSE
BEGIN
    IF CAST(LEFT(CAST(SERVERPROPERTY('ResourceVersion') AS VARCHAR(20)), 2) AS INT) >= 11
	   SET @sql = 'SELECT physical_memory_kb/(1024*1024.) FROM sys.dm_os_sys_info'
    ELSE
	   SET @sql = 'SELECT physical_memory_in_bytes/(1024*1024*1024.) FROM sys.dm_os_sys_info'	
END


SET @sql = 'DECLARE @mem decimal(9,2) SET @mem = (' + @sql + ') INSERT INTO #mem(mem) VALUES(@mem)';

EXEC [sys].[sp_executesql] @sql;

SET @memInMachine = (SELECT MAX (mem) FROM #mem);

--Calculate recommended memory setting---------------------------------------------------------------------------------

SET @memOsBase = 1;

SET @memOs4_16GB = (
    CASE 
	   WHEN @memInMachine <= 4 THEN 0
	   WHEN @memInMachine > 4 AND @memInMachine <= 16 THEN ( @memInMachine - 4 ) / 4
	   WHEN @memInMachine >= 16 THEN 3
    END
)

SET @memOsOver_16GB = (
    CASE WHEN @memInMachine <= 16 THEN 
	   0
    ELSE 
	   ( @memInMachine - 16 ) / 8
    END
)

SET @memOsTot = @memOsBase + @memOs4_16GB + @memOsOver_16GB;
SET @memForSql = @memInMachine - @memOsTot;
SET @memForSQlMin = (@memForSql * .75);

SET @sql = 'EXEC [sys].[sp_configure] @configname = ''show advanced options'', @configvalue = 1;
RECONFIGURE WITH OVERRIDE;
EXEC [sys].[sp_configure] @configname = ''max server memory (MB)'', @configvalue = ' + CAST(CAST(@memForSql * 1024 AS INT) AS NVARCHAR(10)) + ';
RECONFIGURE WITH OVERRIDE;
EXEC [sys].[sp_configure] @configname = ''min server memory (MB)'', @configvalue = ' + CAST(CAST(@memForSQlMin * 1024 AS INT) AS NVARCHAR(10)) + ';
RECONFIGURE WITH OVERRIDE;
EXEC [sys].[sp_configure] @configname = ''show advanced options'', @configvalue = 0
RECONFIGURE WITH OVERRIDE;';

--Output findings------------------------------------------------------------------------------------------------------

IF @bPreview = 1
    SELECT
	   @CurrentMem AS CurrentMemConfig
	   , @memInMachine AS MemInMachine
	   , @memOsTot AS MemForOS
	   , @memForSql AS memForSql_MAX
	   , @memForSQlMin AS memForSql_MIN
	   , @sql AS CommandToExecute
	   , 'Assumes dedicated instance. Only use the value after you verify it is reasonable.' AS Comment
ELSE    
    EXEC [sys].[sp_executesql] @sql;
 

