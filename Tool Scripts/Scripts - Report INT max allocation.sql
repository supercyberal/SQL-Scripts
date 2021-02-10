USE [master];
GO

IF OBJECT_ID('TempDB..##identity_columns') IS NOT NULL
    DROP TABLE ##identity_columns;

CREATE TABLE ##identity_columns
(
    [Database_Name] SYSNAME NOT NULL,
    [Schema_Name] SYSNAME NOT NULL,
    [Table_Name] SYSNAME NOT NULL,
    [Column_Name] SYSNAME NOT NULL,
    [Type_Name] SYSNAME NOT NULL,
    [Seed] NUMERIC(38,0) NOT NULL,
    [Increment] NUMERIC(38,0) NOT NULL,
    [Maximum_Identity_Value] BIGINT NOT NULL,
    [Current_Identity_Value] BIGINT NULL,
    [Percent_Consumed] AS CAST(CAST([Current_Identity_Value] AS DECIMAL(25,4)) / CAST([Maximum_Identity_Value] AS DECIMAL(25,4)) AS DECIMAL(25,4)) * 100
);

DECLARE 
    @PctThreshold DECIMAL(25,4) = 40
    , @Sql_Command VARCHAR(2048) = 'USE [?] ';

SELECT @Sql_Command += 'INSERT INTO ##identity_columns ([Database_Name], [Schema_Name], [Table_Name], [Column_Name], [Type_Name], [Seed], [Increment], [current_identity_value], [maximum_identity_value]) 
SELECT A.TABLE_CATALOG AS [DBNAME], 
       A.TABLE_SCHEMA AS [SCHEMA], 
       A.TABLE_NAME AS [TABLE], 
       B.COLUMN_NAME AS [COLUMN], 
       B.DATA_TYPE AS [Type], 
       IDENT_SEED(A.TABLE_NAME) AS Seed, 
       IDENT_INCR(A.TABLE_NAME) AS Increment, 
       IDENT_CURRENT(A.TABLE_NAME) AS Curr_Value, 
       Type_Limit = CASE LOWER(B.DATA_TYPE)
                        WHEN ''bigint'' THEN
                            CAST(9223372036854775807 AS BIGINT)
                        WHEN ''int'' THEN
                            CAST(2147483647 AS BIGINT)
                        WHEN ''smallint'' THEN
                            CAST(32767 AS BIGINT)
                        WHEN ''tinyint'' THEN
                            CAST(255 AS BIGINT)
                        WHEN ''decimal'' THEN
                            REPLICATE(''9'', B.NUMERIC_PRECISION)
                        WHEN ''numeric'' THEN
                            REPLICATE(''9'', B.NUMERIC_PRECISION)
                    END 
FROM INFORMATION_SCHEMA.TABLES A, 
     INFORMATION_SCHEMA.COLUMNS B 
WHERE A.TABLE_CATALOG = B.TABLE_CATALOG 
      AND A.TABLE_SCHEMA = B.TABLE_SCHEMA 
      AND A.TABLE_NAME = B.TABLE_NAME 
      AND COLUMNPROPERTY(OBJECT_ID(B.TABLE_NAME), B.COLUMN_NAME, ''IsIdentity'') = 1 
      AND OBJECTPROPERTY(OBJECT_ID(A.TABLE_NAME), ''TableHasIdentity'') = 1 
      AND A.TABLE_TYPE = ''BASE TABLE''';

-- Run for every DB in the instance.
EXEC sp_MSforeachdb @Sql_Command;

SELECT *
FROM ##identity_columns
WHERE percent_consumed >= @PctThreshold;
GO
