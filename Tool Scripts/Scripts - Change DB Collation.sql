/***********************************************************************************************************************************************
Description:	This is used to generate the necessary scripts to change table collation to a desired collation.

Notes:			ACOSTA - 2014-01-02
				Created.		
***********************************************************************************************************************************************/

------------------------------------------------------------------------------------------------------------------------------------------------
-- 1. Run proc ScriptDropTableKeys (RUN THIS IN TEXT MODE).

DECLARE @CollationName sysname

-- Set the desired collation
SET @CollationName = '';

-- If a collatio isn't provide, than use the instance's collation.
IF @CollationName IS NULL OR LEN(@CollationName) = 0
	SET @CollationName = CAST(SERVERPROPERTY('Collation') AS sysname);

DECLARE @TableName nvarchar(255)
DECLARE MyTableCursor CURSOR FAST_FORWARD
FOR 
	SELECT	DISTINCT [TABLE_NAME]
	FROM    information_schema.columns
	WHERE   (
		Data_Type LIKE '%char%'
		OR Data_Type LIKE '%text%'
	)
	AND COLLATION_NAME <> @CollationName
	ORDER BY [TABLE_NAME];

OPEN MyTableCursor;

FETCH NEXT FROM MyTableCursor INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC ScriptDropTableKeys @TableName;

    FETCH NEXT FROM MyTableCursor INTO @TableName;
END

CLOSE MyTableCursor;
DEALLOCATE MyTableCursor;
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- 2. Run script to change tables.

DECLARE 
	@TableName NVARCHAR(255)
	, @CollationName sysname
	, @ColumnName sysname
	, @IsNullable VARCHAR(3)
	, @SQLText NVARCHAR(MAX)
	, @DataType NVARCHAR(128)
	, @CharacterMaxLen INT

-- Set the desired collation
SET @CollationName = '';

-- If a collatio isn't provide, than use the instance's collation.
IF @CollationName IS NULL OR LEN(@CollationName) = 0
	SET @CollationName = CAST(SERVERPROPERTY('Collation') AS sysname);

-- Declare table cursor.
DECLARE MyTableCursor CURSOR FAST_FORWARD
FOR
	SELECT  name
	FROM    sys.tables
	WHERE   [type] = 'U'
			AND name <> 'sysdiagrams'
	ORDER BY name;

-- Open table cursor.
OPEN MyTableCursor;

FETCH NEXT FROM MyTableCursor INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
	-- Declare column cursor.
	DECLARE MyColumnCursor CURSOR FAST_FORWARD
	FOR
		SELECT  COLUMN_NAME
				,DATA_TYPE
				,CHARACTER_MAXIMUM_LENGTH
				,IS_NULLABLE
		FROM    information_schema.columns
		WHERE   table_name = @TableName
				AND (Data_Type LIKE '%char%'
						OR Data_Type LIKE '%text%'
					)
				AND COLLATION_NAME <> @CollationName
		ORDER BY ordinal_position;
		
		-- Open column cursor.
        OPEN MyColumnCursor;

        FETCH NEXT FROM MyColumnCursor INTO @ColumnName, @DataType, @CharacterMaxLen, @IsNullable;

        WHILE @@FETCH_STATUS = 0
		BEGIN
            SET @SQLText = 
				'ALTER TABLE ' 
				+ @TableName 
				+ ' ALTER COLUMN [' + @ColumnName + '] ' 
				+ @DataType
				+ CASE WHEN @DataType NOT IN ('text','ntext','image') THEN '(' + CASE WHEN @CharacterMaxLen = -1 THEN 'MAX' ELSE CAST(@CharacterMaxLen AS NVARCHAR(16)) END + ') ' ELSE ' ' END
				--+ '(' + CASE WHEN @CharacterMaxLen = -1 THEN 'MAX' ELSE CAST(@CharacterMaxLen AS NVARCHAR(16)) END + ') '
				+ 'COLLATE ' + @CollationName + ' ' 
				+ CASE WHEN @IsNullable = 'NO' THEN 'NOT NULL' ELSE 'NULL' END;
            
			-- Print alter statement.
			PRINT @SQLText;

			FETCH NEXT FROM MyColumnCursor INTO @ColumnName, @DataType, @CharacterMaxLen, @IsNullable;
		END

        CLOSE MyColumnCursor;
        DEALLOCATE MyColumnCursor;

	FETCH NEXT FROM MyTableCursor INTO @TableName;
END

CLOSE MyTableCursor;
DEALLOCATE MyTableCursor;
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- 3. Run proc ScriptCreateTableKeys (RUN THIS IN TEXT MODE).

DECLARE @CollationName sysname;

-- Set the desired collation
SET @CollationName = '';

-- If a collatio isn't provide, than use the instance's collation.
IF @CollationName IS NULL OR LEN(@CollationName) = 0
	SET @CollationName = CAST(SERVERPROPERTY('Collation') AS sysname);

DECLARE @TableName nvarchar(255)
DECLARE MyTableCursor CURSOR FAST_FORWARD
FOR 
	SELECT	DISTINCT [TABLE_NAME]
	FROM    information_schema.columns
	WHERE   (
		Data_Type LIKE '%char%'
		OR Data_Type LIKE '%text%'
	)
	AND COLLATION_NAME <> @CollationName
	ORDER BY [TABLE_NAME];

OPEN MyTableCursor;

FETCH NEXT FROM MyTableCursor INTO @TableName
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC ScriptCreateTableKeys @TableName;

    FETCH NEXT FROM MyTableCursor INTO @TableName;
END

CLOSE MyTableCursor;
DEALLOCATE MyTableCursor;
GO


------------------------------------------------------------------------------------------------------------------------------------------------
-- 5. Change DB to new collation.

DECLARE 
	@CollationName sysname
	, @SQLStmt NVARCHAR(MAX);

-- Set the desired collation
SET @CollationName = '';

-- If a collatio isn't provide, than use the instance's collation.
IF @CollationName IS NULL OR LEN(@CollationName) = 0
	SET @CollationName = CAST(SERVERPROPERTY('Collation') AS sysname);

SET @SQLStmt = 'ALTER DATABASE [' + DB_NAME() + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE';
SET @SQLStmt = @SQLStmt + CHAR(13) + 'ALTER DATABASE [' + DB_NAME() + '] COLLATE ' + @CollationName;
SET @SQLStmt = @SQLStmt + CHAR(13) + 'ALTER DATABASE [' + DB_NAME() + '] SET COMPATIBILITY_LEVEL = 110';
SET @SQLStmt = @SQLStmt + CHAR(13) + 'ALTER DATABASE [' + DB_NAME() + '] SET MULTI_USER';
SET @SQLStmt = @SQLStmt + CHAR(13) + 'EXEC [sys].[sp_changedbowner] @loginame = ''sa''';

--PRINT @SQLStmt;
EXEC (@SQLStmt);

--SELECT * FROM sys.[databases] d

*/