USE tempdb;
GO

sp_configure 'show advanced options', 1;
GO
RECONFIGURE;
GO

sp_configure 'clr enabled', 1;
GO
RECONFIGURE;
GO
	
sp_configure 'Ole Automation Procedures', 1;
GO
RECONFIGURE;
GO

--=====================================================================
-- File I/O COM section starts  
--=====================================================================

-----------------------------------------------------------------------
-- This SP opens a file according to the input file path 
-- and return the file handle
-----------------------------------------------------------------------

IF OBJECT_ID('sp_openFile', 'P') IS NOT NULL 
	DROP PROCEDURE sp_openFile;
GO

CREATE PROCEDURE sp_openFile
(
	@filePath varchar(max),
	@mode varchar(max)
)
AS 

BEGIN
	DECLARE @fileHandle int, @fileSystem int, @errorCode int, @openMode int;

	EXECUTE @errorCode = sp_OACreate 'Scripting.FileSystemObject', @fileSystem OUTPUT;
	
	IF (@@ERROR > 0 OR @errorCode > 0 Or @fileSystem < 0) BEGIN
		RAISERROR (N'The COM Object [%s] cannot be created. Please check with System Adminstrator.', -1, @errorCode, N'Scripting.FileSystemObject');
		RETURN -1;
	END

	IF @mode = 'IMPORT' BEGIN
		SET @openMode = 1;
	END
	ELSE IF @mode = 'EXPORT' BEGIN 
		SET @openMode = 2;
	END
	ELSE BEGIN
		-- For appending
		SET @openMode = 8;
	END

	EXECUTE @errorCode = sp_OAMethod @fileSystem, 'OpenTextFile', @fileHandle OUTPUT, @filePath, @openMode, 1, 0;

	IF (@@ERROR > 0 OR @errorCode > 0 OR @fileHandle < 0) BEGIN
		RAISERROR (N'The file [%s] cannot be opened. Please check with System Adminstrator.', -1, @errorCode, @filePath);
		EXEC sp_OADestroy @FileSystem;
		RETURN -1;
	END

	EXEC sp_OADestroy @FileSystem;

	RETURN @fileHandle;
END

GO

-----------------------------------------------------------------------
-- This SP checks the existence of the file given by the file path
-- returns 1 if the file exists, 0 if the file does not exist, -1 for error
-----------------------------------------------------------------------

IF OBJECT_ID('sp_isFileExist', 'P') IS NOT NULL 
	DROP PROCEDURE sp_isFileExist;
GO

CREATE PROCEDURE sp_isFileExist
(
	@filePath varchar(max)
)
AS 

BEGIN
	DECLARE @isExist int, @fileSystem int, @errorCode int, @openMode int;

	EXECUTE @errorCode = sp_OACreate 'Scripting.FileSystemObject', @fileSystem OUTPUT;
	
	IF (@@ERROR > 0 OR @errorCode > 0 Or @fileSystem < 0) BEGIN
		RAISERROR (N'The COM Object [%s] cannot be created. Please check with System Adminstrator.', -1, @errorCode, N'Scripting.FileSystemObject');
		RETURN -1;
	END

	EXECUTE @errorCode = sp_OAMethod @fileSystem, 'FileExists', @isExist OUTPUT, @filePath;
	EXECUTE @errorCode = sp_OADestroy @fileSystem;

	RETURN @isExist;
END

GO

-----------------------------------------------------------------------
-- This SP closes the file given by the file handle
-----------------------------------------------------------------------

IF OBJECT_ID('sp_closeFile', 'P') IS NOT NULL 
	DROP PROCEDURE sp_closeFile;
GO

CREATE PROCEDURE sp_closeFile
(
	@fileHandle int
)
AS 

BEGIN
	DECLARE @errorCode int;

	EXECUTE @errorCode = sp_OAMethod @fileHandle, 'Close', NULL
	
	IF (@@ERROR > 0 OR @errorCode > 0) BEGIN
		RAISERROR (N'The file cannot be closed. Please check with System Adminstrator.', -1, @errorCode, @fileHandle);
		RETURN -1;
	END

	EXECUTE @errorCode = sp_OADestroy @fileHandle

	IF (@@ERROR > 0 OR @errorCode > 0) BEGIN
		RAISERROR (N'The file handle cannot be destroyed. Please check with System Adminstrator.', -1, @errorCode, @fileHandle);
		RETURN -1;
	END

	RETURN 0;
END

GO

-----------------------------------------------------------------------
-- This SP writes the input string into the file given by the file handle
-----------------------------------------------------------------------

IF OBJECT_ID('sp_writeToFile', 'P') IS NOT NULL 
	DROP PROCEDURE sp_writeToFile;
GO

CREATE PROCEDURE sp_writeToFile
(
	@fileHandle int,
	@stringToWrite varchar(max)
)
AS 

BEGIN
	DECLARE @errorCode int;

	-- concat the string length and the string to write first
	IF (@stringToWrite IS NULL) OR (@stringToWrite = '') BEGIN
		SET @stringToWrite = N'0, ';
	END
	ELSE BEGIN
		SET @stringToWrite = CAST(LEN(@stringToWrite) AS varchar(max)) + N', ' + @stringToWrite;
	END

	-- then write the command
	EXECUTE @errorCode = sp_OAMethod @fileHandle, 'WriteLine', NULL, @stringToWrite;
	IF (@@ERROR > 0 OR @errorCode > 0) BEGIN
		RAISERROR (N'The string [%s] cannot be written to the file [%d]. Please check with System Adminstrator.', -1, @errorCode, @stringToWrite, @fileHandle);
		RETURN -1;
	END

	RETURN 0;
END

GO

-----------------------------------------------------------------------
-- This SP reads a line from the file given by the file handle
-----------------------------------------------------------------------

IF OBJECT_ID('sp_readFromFile', 'P') IS NOT NULL 
	DROP PROCEDURE sp_readFromFile;
GO

CREATE PROCEDURE sp_readFromFile
(
	@fileHandle int,
	@outputString varchar(max) OUTPUT
)
AS 

BEGIN
	DECLARE @errorCode int, @eof int, @message varchar(8000), @strlen bigint, @getlenStr varchar(8000), @isSkipping binary;
	
	SET @outputString = '';

	EXECUTE @errorCode = sp_OAMethod @fileHandle, 'AtEndOfStream', @eof OUTPUT;
	-- eof
	IF @eof != 0 BEGIN
		RETURN 0;
	END

	EXECUTE @errorCode = sp_OAMethod @fileHandle, 'Read(1)', @message OUTPUT;

	IF (@@ERROR > 0 OR @errorCode > 0) BEGIN
		RAISERROR (N'The file [%d] cannot be read. Please check with System Adminstrator.', -1, @errorCode, @fileHandle);
		RETURN -1;
	END

	SET @strlen = 0;
	SET @isSkipping = 1;

	-- get the length of the command
	-- skip other characters at the front of the line before we get the strlen
	WHILE @message != N',' BEGIN
		IF (@@ERROR > 0) OR (@errorCode > 0) BEGIN
			-- error
			RAISERROR (N'The file [%d] cannot be read. Please check with System Adminstrator.', -1, @errorCode, @fileHandle);
			RETURN -1;
		END
		ELSE IF (@message >= '0') AND (@message <= '9') BEGIN
			SET @strlen = @strlen * 10 + CONVERT(bigint, @message);
			SET @isSkipping = 0;
		END
		ELSE IF @isSkipping = 0 BEGIN
			-- invalid file format
			RETURN -1;
		END

		EXECUTE @errorCode = sp_OAMethod @fileHandle, 'AtEndOfStream', @eof OUTPUT;
		-- eof
		IF @eof != 0 BEGIN
			RETURN 0;
		END

		EXECUTE @errorCode = sp_OAMethod @fileHandle, 'Read(1)', @message OUTPUT;
	END

	EXECUTE @errorCode = sp_OAMethod @fileHandle, 'Read(1)', @message OUTPUT;
	
	-- then get the actual command depends on the length
	-- max 4000 characters for each read 
	WHILE @strlen > 0 BEGIN
		IF @strlen > 4000 BEGIN
			SET @getlenStr = 'Read(4000)';
			SET @strlen = @strlen - 4000;
		END
		ELSE BEGIN
			SET @getlenStr = 'Read(' + CAST(@strlen AS varchar(max)) + ')';
			SET @strlen = 0;
		END

		EXECUTE @errorCode = sp_OAMethod @fileHandle, @getlenStr, @message OUTPUT;

		IF (@@ERROR > 0 OR @errorCode > 0) BEGIN
			RAISERROR (N'The file [%d] cannot be read. Please check with System Adminstrator.', -1, @errorCode, @fileHandle);
			RETURN -1;
		END

		SET @outputString = @outputString + @message;
	END

	RETURN 0;
END

GO

--=====================================================================
-- File I/O COM section ends
--=====================================================================

--=====================================================================
-- Command handling section starts
--=====================================================================

-----------------------------------------------------------------------
-- This sp gets the string sitting inside the first pair of [] from the input string    
-----------------------------------------------------------------------

IF OBJECT_ID('getFirstParameter', 'FN') IS NOT NULL 
	DROP FUNCTION getFirstParameter;
GO

CREATE FUNCTION getFirstParameter
(
	@inputCommand varchar(max)
)
	RETURNS nvarchar(max)
AS

BEGIN
	DECLARE @firstParameter varchar(max), @leftIndex bigint, @rightIndex bigint;

	-- the index of [ should be 1
	IF SUBSTRING(@inputCommand, 1, 1) != N'[' BEGIN
		RETURN NULL;
	END

	SET @leftIndex = 1;
	SET @rightIndex = CHARINDEX(@inputCommand, N']');

	IF @rightIndex <= @leftIndex BEGIN
		RETURN NULL;
	END

	SET @firstParameter = SUBSTRING(@inputCommand, 2, @rightIndex - 2);
	RETURN @firstParameter;
END

GO

-----------------------------------------------------------------------
-- This sp handles the extra action protocol of a command  
-----------------------------------------------------------------------

IF OBJECT_ID('sp_handleCommandProtocol', 'P') IS NOT NULL 
	DROP PROCEDURE sp_handleCommandProtocol;
GO

CREATE PROCEDURE sp_handleCommandProtocol
(
	@inputCommand varchar(max)
)
AS 

BEGIN
	DECLARE @outputCommand varchar(max), @extraCommand1 nvarchar(max), @extraCommand2 nvarchar(max), @extraCommand3 nvarchar(max), @passAll bit;

	SET @passAll = 0;

	SET @outputCommand = @inputCommand;

	WHILE @passAll = 0 BEGIN
		-- checkVersionReturnString command
		IF SUBSTRING(@outputCommand, 1, LEN(N'[checkVersionReturnString]')) = N'[checkVersionReturnString]' BEGIN
			SET @outputCommand = SUBSTRING(@outputCommand, LEN(N'[checkVersionReturnString]'), LEN(@outputCommand));

			-- get the version number
			SET @extraCommand1 = dbo.getFirstParameter(@outputCommand);
			IF @extraCommand1 IS NOT NULL BEGIN
				SET @outputCommand = SUBSTRING(@outputCommand, LEN(@extraCommand1) + 2, LEN(@outputCommand));
			END

			-- get the check string
			SET @extraCommand2 = dbo.getFirstParameter(@outputCommand);
			IF @extraCommand2 IS NOT NULL BEGIN
				SET @outputCommand = SUBSTRING(@outputCommand, LEN(@extraCommand2) + 2, LEN(@outputCommand));
			END

			-- apply checkVersionReturnString
			SET @extraCommand3 = dbo.checkVersionReturnString(@extraCommand2, CAST(@extraCommand1 AS BIGINT));
			IF @extraCommand3 IS NULL BEGIN
				SET @outputCommand = REPLACE(@outputCommand, @extraCommand2, @extraCommand3);
			END
		END
		-- more command protocols can be added here in the future, by adding an else if statement
		-- if there is no more extra command, then we exit this loop
		ELSE BEGIN
			SET @passAll = 1;
		END
	END

	RETURN @outputCommand;
END

GO

-----------------------------------------------------------------------
-- This sp copies the clone commands from a file to the clone command tables  
-----------------------------------------------------------------------

IF OBJECT_ID('sp_getCommandFromFile', 'P') IS NOT NULL 
	DROP PROCEDURE sp_getCommandFromFile;
GO

CREATE PROCEDURE sp_getCommandFromFile
(
	@clone_filename varchar(max)
)
AS 

BEGIN
	DECLARE @errorCode int, @errorCode2 int, @fileHandle int, @sql_script varchar(max), @original_index_name nvarchar(max), @table_name nvarchar(max), @schema_name nvarchar(max), @column_name nvarchar(max), @phaseNumber int;
	
	EXECUTE @fileHandle = sp_openFile @clone_filename, 'IMPORT';
	SET @phaseNumber = 1;

	IF @fileHandle < 0 BEGIN
		RAISERROR (N'Cannot open file [%s] for read. Please check with DBA.', -1, -1, @clone_filename);
	END
	ELSE BEGIN
		WHILE @phaseNumber > 0 BEGIN
			EXECUTE	@errorCode = sp_readFromFile @fileHandle, @sql_script OUTPUT;

			-- file read error
			IF @errorCode = -1 BEGIN
				RAISERROR (N'Error: read from file [%s, %s]. Please check with DBA.', -1, -1, @clone_filename, @sql_script);
			END
			-- eof or invalid format
			ELSE IF @errorCode = 0 AND @sql_script = '' BEGIN
				BREAK;
			END
			-- phase = fill SQLScriptTable
			ELSE IF @sql_script = '[SQLScriptTable]' BEGIN
				PRINT 'Filling Table [SQLScriptTable]...';
				SET @phaseNumber = 1;
			END
			-- phase = fill StatisticsCommandTable
			ELSE IF @sql_script = '[StatisticsCommandTable]' BEGIN
				PRINT 'Filling Table [StatisticsCommandTable]...';
				SET @phaseNumber = 2;
			END
			-- phase = fill AutoCreatedStatisticsCommandTable
			ELSE IF @sql_script = '[AutoCreatedStatisticsCommandTable]' BEGIN
				PRINT 'Filling Table [AutoCreatedStatisticsCommandTable]...';
				SET @phaseNumber = 3;
			END
			-- phase = fill DataCommandTable
			ELSE IF @sql_script = '[DataCommandTable]' BEGIN
				PRINT 'Filling Table [DataCommandTable]...';
				SET @phaseNumber = 4;
			END

			-- all the rest are regular commands
			ELSE IF @sql_script != '' BEGIN
				-- phase 1: fill the SQLScriptTable
				-- TABLE ##SQLScriptTable(sql_script varchar(max) NOT NULL, counter bigint IDENTITY PRIMARY KEY CLUSTERED);
				-- need 1 field
				IF @phaseNumber = 1 BEGIN
					-- regardless of the error, still insert to table for execution and reporting
					-- for performance, we can add a condition for checking the errorCode
					EXECUTE sp_addCloneCommand @sql_script;
				END
				
				-- phase 2: fill the StatisticsCommandTable
				-- TABLE ##StatisticsCommandTable(sql_script varchar(max) NOT NULL, original_index_name nvarchar(max), clone_index_name nvarchar(max), counter bigint IDENTITY PRIMARY KEY CLUSTERED);
				-- need 2 fields
				ELSE IF @phaseNumber = 2 BEGIN
					EXECUTE	@errorCode = sp_readFromFile @fileHandle, @original_index_name OUTPUT;
					
					IF @original_index_name = '' BEGIN
						SET @original_index_name = NULL;
					END
					
					IF @errorCode = -1 BEGIN
						RAISERROR (N'Error: read from file [%s, %s, %s]. Please check with DBA.', -1, -1, @clone_filename, @sql_script, @original_index_name);
					END

					-- regardless of the error, still insert to table for execution and reporting
					-- for performance, we can add a condition for checking the errorCode					
					EXECUTE sp_addStatisticsCommand @sql_script, @original_index_name;
				END
				
				-- phase 3: fill the AutoCreatedStatisticsCommandTable
				-- TABLE ##AutoCreatedStatisticsCommandTable(sql_script varchar(max) NOT NULL, table_name nvarchar(max), schema_name nvarchar(max), column_name nvarchar(max), original_index_name nvarchar(max));		
				-- need 5 fields
				ELSE IF @phaseNumber = 3 BEGIN
					EXECUTE	@errorCode = sp_readFromFile @fileHandle, @table_name OUTPUT;
					SET @errorCode2 = @errorCode;

					EXECUTE @errorCode = sp_readFromFile @fileHandle, @schema_name OUTPUT;
					SET @errorCode2 = @errorCode + @errorCode2;

					EXECUTE @errorCode = sp_readFromFile @fileHandle, @column_name OUTPUT;
					SET @errorCode2 = @errorCode + @errorCode2; 

					EXECUTE @errorCode = sp_readFromFile @fileHandle, @original_index_name OUTPUT;
					SET @errorCode2 = @errorCode + @errorCode2; 

					IF @errorCode2 < 0 BEGIN
						RAISERROR (N'Error: read from file [%s, %s, %s, %s, %s, %s]. Please check with DBA.', -1, -1, @clone_filename, @sql_script, @table_name, @schema_name, @column_name, @original_index_name);
					END

					-- regardless of the error, still insert to table for execution and reporting
					-- for performance, we can add a condition for checking the errorCode					
					EXECUTE sp_addAutoCreatedStatisticsCommand @sql_script, @table_name, @schema_name, @column_name, @original_index_name;
				END

				-- phase 4: fill the DataCommandTable
				-- TABLE ##DataCommandTable(sql_script varchar(max) NOT NULL, counter bigint IDENTITY PRIMARY KEY CLUSTERED);
				-- need 1 field
				ELSE IF @phaseNumber = 4 BEGIN
					-- regardless of the error, still insert to table for execution and reporting
					-- for performance, we can add a condition for checking the errorCode
					EXECUTE sp_addCloneCommand @sql_script, 'DATA';
				END
			END
			ELSE BEGIN
				BREAK;
			END
		END
	END

	EXECUTE @errorCode = sp_closeFile @fileHandle;
--
	RETURN @fileHandle;
END

GO

-----------------------------------------------------------------------
-- This sp copies the clone commands from the clone command tables to a given file 
-----------------------------------------------------------------------

IF OBJECT_ID('sp_copyCommandToFile', 'P') IS NOT NULL 
	DROP PROCEDURE sp_copyCommandToFile;
GO

CREATE PROCEDURE sp_copyCommandToFile
(
	@clone_filename varchar(max)
)
AS 

BEGIN
	DECLARE @errorCode int, @errorCode2 int, @fileHandle int, @sql_script varchar(max), @original_index_name nvarchar(max), @table_name nvarchar(max), 
			@schema_name nvarchar(max), @column_name nvarchar(max), @phaseNumber int;
	
	EXECUTE @fileHandle = sp_openFile @clone_filename, 'W';
	SET @phaseNumber = 1;

	IF @fileHandle < 0 BEGIN
		RAISERROR (N'Cannot open file [%s] for write. Please check with DBA.', -1, -1, @clone_filename);
	END
	ELSE BEGIN
		WHILE (1 = 1) BEGIN
			IF @phaseNumber = 1 BEGIN
				SET @sql_script = '[SQLScriptTable]';
				EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;

				DECLARE cur CURSOR LOCAL FOR
					SELECT sql_script, '', '', '' FROM ##SQLScriptTable
					ORDER BY counter;
			END

			ELSE IF @phaseNumber = 2 BEGIN
				SET @sql_script = '[StatisticsCommandTable]';
				EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;

				DECLARE cur CURSOR LOCAL FOR
					SELECT sql_script, '', '', original_index_name FROM ##StatisticsCommandTable
					ORDER BY counter;
			END

			ELSE IF @phaseNumber = 3 BEGIN
				SET @sql_script = '[AutoCreatedStatisticsCommandTable]';
				EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;

				DECLARE cur CURSOR LOCAL FOR
					SELECT sql_script, table_name, schema_name, original_index_name FROM ##AutoCreatedStatisticsCommandTable;
			END

			ELSE IF @phaseNumber = 4 BEGIN
				SET @sql_script = '[DataCommandTable]';
				EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;

				DECLARE cur CURSOR LOCAL FOR
					SELECT sql_script, '', '', '' FROM ##DataCommandTable
					ORDER BY counter;
			END

			ELSE BEGIN
				BREAK;
			END

			OPEN cur;
			FETCH NEXT FROM cur INTO @sql_script, @table_name, @schema_name, @original_index_name;

			WHILE @@FETCH_STATUS = 0 BEGIN
				IF @phaseNumber = 1 OR @phaseNumber = 4 BEGIN
					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;

					IF @errorCode = -1 BEGIN
						RAISERROR (N'Error: write to file [%s, %s]. Please check with DBA.', -1, -1, @clone_filename, @sql_script);
					END
				END

				ELSE IF @phaseNumber = 2 BEGIN
					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;
					SET @errorCode2 = @errorCode;
				
					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @original_index_name;
					SET @errorCode2 = @errorCode + @errorCode2;

					IF @errorCode2 < 0 BEGIN
						RAISERROR (N'Error: write to file [%s, %s, %s]. Please check with DBA.', -1, -1, @clone_filename, @sql_script, @original_index_name);
					END
				END

				ELSE IF @phaseNumber = 3 BEGIN
					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @sql_script;
					SET @errorCode2 = @errorCode;
				
					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @table_name;
					SET @errorCode2 = @errorCode + @errorCode2;

					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @schema_name;
					SET @errorCode2 = @errorCode + @errorCode2;

					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @column_name;
					SET @errorCode2 = @errorCode + @errorCode2;

					EXECUTE	@errorCode = sp_writeToFile @fileHandle, @original_index_name;
					SET @errorCode2 = @errorCode + @errorCode2;
			
					IF @errorCode2 < 0 BEGIN
						RAISERROR (N'Error: write to file [%s, %s, %s, %s, %s, %s]. Please check with DBA.', -1, -1, @clone_filename, @sql_script, @table_name, @schema_name, @column_name, @original_index_name);
					END
				END

				ELSE BEGIN
					BREAK;
				END

				FETCH NEXT FROM cur INTO @sql_script, @table_name, @schema_name, @original_index_name;
			END

			CLOSE cur;
			DEALLOCATE cur;

			SET @phaseNumber = @phaseNumber + 1;
		END
	END

	EXECUTE @errorCode = sp_closeFile @fileHandle;
--
	RETURN @fileHandle;
END

GO

--=====================================================================
-- Command handling section end
--=====================================================================

--=====================================================================
-- Check version and check type functions start
--=====================================================================

-----------------------------------------------------------------------
-- This function returns the string for create column statement 
-- based on the column type   
-----------------------------------------------------------------------
IF OBJECT_ID('getColumnTypeString', 'FN') IS NOT NULL 
	DROP FUNCTION getColumnTypeString;
GO

CREATE FUNCTION getColumnTypeString
(
	@column_type varchar(max),
	@column_precision bigint,
	@column_scale bigint,
	@column_max_length bigint,
	@collation_name nvarchar(max)
)
	RETURNS varchar(max)
AS 

BEGIN 
	DECLARE @column_field varchar(max);
	
	SET @column_field = '[' + @column_type + ']';

	IF @column_type IN ('decimal', 'numeric', 'float') BEGIN
		IF @column_precision <> 0 BEGIN
			SET @column_field = @column_field + ' (' + CAST(@column_precision AS nvarchar(max));

			IF @column_scale <> 0
				SET @column_field = @column_field + ', ' + CAST(@column_scale AS nvarchar(max)) + ')';
			ELSE
				SET @column_field = @column_field + ')';
			END
		END
	ELSE IF @column_type IN ('time', 'datetime2', 'datetimeoffset') BEGIN
		SET @column_field = @column_field + '(' + CAST(@column_scale AS nvarchar(max)) + ')';
	END
	ELSE IF @column_type IN ('char', 'nchar', 'varchar', 'nvarchar', 'varbinary') BEGIN
		IF @column_max_length = -1
			SET @column_field = @column_field + '(max)';
		ELSE BEGIN
			IF @column_type IN ('nchar', 'nvarchar')
				SET @column_max_length = @column_max_length / 2;
					
			SET @column_field = @column_field + '(' + CAST(@column_max_length AS nvarchar(max)) + ')';
		END

		IF @collation_name IS NOT NULL
			SET @column_field = @column_field + ' COLLATE ' + @collation_name;
	END

	RETURN @column_field;
END

GO

-----------------------------------------------------------------------
-- This function returns the VALUE string based on the data type
-- mainly for insert statement   
-----------------------------------------------------------------------
IF OBJECT_ID('getValueStringByDataType', 'FN') IS NOT NULL 
	DROP FUNCTION getValueStringByDataType;
GO

CREATE FUNCTION getValueStringByDataType
(
	@valueString nvarchar(max),
	@dataType nvarchar(max)
)
	RETURNS nvarchar(max)
AS 

BEGIN 
	DECLARE @outputValueString nvarchar(max);
	
	SET @outputValueString = @valueString;

	IF (@outputValueString != 'NULL') AND @dataType IN ('time', 'datetime', 'datetime2', 'datetimeoffset', 'date', 'smalldatetime', 'char', 'nchar', 'varchar', 'nvarchar', 'timestamp') BEGIN
		SET @outputValueString = '''' + @outputValueString + '''';
	END
	
	RETURN @outputValueString;
END

GO

-----------------------------------------------------------------------
-- This function checks and returns the input string for differentiating 
-- the sql script among different versions  
-----------------------------------------------------------------------
IF OBJECT_ID('checkVersionReturnString', 'FN') IS NOT NULL 
	DROP FUNCTION checkVersionReturnString;
GO

CREATE FUNCTION checkVersionReturnString
(
	@string_for_checking nvarchar(max),
	@supported_version bigint
)
	returns nvarchar(max)
AS 

BEGIN
	DECLARE @sql_version_str nvarchar(max), @sql_version bigint;
	SET @sql_version_str = CAST(SERVERPROPERTY('productversion') AS nvarchar(max));
	SET @sql_version_str = SUBSTRING(@sql_version_str, 1, CHARINDEX('.', @sql_version_str) -1);
	SET @sql_version = CAST(@sql_version_str AS bigint);

	IF @sql_version >= @supported_version BEGIN
		RETURN @string_for_checking;
	END

	RETURN NULL;
END

GO

--=====================================================================
-- Check version and check type functions end
--=====================================================================

--=====================================================================
-- Command execution and command insertion section starts 
--=====================================================================

-----------------------------------------------------------------------
-- This SP prints and executes a sql commmand 
-----------------------------------------------------------------------
IF OBJECT_ID('sp_printAndExecute', 'P') IS NOT NULL 
	DROP PROCEDURE sp_printAndExecute;
GO

CREATE PROCEDURE sp_printAndExecute
	@sql_script varchar(max)
AS

BEGIN TRY
	PRINT 'Executing {' + char(13) + @sql_script + char(13) + '} ...';

	EXECUTE (@sql_script);
END TRY

BEGIN CATCH
	PRINT 'ERROR: ' + ERROR_MESSAGE(); 
END CATCH

GO

-----------------------------------------------------------------------
-- This SP inserts a clone command to the command table
-- These commands will be excuted in the final step
-----------------------------------------------------------------------
IF OBJECT_ID('sp_addCloneCommand', 'P') IS NOT NULL 
	DROP PROCEDURE sp_addCloneCommand;
GO

CREATE PROCEDURE sp_addCloneCommand
	@sql_script varchar(max),
	@tableOption varchar(max) = 'DEFAULT'
AS

-- PRINT (@sql_script);

IF @tableOption = 'DATA' BEGIN
	INSERT ##DataCommandTable VALUES(@sql_script);
END
ELSE BEGIN
	INSERT ##SQLScriptTable VALUES(@sql_script);
END

GO

-----------------------------------------------------------------------
-- This SP inserts a statistics command to the command table
-- These commands will be excuted in the final step
-----------------------------------------------------------------------
IF OBJECT_ID('sp_addStatisticsCommand', 'P') IS NOT NULL 
	DROP PROCEDURE sp_addStatisticsCommand;
GO

CREATE PROCEDURE sp_addStatisticsCommand
	@sql_script varchar(max),
	@original_index_name nvarchar(max) = NULL,
	@clone_index_name nvarchar(max) = NULL
AS

INSERT ##StatisticsCommandTable VALUES(@sql_script, @original_index_name, @clone_index_name);

GO

-----------------------------------------------------------------------
-- This SP inserts an auto created statistics command to the command table
-- These commands will be used to generate statistics commands 
-- and inserted to ##StatisticsCommandTable
-----------------------------------------------------------------------
IF OBJECT_ID('sp_addAutoCreatedStatisticsCommand', 'P') IS NOT NULL 
	DROP PROCEDURE sp_addAutoCreatedStatisticsCommand;
GO

CREATE PROCEDURE sp_addAutoCreatedStatisticsCommand
	@sql_script nvarchar(max),
	@table_name nvarchar(max),
	@schema_name nvarchar(max),
	@column_name nvarchar(max),
	@original_index_name nvarchar(max)
AS

INSERT ##AutoCreatedStatisticsCommandTable VALUES(@sql_script, @table_name, @schema_name, @column_name, @original_index_name);

GO

--=====================================================================
-- Command execution and command insertion section ends 
--=====================================================================

--=====================================================================
-- Clone script section starts
--=====================================================================

-----------------------------------------------------------------------
-- This SP creates and setup a clone database of the source database 
-----------------------------------------------------------------------
IF OBJECT_ID('sp_createCloneDatabase', 'P') IS NOT NULL 
	DROP PROCEDURE sp_createCloneDatabase;
GO

CREATE PROCEDURE sp_createCloneDatabase
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> CREATE CLONE DATABASE';

-- create clone database
SET @sql_script = 
	'USE master;' + char(13) +
	'CREATE DATABASE [' + @clone_database_name + '];';
EXECUTE sp_addCloneCommand @sql_script;

-- turn off AUTO_CREATE_STATISTICS and AUTO_UPDATE_STATISTICS
SET @sql_script =
	'USE [' + @clone_database_name + '];' + char(13) + 
	'ALTER DATABASE [' + @clone_database_name + '] SET AUTO_CREATE_STATISTICS ON;' + char(13) +
	'ALTER DATABASE [' + @clone_database_name + '] SET AUTO_UPDATE_STATISTICS ON;' + char(13) +
	'ALTER DATABASE [' + @clone_database_name + '] SET QUOTED_IDENTIFIER ON;' + char(13) +
	'EXECUTE (N''SP_CONFIGURE ''''CLR ENABLED'''', 1; RECONFIGURE;'');';
EXECUTE sp_addCloneCommand @sql_script;

GO

-----------------------------------------------------------------------
-- This SP clones all XML schema collections of the source database 
-- Based on sys.xml_schema_collections, sys.xml_schema_namespaces, sys.xml_schema_components
-- Not yet ready to use, this sp still under implementation
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllXMLCollections', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllXMLCollections;
GO

CREATE PROCEDURE sp_cloneAllXMLCollections
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY XML SCHEMA COLLECTIONS';

DECLARE @TempSchemaCollections TABLE(collection_name nvarchar(max), schema_name nvarchar(max), namespace_name nvarchar(max), component_name nvarchar(max), component_id bigint,
		symbol_space_desc nvarchar(max), kind_desc nvarchar(max), scoping_xml_component_id bigint, is_qualified binary, placement_id bigint, is_default_fixed binary, 
		min_occurences bigint, max_occurences bigint, default_value nvarchar(max), type_allows_mixed_content binary, attribute_must_be_qualified binary, 
		model_compositor_desc nvarchar(max), child_component_id bigint, child_component_name nvarchar(max), collection_id bigint, namespace_id bigint, 
		UNIQUE NONCLUSTERED (collection_id, namespace_id, scoping_xml_component_id, placement_id));

-- create clone XML schema collections
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT xsc.name AS collection_name, SCHEME_NAME(xsc.schema_id) AS schema_name, xsn.name AS namespace_name, xscm.name AS component_name, xscm.xml_component_id AS componet_id, ' +
	'xscm.symbol_space_desc AS symbol_space_desc, xscm.kind_desc AS kind_desc, xscm.scoping_xml_component_id AS scoping_xml_component_id, xscm.is_qualified AS is_qualified, ' +
	'xscp.placement_id AS placement_id, xscp.is_default_fixed AS is_default_fixed, xscp.min_occurences AS min_occurences, xscp.max_occurences AS max_occurences, ' + 
	'xscp.default_value AS default_value, xst.allows_mixed_content AS type_allows_mixed_content, xsa.is_default_fixed AS attribute_must_be_qualified, ' +
	'xsmg.compositor_desc AS model_compositor_desc, xscm2.xml_component_id AS child_component_id, xscm2.name AS child_component_name, ' +
	'xsc.collection_id AS collection_id, xsn.namespace_id AS namespace_id' + char(13) + 
	'FROM sys.xml_schema_collections AS xsc' + char(13) + 
	'INNER JOIN sys.xml_schema_namespaces AS xsn ON xsn.xml_collection_id = xsc.xml_collection_id' + char(13) +
	'LEFT JOIN sys.xml_schema_components AS xscm ON xscm.xml_collection_id = xsn.xml_collection_id AND xscm.xml_namespace_id = xsn.xml_namespace_id AND xsc.name <> ''sys''' + char(13) +
	'LEFT JOIN sys.xml_schema_component_placements AS xscp ON xscp.placed_xml_component_id = xscm.xml_component_id' + char(13) +
	'LEFT JOIN sys.xml_schema_types AS xst ON xst.xml_component_id = xscm.xml_component_id' + char(13) +
	'LEFT JOIN sys.xml_schema_attributes AS xsa ON xsa.xml_component_id = xscm.xml_component_id' + char(13) +
	'LEFT JOIN sys.xml_schema_facets AS xsf ON xsf.xml_component_id = xscm.xml_component_id' + char(13) +
	'LEFT JOIN sys.xml_schema_elements AS xse ON xse.xml_component_id = xscm.xml_component_id' + char(13) +
	'LEFT JOIN sys.xml_schema_model_groups AS xsmg ON xsmg.xml_component_id = xscm.xml_component_id' + char(13) +
	'LEFT JOIN sys.xml_schema_component_placements AS xscp2 ON xscp2.xml_component_id = xscm.xml_component_id AND xscp2.placement_id = 1' + char(13) +
	'LEFT JOIN sys.xml_schema_components AS xscm2 ON xscp2.placed_xml_component_id = xscm2.xml_component_id;';
INSERT @TempSchemaCollections EXECUTE sp_printAndExecute @sql_script;

DECLARE @collection_name nvarchar(max), @schema_name nvarchar(max), @namespace_name nvarchar(max), @component_name nvarchar(max), @component_id bigint, @symbol_space_desc nvarchar(max), 
		@kind_desc nvarchar(max), @scoping_xml_component_id bigint, @is_qualified binary, @placement_id bigint, @is_default_fixed binary, @min_occurences bigint, @max_occurences bigint, 
		@default_value nvarchar(max), @type_allows_mixed_content binary, @attribute_must_be_qualified binary, @model_compositor_desc nvarchar(max), @child_component_id bigint, 
		@child_component_name nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT collection_name, schema_name namespace_name, component_name, component_id, symbol_space_desc, kind_desc, scoping_xml_component_id, is_qualified, placement_id, is_default_fixed, 
			min_occurences, max_occurences, default_value, type_allows_mixed_content, attribute_must_be_qualified, model_compositor_desc, child_component_id, child_component_name
	FROM @TempSchemaCollections
	ORDER BY collection_id, namespace_id, scoping_xml_component_id, placement_id DESC;

-- the following are used to keep the content for each xml collection doucment
DECLARE @previous_collection_name nvarchar(max), @previous_namespace_name nvarchar(max), @sys_namespace_field varchar(max), @header_field varchar(max), @body_field varchar(max), 
		@footer_field varchar(max), @component_body_tag nvarchar(max), @component_line nvarchar(max);
SET @sys_namespace_field = '';
SET @previous_collection_name = '';
SET @previous_namespace_name = '';

OPEN cur;
FETCH NEXT FROM cur INTO @collection_name, @schema_name, @namespace_name, @component_name, @component_id, @symbol_space_desc, @kind_desc, @scoping_xml_component_id, @is_qualified,
		@placement_id, @is_default_fixed, @min_occurences, @max_occurences, @default_value, @type_allows_mixed_content, @attribute_must_be_qualified, @model_compositor_desc, 
		@child_component_id, @child_component_name;

-- loop through each XML component and create the XML collection in the clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	-- handle sys namespace, special case, should be at the top of the result table because collection_id = 1
	IF @collection_name = 'sys' BEGIN
		SET @sys_namespace_field = @sys_namespace_field + char(13) + 'xmlns="' + @namespace_name + '"';

		FETCH NEXT FROM cur INTO @collection_name, @schema_name, @namespace_name, @component_name, @component_id, @symbol_space_desc, @kind_desc, @scoping_xml_component_id, @is_qualified,
				@placement_id, @is_default_fixed, @min_occurences, @max_occurences, @default_value, @type_allows_mixed_content, @attribute_must_be_qualified, @model_compositor_desc, 
				@child_component_id, @child_component_name;

		CONTINUE;
	END

	-- a XML namespace can have multiple components
	-- the result table is ordered by collection_id and namespace_id, so if either namespace_name or collection_name changes, then it should be a new namespace
	IF @previous_namespace_name <> @namespace_name OR @previous_collection_name <> @collection_name BEGIN
		-- add the clone command before handling the next xml collection
		IF @previous_collection_name <> '' BEGIN
			SET @sql_script = @header_field + @body_field + @footer_field;
			EXECUTE sp_addCloneCommand @sql_script;
		END

		-- a XML collection can have multiple schemas
		-- the result table is ordered by collection_id, so if the collection_name changes, then it should be a new collection
		IF @previous_collection_name <> @collection_name BEGIN
			PRINT '>>> XML Collection [' + @collection_name + '] is found ...';

			SET @header_field = 
				'USE [' + @clone_database_name + '];' + char(13) + 
				'CREATE XML SCHEMA COLLECTION [' + @schema_name + '].[' + @collection_name + '] AS' + char(13) +
				'N''<?xml?>';
		END
		-- add the namespace content into the collection body before handling the next namespace
		-- to prevent the sql statement becoming too big, it is better to use another alter statement instead of appending to the same create statement
		ELSE BEGIN
			SET @header_field = 
				'USE [' + @clone_database_name + '];' + char(13) + 
				'ALTER XML SCHEMA COLLECTION [' + @schema_name + '].[' + @collection_name + '] ADD' + char(13) +
				'N''<?xml?>';
		END

		PRINT '>>> Namespace [' + @namespace_name + '] is found in Collection [' + @collection_name + '] ...';
		
		SET @header_field = @header_field + char(13) + 
			'<xsd:schema targerNamespace="' + @namespace_name + '"' + 
			@sys_namespace_field + '>';

		SET @body_field = '';
		SET @footer_field = char(13) + '</xsd:schema>'';';
	END

	-- handle each component of the namespace
	PRINT '>>> Component [' + @component_name + '] in Space [' + @kind_desc + '] is found ...';

	-- if see this line when debug, mean need the type / kind is not implemented in the following if else staetment, please add it
	SET @component_line = 'notYetImplementedPleaseFix';

	IF @symbol_space_desc = 'NONE' BEGIN
		SET @component_line = @kind_desc;
	END
	ELSE IF @symbol_space_desc = 'TYPE' BEGIN
		IF @kind_desc = 'SIMPLE_TYPE' 
			SET @component_line = 'simpleType';
		ELSE IF @kind_desc = 'COMPLEX_SIMPLE_TYPE'
			SET @component_line = 'complexSimpleType';
		ELSE IF @kind_desc = 'COMPLEX_TYPE'
			SET @component_line = 'complexType';
		
		IF @type_allows_mixed_content = 1
			SET @component_line = @component_line + ' mixed="true"';	
	END
	ELSE IF @symbol_space_desc = 'ELEMENT' BEGIN
		IF @kind_desc = 'ELEMENT' 
			SET @component_line = 'element';
	END
	ELSE IF @symbol_space_desc = 'MODEL_GROUP' BEGIN
		IF @model_compositor_desc = 'XSD_ALL_GROUP'
			SET @component_line = 'all';
		ELSE IF @model_compositor_desc = 'XSD_CHOICE_GROUP'
			SET @component_line = 'choice';
		ELSE IF @model_compositor_desc = 'XSD_SEQUENCE_GROUP'
			SET @component_line = 'sequence';
	END
	ELSE IF @symbol_space_desc = 'ATTRIBUTE' BEGIN
		IF @kind_desc = 'ATTRIBUTE' 
			SET @component_line = 'attribute';

		IF @attribute_must_be_qualified = 1
			SET @component_line = @component_line + ' use="required"';
	END
	ELSE IF @symbol_space_desc = 'ATTRIBUTE_GROUP' BEGIN
		SET @component_line = @kind_desc;
	END
	ELSE
		SET @component_line = 'UNKNOWN - PLEASE CHECK';

	-- common options
	IF @component_name IS NOT NULL
		SET @component_line = @component_line + ' name="' + @component_name + '"';

	IF @min_occurences > 0 
		SET @component_line = @component_line + ' minOccurs="' + CAST(@min_occurences AS nvarchar(max)) + '"';
	
	IF @max_occurences > @min_occurences
		SET @component_line = @component_line + ' maxOccurs="' + CAST(@max_occurences AS nvarchar(max)) + '"';

	IF @default_value IS NOT NULL
		SET @component_line = @component_line + ' default="' + @default_value + '"';

	-- create content of the parent
	SET @component_body_tag = '[>[>BODY:' + CAST(@scoping_xml_component_id AS nvarchar(max)) + '<]<]';

	-- note: sorted by parent component i
	-- create content of the child 
	-- if the child id > parent_id, means the content of the parent will be expanded by the child if the further 
	-- if child id <= parent id, means the child type is predefined, so add the child type - no need to expand  
	IF @child_component_id > @component_id BEGIN
		SET @component_line = 
			'<xsd:' + @component_line + '>' + char(13) +
			'[>[>BODY:' + CAST(@component_id AS nvarchar(max)) + '<]<]' + char(13) +
			'</xsd:' + @component_line + '>';
	END
	ELSE BEGIN
		SET @component_line = '<xsd:' + @component_line + ' type="' + @child_component_name + '"/>';
	END

	-- note: components are sorted in desc order with the placement id
	-- expand the xml scheme content, scoping_xml_component_id = NULL means at root level, so just add the component into the front
	-- placement_id = 1 means the last child of the parent, so no need to reserve the body for next child
	-- placement_id > 1 means need to add the content of the child and reserve the body space for next child
	IF @scoping_xml_component_id IS NULL
		SET @body_field = char(13) + @component_line + @body_field;
	ELSE IF @placement_id = 1
		SET @body_field = REPLACE(@body_field, @component_body_tag, @component_line);
	ELSE
		SET @body_field = REPLACE(@body_field, @component_body_tag, @component_body_tag + char(13) + @component_line);

	SET @previous_collection_name = @collection_name;
	SET @previous_namespace_name = @namespace_name;

	FETCH NEXT FROM cur INTO @collection_name, @schema_name, @namespace_name, @component_name, @component_id, @symbol_space_desc, @kind_desc, @scoping_xml_component_id, @is_qualified,
			@placement_id, @is_default_fixed, @min_occurences, @max_occurences, @default_value, @type_allows_mixed_content, @attribute_must_be_qualified, @model_compositor_desc, 
			@child_component_id, @child_component_name;
END

CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_collection_name <> '' BEGIN
	SET @sql_script = @header_field + @body_field + @footer_field;
	EXECUTE sp_addCloneCommand @sql_script;
END

GO

-----------------------------------------------------------------------
-- This SP clones all schemas of the source database 
-- Based on sys.schemas 
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllSchemas', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllSchemas;
GO

CREATE PROCEDURE sp_cloneAllSchemas
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY SCHEMAS';

DECLARE @TempSchemas TABLE(schema_name nvarchar(max));

-- create clone schemas
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT name as schema_name' + char(13) + 
	'FROM sys.schemas;';
INSERT @TempSchemas EXECUTE sp_printAndExecute @sql_script;

DECLARE @schema_name nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT schema_name FROM @TempSchemas;

OPEN cur;
FETCH NEXT FROM cur INTO @schema_name;

-- loop through each schema and create in the clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Schema [' + @schema_name + '] is found ...';

	-- create schema if not exists
	SET @sql_script = 
		'EXECUTE(''' + char(13) +
		'USE [' + @clone_database_name + '];' + char(13) + 
		'IF SCHEMA_ID(''''' + @schema_name + ''''') IS NULL' + char(13) +
		'EXECUTE (N''''CREATE SCHEMA [' + @schema_name + '];'''');' + char(13) +
		''');';
	EXECUTE sp_addCloneCommand @sql_script;

	SET @sql_script = 
		'USE [' + @clone_database_name + '];' + char(13) +  
		'GRANT CONTROL, TAKE OWNERSHIP, ALTER, EXECUTE, INSERT, DELETE, UPDATE, SELECT, REFERENCES, VIEW CHANGE TRACKING, VIEW DEFINITION ON SCHEMA::[' + @schema_name + '] TO ' + CURRENT_USER + ' WITH GRANT OPTION;';
	EXECUTE sp_addCloneCommand @sql_script;

	FETCH NEXT FROM cur INTO @schema_name;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all types of the source database 
-- Based on sys.types
-- Excluded is_assumble_type, default_object_id, rule_object_id, xml columns indexes and constraints
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllTypes', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllTypes;
GO

CREATE PROCEDURE sp_cloneAllTypes
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY TYPES';

DECLARE @TempTypes TABLE(type_name nvarchar(max), type_description nvarchar(max), schema_name nvarchar(max), max_length bigint, precision bigint,
		scale bigint, collation_name nvarchar(max), is_nullable binary, is_assembly_type binary, column_name nvarchar(max), 
		column_type nvarchar(max), column_max_length bigint, column_precision bigint, column_scale bigint, column_collation_name nvarchar(max), 
		column_is_nullable binary, column_is_ansi_padded binary, column_is_rowguidcol binary, column_is_identity binary, column_is_filestream binary, 
		column_is_replicated binary, column_is_xml_document binary, column_is_sparse binary, computed_definition nvarchar(max), computed_is_persisted binary, 
		user_type_id bigint, object_id bigint, column_id bigint, UNIQUE NONCLUSTERED(object_id, column_id, user_type_id));

-- create clone user defined types
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT t.name AS type_name, TYPE_NAME(t.system_type_id) AS type_description, SCHEMA_NAME(t.schema_id) AS schema_name, t.max_length AS max_length, ' +
	't.precision AS precision, t.scale AS scale, t.collation_name AS collation_name, t.is_nullable AS is_nullable, t.is_assembly_type AS is_assembly_type, ' +
	'c.name AS column_name, TYPE_NAME(c.user_type_id) AS column_type, c.max_length AS column_max_length, c.precision AS column_precision, ' +
	'c.scale AS column_scale, c.collation_name AS column_collation_name, c.is_nullable AS column_is_nullable, c.is_ansi_padded AS column_is_ansi_padded, ' +
	'c.is_rowguidcol AS column_is_rowguidcol, c.is_identity AS column_is_identity, c.is_filestream AS column_is_filestream, c.is_replicated AS column_is_replicated, ' +
	'c.is_xml_document AS column_is_xml_document, cc.is_sparse AS column_is_sparse, cc.definition AS computed_definition, cc.is_persisted AS computed_is_persisted, ' +
	't.user_type_id AS user_type_id, c.object_id AS object_id, c.column_id AS column_id' + char(13) + 
	'FROM sys.types AS t' + char(13) +
	'LEFT JOIN sys.table_types AS tt ON t.user_type_id = tt.user_type_id' + char(13) +
	'LEFT JOIN sys.columns AS c ON c.object_id = tt.type_table_object_id' + char(13) +
	'LEFT JOIN sys.computed_columns AS cc ON c.object_id = cc.object_id AND c.column_id = cc.column_id' + char(13) + 
	'WHERE t.is_user_defined = 1 AND t.is_assembly_type = 0';
INSERT @TempTypes EXECUTE sp_printAndExecute @sql_script;

DECLARE @type_name nvarchar(max), @type_description nvarchar(max), @schema_name nvarchar(max), @max_length bigint, @precision bigint,
		@scale bigint, @collation_name nvarchar(max), @is_nullable binary, @is_assembly_type binary, @column_name nvarchar(max), 
		@column_type nvarchar(max), @column_max_length bigint, @column_precision bigint, @column_scale bigint, @column_collation_name nvarchar(max), 
		@column_is_nullable binary, @column_is_ansi_padded binary, @column_is_rowguidcol binary, @column_is_identity binary, 
		@column_is_filestream binary, @column_is_replicated binary, @column_is_xml_document binary, @column_is_sparse binary, 
		@computed_definition nvarchar(max), @computed_is_persisted binary  
DECLARE cur CURSOR LOCAL FOR
	SELECT type_name, type_description, schema_name, max_length, precision,	scale, collation_name, is_nullable, is_assembly_type, column_name,
			column_type, column_max_length, column_precision, column_scale, column_collation_name, column_is_nullable, column_is_ansi_padded, 
			column_is_rowguidcol, column_is_identity, column_is_filestream, column_is_replicated, column_is_xml_document, column_is_sparse,
			computed_definition, computed_is_persisted
	FROM @TempTypes
	ORDER BY object_id, column_id, user_type_id;

OPEN cur;
FETCH NEXT FROM cur INTO @type_name, @type_description, @schema_name, @max_length, @precision, @scale, @collation_name, @is_nullable, @is_assembly_type,
		@column_name, @column_type, @column_max_length, @column_precision, @column_scale, @column_collation_name, @column_is_nullable, @column_is_ansi_padded, 
		@column_is_rowguidcol, @column_is_identity, @column_is_filestream, @column_is_replicated, @column_is_xml_document, @column_is_sparse,
		@computed_definition, @computed_is_persisted;

-- the following are used for checking the change of type and table type statement
DECLARE @previous_type_name nvarchar(max), @column_field nvarchar(max), @prefix_field nvarchar(max), @suffix_field nvarchar(max), @separator nvarchar(max);
SET @previous_type_name = '';
SET @column_field = '';
SET @separator = char(13);

-- loop through each type and create in the clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	-- a table type can have multiple columns
	-- the result table is ordered by object_id, column_id and user_type_id, so if either user_type_id changes, then it should be a new type
	IF @previous_type_name <> @type_name BEGIN
		-- add the clone command before handling the next type statement
		IF @previous_type_name <> '' BEGIN
			SET @sql_script = @prefix_field + @column_field + @suffix_field;
			EXECUTE sp_addCloneCommand @sql_script;

			SET @column_field = '';
			SET @separator = char(13);
		END

		PRINT '>>> Type [' + @type_name + '] is found ...';

		SET @prefix_field = 
			'USE [' + @clone_database_name + '];' + char(13) + 
			'CREATE TYPE [' + @schema_name + '].[' + @type_name + ']';

		-- create a basic type
		IF @column_name IS NULL BEGIN
			IF @collation_name IS NOT NULL BEGIN
				SET @prefix_field =
					'ALTER DATABASE [' + @clone_database_name + '] COLLATE ' + @collation_name + ';' + char(13) +
					@prefix_field;
			END

			SET @column_field = @column_field + ' FROM ' + dbo.getColumnTypeString(@type_description, @precision, @scale, @max_length, NULL);

			IF @is_nullable = 0
				SET @column_field = @column_field + ' NOT NULL';
			ELSE
				SET @column_field = @column_field + ' NULL';

			SET @suffix_field = ';';
		END
		-- create a table type
		ELSE BEGIN
			SET @column_field = @column_field + ' AS TABLE (';

			SET @suffix_field = char(13) + ');';
		END
	END

	IF @column_name IS NOT NULL BEGIN
		PRINT '>>> Column [' + @column_name + '] is found in Table Type [' + @type_name + '] ...';

		SET @column_field = @column_field + @separator + '[' + @column_name + ']';
		SET @separator = ',' + char(13);
		
		-- computed column
		IF @computed_definition IS NOT NULL BEGIN
			SET @column_field = @column_field + ' AS ' + @computed_definition;
			
			IF @computed_is_persisted = 1 BEGIN
				SET @column_field = @column_field + ' PERSISTED';
			
				IF @column_is_nullable = 0
					SET @column_field = @column_field + ' NOT NULL';
			END
		END		
		-- normal column
		ELSE BEGIN
			SET @column_field = @column_field + ' ' + dbo.getColumnTypeString(@column_type, @column_precision, @column_scale, @column_max_length, @column_collation_name);

			IF @column_is_filestream = 1
				SET @column_field = @column_field + ' FILESTREAM';

			IF @column_is_nullable = 0
				SET @column_field = @column_field + ' NOT NULL';
			ELSE
				SET @column_field = @column_field + ' NULL';

			IF @column_is_identity = 1 BEGIN
				SET @column_field = @column_field + ' IDENTITY';
				
				IF @column_is_replicated = 0
					SET @column_field = @column_field + ' NOT FOR REPLICATION';
			END

			IF @column_is_sparse = 1
				SET @column_field = @column_field + ' SPARSE';
		END
	END

	SET @previous_type_name = @type_name;

	FETCH NEXT FROM cur INTO @type_name, @type_description, @schema_name, @max_length, @precision, @scale, @collation_name, @is_nullable, @is_assembly_type,
			@column_name, @column_type, @column_max_length, @column_precision, @column_scale, @column_collation_name, @column_is_nullable, @column_is_ansi_padded, 
			@column_is_rowguidcol, @column_is_identity, @column_is_filestream, @column_is_replicated, @column_is_xml_document, @column_is_sparse,
			@computed_definition, @computed_is_persisted;
END

CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_type_name <> '' BEGIN
	SET @sql_script = @prefix_field + @column_field + @suffix_field;
	EXECUTE sp_addCloneCommand @sql_script;
END

GO

-----------------------------------------------------------------------
-- This SP clones all assemblies of the source database 
-- Based on sys.assemblies
-- Omitted permission_set
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllAssemblies', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllAssemblies;
GO

CREATE PROCEDURE sp_cloneAllAssemblies
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY ASSEMBLIES';

DECLARE @TempAssemblies TABLE(assembly_name nvarchar(max), permission_set bigint, content varbinary(max));

-- create clone user defined assemblies
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT a.name AS assembly_name, a.permission_set AS permission_set, af.content AS content' + char(13) + 
	'FROM sys.assemblies AS a' + char(13) +
	'INNER JOIN sys.assembly_files AS af ON a.assembly_id = af.assembly_id' + char(13) +
	'WHERE a.is_user_defined = 1;'
INSERT @TempAssemblies EXECUTE sp_printAndExecute @sql_script;

DECLARE @assembly_name nvarchar(max), @permission_set bigint, @content varbinary(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT assembly_name, permission_set, content FROM @TempAssemblies;

OPEN cur;
FETCH NEXT FROM cur INTO @assembly_name, @permission_set, @content;

DECLARE @content_str varchar(max);

-- loop through each assembly and create in the clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Assembly [' + @assembly_name + '] is found ...';

	-- convert content to str
	IF @content IS NULL
		SET @content_str = 'NULL';
	ELSE
		SET @content_str = '0x' + CAST('' as xml).value('xs:hexBinary(sql:variable("@content") )', 'varchar(max)'); 

	SET @sql_script = 
		'USE [' + @clone_database_name + '];' + char(13) + 
		'CREATE ASSEMBLY [' + @assembly_name + ']' + char(13) +
		'FROM ' + @content_str + ';'; 

	-- Omitted permission_set
	--SET @sql_script = 
	--	CASE 
	--		WHEN @permission_set = 1 THEN @sql_script + char(13) + 'WITH PERMISSION_SET = SAFE;'
	--		WHEN @permission_set = 2 THEN @sql_script + char(13) + 'WITH PERMISSION_SET = EXTERNAL_ACCESS;'
	--		WHEN @permission_set = 3 THEN @sql_script + char(13) + 'WITH PERMISSION_SET = UNSAFE;'
	--		ELSE @sql_script + char(13) + 'WITH PERMISSION_SET = UNKNOWN - PLEASE CHECK;'
	--	END

	EXECUTE sp_addCloneCommand @sql_script;

	FETCH NEXT FROM cur INTO @assembly_name, @permission_set, @content;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all filegroups of the source database 
-- Based on sys.filegroups
-- Omitted is_read_only and is_default, if we need this option, 
-- then add file option is needed to implemented first 
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllFileGroups', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllFileGroups;
GO

CREATE PROCEDURE sp_cloneAllFileGroups
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY FILEGROUPS';

DECLARE @TempFileGroups TABLE(filegroup_name nvarchar(max), type_desc nvarchar(max), is_default binary, is_readonly binary);

-- create clone filegroups
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT name AS filegroup_name, type_desc AS type_desc, is_default AS is_default, is_read_only AS is_readonly' + char(13) + 
	'FROM sys.filegroups' + char(13) +
	dbo.checkVersionReturnString('WHERE is_system = 0', 11) + ';'
INSERT @TempFileGroups EXECUTE sp_printAndExecute @sql_script;

DECLARE @filegroup_name nvarchar(max), @type_desc nvarchar(max), @is_default binary, @is_readonly binary;
DECLARE cur CURSOR LOCAL FOR
	SELECT filegroup_name, type_desc, is_default, is_readonly FROM @TempFileGroups;

OPEN cur;
FETCH NEXT FROM cur INTO @filegroup_name, @type_desc, @is_default, @is_readonly;

-- loop through each filegroup and create in the clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	IF @filegroup_name <> 'PRIMARY' BEGIN 
		PRINT '>>> FileGroup [' + @filegroup_name + '] is found ...';

		SET @sql_script = 
			'USE master;' + char(13) + 
			'ALTER DATABASE [' + @clone_database_name + ']' + char(13) +
			'ADD FILEGROUP [' + @filegroup_name + ']';

		IF @type_desc = 'FILESTREAM_DATA_FILEGROUP'
			SET @sql_script = @sql_script + ' CONTAINS FILESTREAM;';
		ELSE
			SET @sql_script = @sql_script + ';';

		EXECUTE sp_addCloneCommand @sql_script;
	END

	FETCH NEXT FROM cur INTO @filegroup_name, @type_desc, @is_default, @is_readonly;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all partition functions of the source database 
-- Based on sys.partition_functions, sys.partition_parameters and sys.partition_range_values
-- Only RANGE type is supported up to current version, 
-- if more partition function types are provided in the future, please change the script in this section
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllPartitionFucntions', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllPartitionFucntions;
GO

CREATE PROCEDURE sp_cloneAllPartitionFucntions
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY PARTITION FUNCTIONS';

DECLARE @TempPartitionFucntions TABLE(function_name nvarchar(max), type_desc nvarchar(max), boundary_value_on_right binary, type_name nvarchar(max), max_length bigint, precision bigint, scale bigint,
		collation_name nvarchar(max), range_value sql_variant, function_id bigint, parameter_id bigint, boundary_id bigint, UNIQUE NONCLUSTERED (function_id, parameter_id, boundary_id));

-- create clone user defined partition functions
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT pf.name AS function_name, pf.type_desc AS type_desc, pf.boundary_value_on_right AS boundary_value_on_right, TYPE_NAME(pp.user_type_id) AS type_name, pp.max_length AS max_length, ' + 
	'pp.precision AS precision, pp.scale AS scale, pp.collation_name AS collation_name, prv.value AS range_value, prv.function_id AS function_id, prv.parameter_id AS parameter_id, ' +
	'prv.boundary_id AS boundary_id' + char(13) +
	'FROM sys.partition_functions AS pf' + char(13) +
	'INNER JOIN sys.partition_parameters AS pp ON pp.function_id = pf.function_id' + char(13) + 
	'INNER JOIN sys.partition_range_values AS prv ON prv.function_id = pp.function_id AND prv.parameter_id = pp.parameter_id' + char(13) + 
	dbo.checkVersionReturnString('WHERE pf.is_system = 0', 11) + ';';
INSERT @TempPartitionFucntions EXECUTE sp_printAndExecute @sql_script;

DECLARE @function_name nvarchar(max), @type_desc nvarchar(max), @boundary_value_on_right binary, @type_name nvarchar(max), @max_length bigint, @precision bigint, @scale bigint, @collation_name nvarchar(max), 
		@range_value sql_variant, @parameter_id bigint;
DECLARE cur CURSOR LOCAL FOR
	SELECT function_name, type_desc, boundary_value_on_right, type_name, max_length, precision, scale, collation_name, range_value, parameter_id 
	FROM @TempPartitionFucntions
	ORDER BY function_id, parameter_id, boundary_id; 

-- the following are used for checking the change of partition function statement
DECLARE @previous_function_name nvarchar(max), @previous_parameter_id bigint, @parameter_field nvarchar(max), @boundary_field nvarchar(max),
		@prefix_field nvarchar(max), @infix_field nvarchar(max), @suffix_field nvarchar(max), @parameter_separator nvarchar(max), @boundary_separator nvarchar(max);
SET @previous_function_name = '';
SET @previous_parameter_id = -1;
SET @parameter_field = '';
SET @boundary_field = '';
SET @parameter_separator = '';
SET @boundary_separator = '';

OPEN cur;
FETCH NEXT FROM cur INTO @function_name, @type_desc, @boundary_value_on_right, @type_name, @max_length, @precision, @scale, @collation_name, @range_value, @parameter_id;

WHILE @@FETCH_STATUS = 0 BEGIN
	-- a partition function may has multiple range values and parameters
	-- the result table is ordered by function_id, parameter_id and boundary_id, so if function_name changes, then it should be part of a new statement	
	IF @previous_function_name <> @function_name BEGIN
		-- add the clone command before handling the next statement
		IF @previous_function_name <> '' BEGIN
			SET @sql_script = @prefix_field + @parameter_field + @infix_field + @boundary_field + @suffix_field;
			EXECUTE sp_addCloneCommand @sql_script;

			SET @parameter_field = '';
			SET @boundary_field = '';
			SET @parameter_separator = '';
			SET @boundary_separator = '';
		END

		PRINT '>>> Partition Function [' + @function_name + '] is found ...';

		SET @prefix_field = 
			'USE [' + @clone_database_name + '];' + char(13) + 
			'CREATE PARTITION FUNCTION [' + @function_name + ']('; 

		SET @infix_field = ')' + char(13) + 'AS ' + @type_desc; 

		IF @boundary_value_on_right = 1
			SET @infix_field = @infix_field + ' RIGHT' + char(13) + 'FOR VALUES (';
		ELSE
			SET @infix_field = @infix_field + ' LEFT' + char(13) + 'FOR VALUES (';

		SET @suffix_field = ');';
 	END
	
	-- parameter changes
	IF @previous_parameter_id <> @parameter_id OR @previous_function_name <> @function_name BEGIN
		SET @parameter_field = @parameter_field + @parameter_separator + dbo.getColumnTypeString(@type_name, @precision, @scale, @max_length, @collation_name);
		SET @parameter_separator = ', ';
	END
	
	SET @boundary_field = @boundary_field + @boundary_separator + dbo.getValueStringByDataType(CAST(@range_value AS nvarchar(max)), @type_name);
	SET @boundary_separator = ', ';

	SET @previous_function_name = @function_name;
	SET @previous_parameter_id = @parameter_id;

	FETCH NEXT FROM cur INTO @function_name, @type_desc, @boundary_value_on_right, @type_name, @max_length, @precision, @scale, @collation_name, @range_value, @parameter_id;
END
	
CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_function_name <> '' BEGIN
	SET @sql_script = @prefix_field + @parameter_field + @infix_field + @boundary_field + @suffix_field;
	EXECUTE sp_addCloneCommand @sql_script;
END

GO

-----------------------------------------------------------------------
-- This SP clones all partition schemes of the source database 
-- Based on sys.partition_schemes, sys.data_spaces and sys.destination_data_spaces
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllPartitionSchemes', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllPartitionSchemes;
GO

CREATE PROCEDURE sp_cloneAllPartitionSchemes
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY PARTITION SCHEMES';

DECLARE @TempPartitionSchemes TABLE(scheme_name nvarchar(max), function_name nvarchar(max), filegroup_name nvarchar(max), partition_scheme_id bigint, destination_id bigint, 
		UNIQUE NONCLUSTERED (partition_scheme_id, destination_id));

-- create clone partition schemes
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT ps.name AS scheme_name, pf.name AS function_name, ds.name AS filegroup_name, dds.partition_scheme_id AS parition_scheme_id, dds.destination_id AS destination_id' + char(13) +
	'FROM sys.partition_functions AS pf' + char(13) +
	'INNER JOIN sys.partition_schemes AS ps ON ps.function_id = pf.function_id' + char(13) + 
	'INNER JOIN sys.destination_data_spaces AS dds ON dds.partition_scheme_id = ps.data_space_id' + char(13) + 
	'INNER JOIN sys.data_spaces AS ds ON dds.data_space_id = ds.data_space_id' + char(13) + 
	dbo.checkVersionReturnString('WHERE pf.is_system = 0', 11) + ';';
INSERT @TempPartitionSchemes EXECUTE sp_printAndExecute @sql_script;

DECLARE @scheme_name nvarchar(max), @function_name nvarchar(max), @filegroup_name nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT scheme_name, function_name, filegroup_name 
	FROM @TempPartitionSchemes
	ORDER BY partition_scheme_id, destination_id; 

-- the following are used for checking the change of partition scheme statement
DECLARE @previous_scheme_name nvarchar(max), @filegroup_field nvarchar(max), @prefix_field nvarchar(max), @suffix_field nvarchar(max), @separator nvarchar(max);
SET @previous_scheme_name = '';
SET @filegroup_field = '';
SET @separator = '';

OPEN cur;
FETCH NEXT FROM cur INTO @scheme_name, @function_name, @filegroup_name;

WHILE @@FETCH_STATUS = 0 BEGIN
	-- a partition scheme may associate with multiple filegroups
	-- the result table is ordered by parition_scheme_id and destiniation_id, so if scheme_name changes, then it should be part of a new statement	
	IF @previous_scheme_name <> @scheme_name BEGIN
		-- add the clone command before handling the next statement
		IF @previous_scheme_name <> '' BEGIN
			SET @sql_script = @prefix_field + @filegroup_field + @suffix_field;
			EXECUTE sp_addCloneCommand @sql_script;

			SET @filegroup_field = '';
			SET @separator = '';
		END

		PRINT '>>> Partition Scheme [' + @scheme_name + '] is found ...';

		SET @prefix_field = 
			'USE [' + @clone_database_name + '];' + char(13) + 
			'CREATE PARTITION SCHEME [' + @scheme_name + ']' + char(13) +
			'AS PARTITION [' + @function_name + ']' + char(13) +
			'TO ('; 

		SET @suffix_field = ');';
 	END
	
	SET @filegroup_field = @filegroup_field + @separator + '[' + @filegroup_name + ']';
	SET @separator = ', ';

	SET @previous_scheme_name = @scheme_name;

	FETCH NEXT FROM cur INTO @scheme_name, @function_name, @filegroup_name;
END
	
CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_scheme_name <> '' BEGIN
	SET @sql_script = @prefix_field + @filegroup_field + @suffix_field;
	EXECUTE sp_addCloneCommand @sql_script;
END

GO

-----------------------------------------------------------------------
-- This SP clones all indexes of an object from the source database
-- Based on sys.indexes
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllIndexes', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllIndexes;
GO

CREATE PROCEDURE sp_cloneAllIndexes
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY INDEXES';

-- clone keys of each table/view
DECLARE @TempKeys TABLE(table_name nvarchar(max), schema_name nvarchar(max), index_name nvarchar(max), column_name nvarchar(max), is_ansi_padded binary, cluster_desc nvarchar(max), is_primary_key binary, 
		is_unique binary, is_unique_constraint binary, is_padded binary, is_hypothetical binary, ignore_dup_key binary, allow_row_locks binary, allow_page_locks binary, partition_ordinal bigint, 
		is_descending_key binary, is_included_column binary, fill_factor bigint, filter_definition nvarchar(max), data_space_name nvarchar(max), data_space_type nvarchar(max), object_id bigint, 
		index_id bigint, key_ordinal bigint, index_column_id bigint, UNIQUE NONCLUSTERED(object_id, index_id, key_ordinal, index_column_id));

SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT t.table_name AS table_name, t.schema_name AS schema_name, i.name AS index_name, c.name AS column_name, c.is_ansi_padded AS is_ansi_padded, i.type_desc AS cluster_desc, i.is_primary_key AS is_primary_key, ' +
	'i.is_unique AS is_unique, i.is_unique_constraint AS is_unique_constraint, i.is_padded AS is_padded, i.is_hypothetical AS is_hypothetical, i.ignore_dup_key AS ignore_dup_key, i.allow_row_locks AS allow_row_locks, ' +
	'i.allow_page_locks AS allow_page_locks, ic.partition_ordinal AS partition_ordinal, ic.is_descending_key AS is_descending_key, ic.is_included_column AS is_included_column, i.fill_factor AS fill_factor, ' + 
	'i.filter_definition AS filter_definition, ds.name AS data_space_name, ds.type_desc AS data_space_type, ic.object_id AS object_id, ic.index_id AS index_id, ic.key_ordinal AS key_ordinal, ' +
	'ic.index_column_id AS index_column_id' + char(13) +
	'FROM ##AllTableAndViews AS t' + char(13) +
	'INNER JOIN sys.columns AS c ON c.object_id = t.object_id' + char(13) +
	'INNER JOIN sys.index_columns AS ic ON t.object_id = ic.object_id AND c.column_id = ic.column_id' + char(13) + 
	'INNER JOIN sys.indexes AS i ON t.object_id = i.object_id AND i.index_id = ic.index_id' + char(13) +
	'INNER JOIN sys.data_spaces AS ds ON ds.data_space_id = i.data_space_id;';
INSERT @TempKeys EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @index_name nvarchar(max), @column_name nvarchar(max), @is_ansi_padded binary, @cluster_desc nvarchar(max), @is_primary_key binary, @is_unique binary, 
		@is_unique_constraint binary, @is_padded binary, @is_hypothetical binary, @ignore_dup_key binary, @allow_row_locks binary, @allow_page_locks binary, @partition_ordinal bigint, 
		@is_descending_key binary, @is_included_column binary, @fill_factor bigint, @filter_definition nvarchar(max), @data_space_name nvarchar(max), @data_space_type nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, index_name, column_name, is_ansi_padded, cluster_desc, is_primary_key, is_unique, is_unique_constraint, is_padded, is_hypothetical, ignore_dup_key, allow_row_locks, allow_page_locks, partition_ordinal, 
			is_descending_key, is_included_column, fill_factor, filter_definition, data_space_name, data_space_type
	FROM @TempKeys
	ORDER BY object_id, index_id, key_ordinal, index_column_id; 

-- the following are used for checking the change of index statement
DECLARE @previous_table_name nvarchar(max), @previous_index_name nvarchar(max), @index_column_field nvarchar(max), @include_column_field nvarchar(max), @partition_column_field nvarchar(max),
		@prefix_field nvarchar(max), @suffix_field nvarchar(max), @index_column_separator nvarchar(max), @include_column_separator nvarchar(max), @partition_column_separator nvarchar(max),
		@max_partition_ordinal bigint;
SET @previous_table_name = '';
SET @previous_index_name = '';
SET @index_column_field = '';
SET @include_column_field = '';
SET @partition_column_field = '';
SET @index_column_separator = '';
SET @include_column_separator = '';
SET @partition_column_separator = '';
SET @max_partition_ordinal = 0;

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @index_name, @column_name, @is_ansi_padded, @cluster_desc, @is_primary_key, @is_unique, @is_unique_constraint, @is_padded, @is_hypothetical, @ignore_dup_key, 
		@allow_row_locks, @allow_page_locks, @partition_ordinal, @is_descending_key, @is_included_column, @fill_factor, @filter_definition, @data_space_name, @data_space_type;

WHILE @@FETCH_STATUS = 0 BEGIN
	-- heap is not an index, so we skip it
	IF @cluster_desc = 'HEAP' BEGIN
		FETCH NEXT FROM cur INTO @table_name, @schema_name, @index_name, @column_name, @is_ansi_padded, @cluster_desc, @is_primary_key, @is_unique, @is_unique_constraint, @is_padded, @is_hypothetical,
				@ignore_dup_key, @allow_row_locks, @allow_page_locks, @partition_ordinal, @is_descending_key, @is_included_column, @fill_factor, @filter_definition, 
				@data_space_name, @data_space_type;
		CONTINUE;
	END

	-- an index can be applied on multiple columns
	-- the result table is ordered by object_id and index_id, so if either the table / index changes, then it should be part of a new index statement	
	IF (@previous_table_name <> @table_name) OR (@previous_index_name <> @index_name) BEGIN
		-- add the clone command before handling the next index statement
		IF @previous_index_name <> '' BEGIN
			SET @sql_script = @prefix_field + @index_column_field;

			IF @include_column_field <> '' 
				SET @sql_script = @sql_script + ')' + char(13) + 'INCLUDE (' + @include_column_field;
			
			SET @sql_script = @sql_script + @suffix_field;

			IF @partition_column_field <> ''
				SET @sql_script = @sql_script + '(' + @partition_column_field + ');';

			EXECUTE sp_addCloneCommand @sql_script;

			SET @index_column_field = '';
			SET @include_column_field = '';
			SET @partition_column_field = '';
			SET @index_column_separator = '';
			SET @include_column_separator = '';
			SET @partition_column_separator = '';
			SET @max_partition_ordinal = 0;
		END

		PRINT '>>> Index [' + @index_name + '] is found in Table/View [' + @table_name + '] ...';

		-- need to have the system created statistics on the column first, reserved for auto created statistics
		-- otherwise, no auto created statistics can be created after the creation of the index / primary key 
		SET @sql_script = 
			'USE [' + @clone_database_name + '];' + char(13) + 
			'DECLARE @dummy int;' + char(13) + 
			'SELECT @dummy = count(*)' + char(13) +
			'FROM [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']' + char(13) +
			'WHERE [' + @column_name + '] IS NOT NULL;';
		EXECUTE sp_addCloneCommand @sql_script;

		IF @is_primary_key = 1 OR @is_unique_constraint = 1 BEGIN
			SET @prefix_field =   
				'USE [' + @clone_database_name + '];' + char(13) +  
				'ALTER TABLE [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']' + char(13) +
				'ADD CONSTRAINT [' + @index_name + ']' + char(13);
				
			IF @is_primary_key = 1
				SET @prefix_field = @prefix_field + 'PRIMARY KEY ' + @cluster_desc + '(';
			ELSE
				SET @prefix_field = @prefix_field + 'UNIQUE ' + @cluster_desc + '(';
		END
		ELSE BEGIN
			SET @prefix_field = 'USE [' + @clone_database_name + '];' + char(13) + 'CREATE ';		
	
			IF @is_unique = 1
				SET @prefix_field = @prefix_field + 'UNIQUE ';
			SET @prefix_field = 
				@prefix_field + @cluster_desc + ' INDEX [' + @index_name + ']' + char(13) + 
				'ON [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + '] (';
		END

		SET @suffix_field = ')' + char(13)

		IF @filter_definition IS NOT NULL
			SET @suffix_field = @suffix_field +  'WHERE ' + @filter_definition + char(13); 

		-- check for each options
		IF @is_padded = 0
			SET @suffix_field = @suffix_field + 'WITH (PAD_INDEX = OFF, ';
		ELSE
			SET @suffix_field = @suffix_field + 'WITH (PAD_INDEX = ON, ';

		IF @is_hypothetical = 1
			SET @suffix_field = @suffix_field + 'STATISTICS_ONLY = 0, ';

		IF @ignore_dup_key = 0
			SET @suffix_field = @suffix_field + 'IGNORE_DUP_KEY = OFF, ';
		ELSE
			SET @suffix_field = @suffix_field + 'IGNORE_DUP_KEY = ON, ';

		IF @allow_row_locks = 0
			SET @suffix_field = @suffix_field + 'ALLOW_ROW_LOCKS = OFF, ';
		ELSE
			SET @suffix_field = @suffix_field + 'ALLOW_ROW_LOCKS = ON, ';

		IF @allow_page_locks = 0
			SET @sql_script = @sql_script + 'ALLOW_PAGE_LOCKS = OFF, ';
		ELSE
			SET @sql_script = @sql_script + 'ALLOW_PAGE_LOCKS = ON, ';

		IF @fill_factor > 0
			SET @suffix_field = @suffix_field + 'FILLFACTOR = ' + CAST(@fill_factor AS nvarchar(max)) + ', STATISTICS_NORECOMPUTE = OFF)';
		ELSE
			SET @suffix_field = @suffix_field + 'STATISTICS_NORECOMPUTE = OFF)';

		IF @data_space_type = 'ROWS_FILEGROUP'
			SET @suffix_field = @suffix_field + char(13) + 'ON [' + @data_space_name + '];';
		ELSE IF @data_space_type = 'FILESTREAM_DATA_FILEGROUP'
			SET @suffix_field = @suffix_field + char(13) + 'FILESTREAM_ON [' + @data_space_name + '];';
		ELSE IF @data_space_type = 'PARTITION_SCHEME'
			SET @suffix_field = @suffix_field + char(13) + 'ON [' + @data_space_name + ']';
		ELSE
			SET @suffix_field = @suffix_field + char(13) + 'ON UNKNOWN PARTITION OPTION - PLEASE CHECK;';
	END
	
	-- the column can be part of the index column field or the include column field
	IF (@is_primary_key = 1) OR (@is_included_column = 0) BEGIN 
		SET @index_column_field = @index_column_field + @index_column_separator + '[' + @column_name + '] ';
		SET @index_column_separator = ', ';
		
		-- set order
		IF @is_descending_key = 0
			SET @index_column_field = @index_column_field + 'ASC';
		ELSE
			SET @index_column_field = @index_column_field + 'DESC'; 

	END
	ELSE BEGIN
		SET @include_column_field = @include_column_field + @include_column_separator + '[' + @column_name + ']';
		SET @include_column_separator = ', ';
	END

	-- handle partition
	IF @data_space_type = 'PARTITION_SCHEME' BEGIN
		IF @partition_ordinal <> 0 BEGIN
			-- deal with the partition column order
			-- add the new column name and reserve the string location for the missing columns at the front 
			IF @partition_ordinal >= @max_partition_ordinal BEGIN
				WHILE @partition_ordinal > @max_partition_ordinal + 1 BEGIN
					SET @max_partition_ordinal = @max_partition_ordinal + 1;

					SET @partition_column_field = @partition_column_field + @partition_column_separator + '[>[>' + CAST(@max_partition_ordinal AS nvarchar(max)) + '<]<]';
					SET @partition_column_separator = ', ';
				END

				SET @partition_column_field = @partition_column_field + @partition_column_separator + '[' + @column_name + ']';
				SET @partition_column_separator = ', ';
				SET @max_partition_ordinal = @partition_ordinal;				
			END
			-- the string location is reserved, so replace it with the column name
			ELSE BEGIN
				SET @partition_column_field = REPLACE(@partition_column_field, '[>[>' + CAST(@partition_ordinal AS nvarchar(max)) + '<]<]', '[' + @column_name + ']');
			END
		END
	END

	SET @previous_table_name = @table_name;
	SET @previous_index_name = @index_name;

	FETCH NEXT FROM cur INTO @table_name, @schema_name, @index_name, @column_name, @is_ansi_padded, @cluster_desc, @is_primary_key, @is_unique, @is_unique_constraint, @is_padded, @is_hypothetical, @ignore_dup_key, 
			@allow_row_locks, @allow_page_locks, @partition_ordinal, @is_descending_key, @is_included_column, @fill_factor, @filter_definition, @data_space_name, @data_space_type;
END

CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_index_name <> '' BEGIN
	SET @sql_script = @prefix_field + @index_column_field;

	IF @include_column_field <> '' 
		SET @sql_script = @sql_script + ')' + char(13) + 'INCLUDE (' + @include_column_field;
			
	SET @sql_script = @sql_script + @suffix_field;

	IF @partition_column_field <> ''
		SET @sql_script = @sql_script + '(' + @partition_column_field + ');';

	EXECUTE sp_addCloneCommand @sql_script;
END

GO

-----------------------------------------------------------------------
-- This SP clones all computed columns of an object from the source database
-- Based on sys.computed_columns
-- Omits uses_database_collation
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllComputedColumns', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllComputedColumns;
GO

CREATE PROCEDURE sp_cloneAllComputedColumns
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY COMPUTED COLUMNS';

-- clone computed columns
DECLARE @TempCCs TABLE(table_name nvarchar(max), schema_name nvarchar(max), column_name nvarchar(max), definition nvarchar(max), is_persisted binary, is_nullable binary, is_ansi_padded binary);

SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT t.table_name AS table_name, t.schema_name AS schema_name, c.name AS column_name, c.definition AS definition, ' +
	'c.is_persisted AS is_persisted, c.is_nullable AS is_nullable, c.is_ansi_padded AS is_ansi_padded' + char(13) +
	'FROM ##AllTableAndViews AS t' + char(13) +
	'INNER JOIN sys.computed_columns AS c ON c.object_id = t.object_id;'; 
INSERT @TempCCs EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @column_name nvarchar(max), @definition nvarchar(max), @is_persisted binary, @is_nullable binary, @is_ansi_padded binary;
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, column_name, definition, is_persisted, is_nullable, is_ansi_padded FROM @TempCCs;

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @column_name, @definition, @is_persisted, @is_nullable, @is_ansi_padded;

WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Computed Column [' + @column_name + '] is found in Table/View [' + @table_name + '] ...';

	-- set for ansi padded field
	IF @is_ansi_padded = 1 BEGIN
		SET @sql_script = 'SET ANSI_PADDING ON;';
	END
	ELSE BEGIN
		SET @sql_script = 'SET ANSI_PADDING OFF;';
	END

	SET @sql_script = @sql_script + char(13) +
		'USE [' + @clone_database_name + '];' + char(13) +
		'ALTER TABLE [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']' + char(13) + 
		'DROP COLUMN [' + @column_name + '];' + char(13) + 
		'ALTER TABLE [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']' + char(13) + 
		'ADD [' + @column_name + '] AS ' + @definition;
	
	IF @is_persisted = 1 BEGIN
		SET @sql_script = @sql_script + ' PERSISTED';

		IF @is_nullable = 0
			SET @sql_script = @sql_script + ' NOT NULL';
	END
	SET @sql_script = @sql_script + ';';
	
	EXECUTE sp_addCloneCommand @sql_script;

	FETCH NEXT FROM cur INTO @table_name, @schema_name, @column_name, @definition, @is_persisted, @is_nullable, @is_ansi_padded;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all check constraints of an object from the source database
-- Based on sys.check_constraints
-- Omits uses_database_collation
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllCheckConstraints', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllCheckConstraints;
GO

CREATE PROCEDURE sp_cloneAllCheckConstraints
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY CHECK CONSTRAINTS';

-- clone check constraints
DECLARE @TempCCs TABLE(table_name nvarchar(max), schema_name nvarchar(max), constraint_name nvarchar(max), column_name nvarchar(max), is_ansi_padded binary, is_disabled binary, is_not_for_replication binary, is_not_trusted binary, definition nvarchar(max), uses_database_collation binary);

SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT t.table_name AS table_name, t.schema_name AS schema_name, cc.name AS constraint_name, c.name AS column_name, c.is_ansi_padded AS is_ansi_padded, cc.is_disabled AS is_disabled, cc.is_not_for_replication AS is_not_for_replication, ' +
	'cc.is_not_trusted AS is_not_trusted, cc.definition AS definition, cc.uses_database_collation AS uses_database_collation' + char(13) +
	'FROM ##AllTableAndViews AS t' + char(13) +
	'INNER JOIN sys.check_constraints AS cc ON cc.parent_object_id = t.object_id' + char(13) +
	'INNER JOIN sys.columns AS c on c.object_id = cc.parent_object_id AND c.column_id = cc.parent_column_id;';
INSERT @TempCCs EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @constraint_name nvarchar(max), @column_name nvarchar(max), @is_ansi_padded binary, @is_disabled binary, @is_not_for_replication binary, @is_not_trusted binary, @definition nvarchar(max), @uses_database_collation binary;
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, constraint_name, column_name, is_ansi_padded, is_disabled, is_not_for_replication, is_not_trusted, definition, uses_database_collation FROM @TempCCs;

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @constraint_name, @column_name, @is_ansi_padded, @is_disabled, @is_not_for_replication, @is_not_trusted, @definition, @uses_database_collation;

-- loop through each contraint and update the clone
WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Check Constraint [' + @constraint_name + '] is found in Table/View [' + @table_name + '] ...';

	-- set for ansi padded field
	IF @is_ansi_padded = 1 BEGIN
		SET @sql_script = 'SET ANSI_PADDING ON;';
	END
	ELSE BEGIN
		SET @sql_script = 'SET ANSI_PADDING OFF;';
	END

	SET @sql_script = @sql_script + char(13) +
		'USE [' + @clone_database_name + '];' + char(13) + 
		'ALTER TABLE [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']';

	IF @is_not_trusted = 1
		SET @sql_script = @sql_script + ' WITH NOCHECK'  + char(13) + 'ADD CONSTRAINT [' + @constraint_name + ']';
	ELSE
		SET @sql_script = @sql_script + char(13) + 'ADD CONSTRAINT [' + @constraint_name + ']';
		
	IF @is_disabled = 1
		SET @sql_script = @sql_script + ' NOCHECK ';
	ELSE
		SET @sql_script = @sql_script + ' CHECK ';
	IF @is_not_for_replication = 1
		SET @sql_script = @sql_script + 'NOT FOR REPLICATION ';
	SET @sql_script = @sql_script +	'(' + @definition + ');';

	EXECUTE sp_addCloneCommand @sql_script;

	-- omitted @uses_database_collation
	FETCH NEXT FROM cur INTO @table_name, @schema_name, @constraint_name, @column_name, @is_ansi_padded, @is_disabled, @is_not_for_replication, @is_not_trusted, @definition, @uses_database_collation;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all default constraints of an object from the source database
-- Based on sys.default_constraints 
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllDefaultConstraints', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllDefaultConstraints;
GO

CREATE PROCEDURE sp_cloneAllDefaultConstraints
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY DEFAULT CONSTRAINTS';

-- clone default constraints
DECLARE @TempDCs TABLE(table_name nvarchar(max), schema_name nvarchar(max), constraint_name nvarchar(max), column_name nvarchar(max), is_ansi_padded binary, definition nvarchar(max));

SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT t.table_name AS table_name, t.schema_name AS schema_name, dc.name AS constraint_name, c.name AS column_name, c.is_ansi_padded AS is_ansi_padded, dc.definition AS definition' + char(13) +
	'FROM ##AllTableAndViews AS t' + char(13) +
	'INNER JOIN sys.default_constraints AS dc ON dc.parent_object_id = t.object_id' + char(13) +
	'INNER JOIN sys.columns AS c on c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id;';
INSERT @TempDCs EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @constraint_name nvarchar(max), @column_name nvarchar(max), @is_ansi_padded binary, @definition nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, constraint_name, column_name, is_ansi_padded, definition FROM @TempDCs;

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @constraint_name, @column_name, @is_ansi_padded, @definition;

-- loop through each contraint and update the clone
WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Default Constraint [' + @constraint_name + '] is found in Table/View [' + @table_name + '] ...';

	-- set for ansi padded field
	IF @is_ansi_padded = 1 BEGIN
		SET @sql_script = 'SET ANSI_PADDING ON;';
	END
	ELSE BEGIN
		SET @sql_script = 'SET ANSI_PADDING OFF;';
	END

	SET @sql_script = @sql_script + char(13) +  
		'USE [' + @clone_database_name + '];' + char(13) + 
		'ALTER TABLE [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']' + char(13) + 
		'ADD CONSTRAINT ' + @constraint_name + char(13) + 
		'DEFAULT ' + @definition + char(13) + 
		'FOR [' + @column_name + '];';
	EXECUTE sp_addCloneCommand @sql_script;

	FETCH NEXT FROM cur INTO @table_name, @schema_name, @constraint_name, @column_name, @is_ansi_padded, @definition;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all sql modules of an object from the source database
-- Based on sys.sql_modules
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllModules', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllModules;
GO

CREATE PROCEDURE sp_cloneAllModules
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY MODULES';

-- clone modules
DECLARE @TempModules TABLE(module_name nvarchar(max), schema_name nvarchar(max), module_object_id bigint, definition nvarchar(max), type nvarchar(max));

SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) +  
	'SELECT o.name AS module_name, SCHEMA_NAME(o.schema_id) AS schema_name, m.object_id AS module_object_id, m.definition AS definition, o.type AS type' + char(13) +
	'FROM sys.sql_modules AS m' + char(13) +
	'INNER JOIN sys.objects AS o ON o.object_id = m.object_id' + char(13) +
	'WHERE o.parent_object_id = 0 OR o.parent_object_id IN (' + char(13) +
	'SELECT object_id' + char(13) +
	'FROM ##AllTableAndViews' + char(13) +
	');';
INSERT @TempModules EXECUTE sp_printAndExecute @sql_script;

DECLARE @module_name nvarchar(max), @schema_name nvarchar(max), @module_object_id bigint, @definition nvarchar(max), @type nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT module_name, schema_name, module_object_id, definition, type FROM @TempModules;

OPEN cur;
FETCH NEXT FROM cur INTO @module_name, @schema_name, @module_object_id, @definition, @type;

-- loop through each trigger and update the clone
WHILE @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Module [' + @module_name + '] with Type [' + @type + '] is found ...';

	SET @sql_script = 
		'EXECUTE(''USE [' + @clone_database_name + '];' + char(13) + 
		'EXECUTE (N''''' + REPLACE(@definition, '''', '''''''''') + ''''');'');';

	-- not support encrypted modules
	IF @definition IS NOT NULL
		EXECUTE sp_addCloneCommand @sql_script;
	ELSE BEGIN
		PRINT 'ERROR: Module [' + @module_name + '] cannot be copied because it is Encrypted, please check with DBA ...';

		-- if the view is encrypted, then this is the workaround to create a table instead of a view
		IF @type = 'V' BEGIN
			SET @sql_script = 
				'USE master;' + char(13) +  
				'SELECT * INTO [' + @clone_database_name + '].[' + @schema_name + '].[' + @module_name + ']' + char(13) +
				'FROM [' + @source_database_name + '].[' + @schema_name + '].[' + @module_name + ']' + char(13) +
				'WHERE 1 = 2;';
			EXECUTE sp_addCloneCommand @sql_script;
		END
	END

	FETCH NEXT FROM cur INTO @module_name, @schema_name, @module_object_id, @definition, @type;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all foreign keys of an object from the source database 
-- Based on sys.foreign_keys
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllForeignKeys', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllForeignKeys;
GO

CREATE PROCEDURE sp_cloneAllForeignKeys
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY FOREIGN KEYS';

-- clone all foreign keys
DECLARE @TempFKs TABLE(table_name nvarchar(max), schema_name nvarchar(max), fk_table_name nvarchar(max), fk_schema_name nvarchar(max), fk_column nvarchar(max), pk_column nvarchar(max), 
		constraint_name nvarchar(max), is_disabled binary, is_not_for_replication binary, is_not_trusted binary, delete_referential_action bigint, update_referential_action bigint, 
		parent_object_id bigint, constraint_object_id bigint, constraint_column_id bigint, UNIQUE NONCLUSTERED(parent_object_id, constraint_object_id, constraint_column_id)); 

SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT t.table_name AS table_name, t.schema_name AS schema_name, ft.table_name AS fk_table_name, ft.schema_name AS fk_schema_name, fc.name AS fk_column, pc.name AS pk_column, ' + 
	'fk.name AS constraint_name, fk.is_disabled AS is_disabled, fk.is_not_for_replication AS is_not_for_replication, ' +
	'fk.is_not_trusted AS is_not_trusted, fk.delete_referential_action AS delete_referential_action, fk.update_referential_action AS update_referential_action, ' +
	'fkc.parent_object_id AS parent_object_id, fkc.constraint_object_id AS constraint_object_id, fkc.constraint_column_id AS constraint_column_id' + char(13) +  
	'FROM ##AllTableAndViews AS t' + char(13) +
	'INNER JOIN sys.foreign_key_columns AS fkc ON fkc.parent_object_id = t.object_id' + char(13) +
	'INNER JOIN sys.foreign_keys AS fk ON fk.parent_object_id = t.object_id AND fk.object_id = fkc.constraint_object_id' + char(13) +
	'INNER JOIN sys.columns AS pc ON pc.object_id = fkc.parent_object_id AND pc.column_id = fkc.parent_column_id' + char(13) +
	'INNER JOIN sys.columns AS fc ON fc.object_id = fkc.referenced_object_id AND fc.column_id = fkc.referenced_column_id'  + char(13) +
	'INNER JOIN ##AllTableAndViews AS ft ON ft.object_id = fkc.referenced_object_id;'; 
INSERT @TempFKs EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @fk_table_name nvarchar(max), @fk_schema_name nvarchar(max), @fk_column nvarchar(max), @pk_column nvarchar(max), @constraint_name nvarchar(max), 
		@is_disabled binary, @is_not_for_replication binary, @is_not_trusted binary, @delete_referential_action bigint, @update_referential_action bigint; 
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, fk_table_name, fk_schema_name, fk_column, pk_column, constraint_name, is_disabled, is_not_for_replication, is_not_trusted, 
			delete_referential_action, update_referential_action FROM @TempFKs
	ORDER BY parent_object_id, constraint_object_id, constraint_column_id;

-- the following are used for checking the change of fk constraint statement
DECLARE @previous_table_name nvarchar(max), @previous_constraint_name nvarchar(max), @pk_column_field nvarchar(max), @fk_column_field nvarchar(max), @prefix_field nvarchar(max), 
		@infix_field nvarchar(max), @suffix_field nvarchar(max), @separator nvarchar(max);
SET @previous_table_name = '';
SET @previous_constraint_name = '';
SET @pk_column_field = '';
SET @fk_column_field = '';
SET @separator = '';

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @fk_table_name, @fk_schema_name, @fk_column, @pk_column, @constraint_name, @is_disabled, @is_not_for_replication, 
							@is_not_trusted, @delete_referential_action, @update_referential_action;

-- loop through each FK and create in clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	-- an index can be applied on multiple columns
	-- the result table is ordered by object_id and constraint_id, so if either the table / constraint changes, then it should be part of a new fk contraint statement	
	IF (@previous_table_name <> @table_name) OR (@previous_constraint_name <> @constraint_name) BEGIN
		-- add the clone command before handling the next fk constraint statement
		IF @previous_constraint_name <> '' BEGIN
			SET @sql_script = @prefix_field + @pk_column_field + @infix_field + @fk_column_field + @suffix_field;
			EXECUTE sp_addCloneCommand @sql_script;

			SET @pk_column_field = '';
			SET @fk_column_field = '';
			SET @separator = '';
		END	

		PRINT '>>> Foreign Key [' + @constraint_name + '] is found in Table/View [' + @table_name + '] ...';

		SET @prefix_field = 
			'USE [' + @clone_database_name + '];' + char(13) + 
			'ALTER TABLE [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']';
			
		IF @is_not_trusted = 1
			SET @prefix_field = @prefix_field + ' WITH NOCHECK' + char(13) + 'ADD CONSTRAINT [' + @constraint_name + ']';
		ELSE
			SET @prefix_field = @prefix_field + char(13) + 'ADD CONSTRAINT [' + @constraint_name + ']'; 

		IF @is_disabled = 1
			SET @prefix_field = @prefix_field + ' NOCHECK';
		IF @is_not_for_replication = 1
			SET @prefix_field = @prefix_field + ' NOT FOR REPLICATION';
		SET @prefix_field = @prefix_field + ' FOREIGN KEY (';

		SET @infix_field =
			')' + char(13) + 'REFERENCES [' + @clone_database_name + '].[' + @fk_schema_name + '].[' + @fk_table_name + '] (';
			
		SET @suffix_field = 
			CASE 
				WHEN @delete_referential_action = 0 THEN ') ON DELETE NO ACTION'
				WHEN @delete_referential_action = 1 THEN ') ON DELETE CASCADE'
				WHEN @delete_referential_action = 2 THEN ') ON DELETE SET NULL'
				WHEN @delete_referential_action = 3 THEN ') ON DELETE SET DEFAULT'
				ELSE ') ON DELETE SET UNKNOWN - PLEASE CHECK'
			END
		SET @suffix_field =
			CASE 
				WHEN @update_referential_action = 0 THEN @suffix_field + ' ON UPDATE NO ACTION;'
				WHEN @update_referential_action = 1 THEN @suffix_field + ' ON UPDATE CASCADE;'
				WHEN @update_referential_action = 2 THEN @suffix_field + ' ON UPDATE SET NULL;'
				WHEN @update_referential_action = 2 THEN @suffix_field + ' ON UPDATE SET DEFAULT;'
				ELSE @suffix_field + ' ON UPDATE SET UNKNOWN - PLEASE CHECK;'
			END
	END
	
	SET @pk_column_field = @pk_column_field + @separator + '[' + @pk_column + ']';
	SET @fk_column_field = @fk_column_field + @separator + '[' + @fk_column + ']';
	SET @separator = ', ';

	SET @previous_table_name = @table_name;
	SET @previous_constraint_name = @constraint_name;

	FETCH NEXT FROM cur INTO @table_name, @schema_name, @fk_table_name, @fk_schema_name, @fk_column, @pk_column, @constraint_name, @is_disabled, @is_not_for_replication, 
			@is_not_trusted, @delete_referential_action, @update_referential_action;
END

CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_constraint_name <> '' BEGIN 
	SET @sql_script = @prefix_field + @pk_column_field + @infix_field + @fk_column_field + @suffix_field;
	EXECUTE sp_addCloneCommand @sql_script;
END

GO

-----------------------------------------------------------------------
-- This SP maps auto created statistics from the source database to the clone database
-- Auto created statistics are system created, so the source and clone will be different
-- Mapped by Table Name, Schema Name and Column Name
-- After mapping, the updated commands will be inserted to ##StatisticsCommandTable
-----------------------------------------------------------------------
IF OBJECT_ID('sp_mapAutoCreatedStatistics', 'P') IS NOT NULL 
	DROP PROCEDURE sp_mapAutoCreatedStatistics;
GO

CREATE PROCEDURE sp_mapAutoCreatedStatistics
	@clone_database_name nvarchar(max)
AS 
	DECLARE @sql_script varchar(max);
	PRINT '>>> MAP AUTO CREATE STATISTICS';

	-- maps auto created statistics by table name, schema name and column name
	SET @sql_script =
		'USE [' + @clone_database_name + '];' + char(13) +
		'SELECT REPLACE(acs.sql_script, ''(['' + acs.original_index_name + ''])'', ''(['' + s.name + ''])'') AS sql_script, acs.original_index_name AS original_index_name, s.name AS clone_index_name' + char(13) +
		'FROM sys.stats AS s' + char(13) +
		'INNER JOIN sys.stats_columns AS sc ON s.object_id = sc.object_id AND s.stats_id = sc.stats_id' + char(13) +
		'INNER JOIN sys.columns AS c ON c.object_id = sc.object_id AND c.column_id = sc.column_id' + char(13) +
		'INNER JOIN sys.objects AS o ON c.object_id = o.object_id' + char(13) +
		'RIGHT JOIN ##AutoCreatedStatisticsCommandTable AS acs ON acs.table_name = o.name AND acs.schema_name = SCHEMA_NAME(o.schema_id) AND acs.column_name = c.name' + char(13) +
		'WHERE s.name LIKE ''_WA_Sys_%'';';

	INSERT ##StatisticsCommandTable EXECUTE sp_printAndExecute @sql_script;
GO

-----------------------------------------------------------------------
-- This SP creates the statistics for an object from the source database
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneObjectStatistics', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneObjectStatistics;
GO

CREATE PROCEDURE sp_cloneObjectStatistics
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max),
	@table_name nvarchar(max),
	@schema_name nvarchar(max),
	@column_name nvarchar(max) = NULL,
	@index_name nvarchar(max) = NULL
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY STATISTICS';

-- get table statistics from the source database
DECLARE @TempStats TABLE(Stats_Stream varbinary(max), Rows bigint, Data_Pages bigint);

-- get statistics information
SET @sql_script = 
	'USE [' + @source_database_name + '];' + char(13) + 
	'DBCC SHOW_STATISTICS(N''[' +  @schema_name + '].[' + @table_name + ']''';
IF @index_name IS NOT NULL
	SET @sql_script = @sql_script + ', [' + @index_name + ']';
SET @sql_script = @sql_script + ') WITH STATS_STREAM;';

BEGIN TRY
	INSERT @TempStats EXECUTE sp_printAndExecute @sql_script;
END TRY

BEGIN CATCH
	PRINT '>>> No Statistics ...';
	RETURN; 
END CATCH

DECLARE @Stats_Stream varbinary(max), @Rows bigint, @Data_Pages bigint;
DECLARE cur CURSOR LOCAL FOR
	SELECT Stats_Stream, Rows, Data_Pages FROM @TempStats;

OPEN cur;
FETCH NEXT FROM cur INTO @Stats_Stream, @Rows, @Data_Pages;

IF @@FETCH_STATUS = 0 BEGIN
	PRINT '>>> Statistics is found ...';
		
	-- update statistics information
	DECLARE @Stats_Stream_Str varchar(max), @Rows_Str nvarchar(max), @Data_Pages_Str nvarchar(max);
	IF @index_name IS NOT NULL
		IF @Stats_Stream IS NULL
			SET @Stats_Stream_Str = 'NULL';
		ELSE 
			SET @Stats_Stream_Str = '0x' + CAST('' as xml).value('xs:hexBinary(sql:variable("@Stats_Stream") )', 'varchar(max)'); 

	IF @Rows IS NULL
		SET @Rows_Str = 'NULL';
	ELSE
		SET @Rows_Str = CAST(@Rows AS nvarchar(max));

	IF @Data_Pages IS NULL
		SET @Data_Pages_Str = 'NULL';
	ELSE
		SET @Data_Pages_Str = CAST(@Data_Pages AS nvarchar(max));

	SET @sql_script =
		'USE [' + @clone_database_name + '];' + char(13) +
		'UPDATE STATISTICS [' +  @schema_name + '].[' + @table_name + ']';

	IF @index_name IS NOT NULL
		SET @sql_script = @sql_script + '([' + @index_name + '])' + char(13) + 'WITH STATS_STREAM = ' + @Stats_Stream_Str + ', ';
	ELSE
		SET @sql_script = @sql_script + char(13) + 'WITH ';

	IF @Rows IS NOT NULL 
		SET @sql_script = @sql_script +	'ROWCOUNT = ' + @Rows_Str + ', ';

	IF @Data_Pages IS NOT NULL
		SET @sql_script = @sql_script + 'PAGECOUNT = ' + @Data_Pages_Str + ', NORECOMPUTE;';
	ELSE
		SET @sql_script = @sql_script + 'NORECOMPUTE;';

	-- auto created statistics need to be mapped with the system created statistics later by using table name, schema name and column name
	IF @column_name IS NOT NULL
		EXECUTE sp_addAutoCreatedStatisticsCommand @sql_script, @table_name, @schema_name, @column_name, @index_name;
	-- all other regular and user created statistics are fixed, just need the index name for copy
	ELSE
		EXECUTE sp_addStatisticsCommand @sql_script, @index_name;
END
ELSE
	PRINT '>>> No Statistics ...';

CLOSE cur; 
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP creates the statistics for all indexes of a table from the source database
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneIndexesStatistics', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneIndexesStatistics;
GO

CREATE PROCEDURE sp_cloneIndexesStatistics
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> COPY INDEXES STATISTICS';

-- get all statistics indexes from the source database
DECLARE @TempIndexes TABLE(table_name nvarchar(max), schema_name nvarchar(max), index_name nvarchar(max), column_name nvarchar(max), auto_created binary, user_created binary, has_filter binary, filter_definition nvarchar(max), 
		object_id bigint, stats_id bigint, stats_column_id bigint, UNIQUE NONCLUSTERED(object_id, stats_id, stats_column_id));

SET @sql_script = 
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT t.table_name AS table_name, t.schema_name AS schema_name, s.name AS index_name, c.name AS column_name, s.auto_created AS auto_created, s.user_created AS user_created, s.has_filter AS has_filter, ' +
	's.filter_definition AS filter_definition, sc.object_id AS object_id, sc.stats_id AS stats_id, sc.stats_column_id AS stats_column_id' + char(13) + 
	'FROM ##AllTableAndViews AS t' + char(13) +
	'INNER JOIN sys.stats AS s ON s.object_id = t.object_id' + char(13) +
	'INNER JOIN sys.stats_columns AS sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id' + char(13) +
	'INNER JOIN sys.columns AS c ON sc.object_id = c.object_id AND sc.column_id = c.column_id;';
INSERT @TempIndexes EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @index_name nvarchar(max), @column_name nvarchar(max), @auto_created binary, @user_created binary, @has_filter binary, @filter_definition nvarchar(max);
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, index_name, column_name, auto_created, user_created, has_filter, filter_definition FROM @TempIndexes
	ORDER BY object_id, stats_id, stats_column_id;

-- the following are used for checking the change of index statement
DECLARE @previous_table_name nvarchar(max), @previous_schema_name nvarchar(max), @previous_index_name nvarchar(max), @previous_column_name nvarchar(max), 
		@index_column_field nvarchar(max), @prefix_field nvarchar(max), @suffix_field nvarchar(max), @separator nvarchar(max);
SET @previous_table_name = '';
SET @previous_schema_name = '';
SET @previous_index_name = '';
SET @index_column_field = '';
SET @separator = '';

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @index_name, @column_name, @auto_created, @user_created, @has_filter, @filter_definition;

-- loop through each index and update statistics
WHILE @@FETCH_STATUS = 0 BEGIN
	-- an index can be applied on multiple columns
	-- the result table is ordered by object_id and index_id, so if either the table / index changes, then it should be part of a new stats index statement	
	IF (@previous_table_name <> @table_name) OR (@previous_index_name <> @index_name) BEGIN
		-- add the clone command before handling the next stats index statement, and clone statistics
		IF @previous_index_name <> '' BEGIN
			-- there is a user created stats index, so create it first
			IF @index_column_field <> '' BEGIN 
				SET @sql_script = @prefix_field + @index_column_field + @suffix_field;
				EXECUTE sp_addStatisticsCommand @sql_script;
			END

			-- copy statistis
			EXECUTE sp_cloneObjectStatistics @source_database_name, @clone_database_name, @previous_table_name, @previous_schema_name, @previous_column_name, @previous_index_name;

			SET @index_column_field = '';
			SET @separator = '';
		END	

		-- need to have the system creating the statistics if it is auto created
		IF @auto_created = 1 BEGIN
			SET @sql_script =
				'USE [' + @clone_database_name + '];' + char(13) + 
				'DECLARE @dummy int;' + char(13) + 
				'SELECT @dummy = count(*)' + char(13) +
				'FROM [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + ']' + char(13) +
				'WHERE [' + @column_name + '] IS NOT NULL;';
			EXECUTE sp_addCloneCommand @sql_script;
		END
		-- need to create the stats index if it is user created
		ELSE IF @user_created = 1 BEGIN
			PRINT '>>> Stats Index [' + @index_name + '] is found in Table/View [' + @table_name + '] ...';

			SET @prefix_field = 
				'CREATE STATISTICS [' + @index_name + ']' + char(13) +
				'ON [' + @clone_database_name + '].[' + @schema_name + '].[' + @table_name + '] (';
			
			SET @suffix_field = ')';

			IF @has_filter = 1 AND @filter_definition IS NOT NULL
				SET @suffix_field = @suffix_field + char(13) + 'WHERE ' + @filter_definition + ';';
			ELSE
				SET @suffix_field = @suffix_field + ';';
		END
	END
	
	-- need to add columns of the stats index if it is user created
	IF @user_created = 1 BEGIN
		SET @index_column_field = @index_column_field + @separator + '[' + @column_name + ']';
		SET @separator = ', ';
	END

	SET @previous_table_name = @table_name;
	SET @previous_schema_name = @schema_name;
	SET @previous_index_name = @index_name;

	-- for auto created statistics, the column name is needed to check for the index name in the clone database
	IF @auto_created = 1
		SET @previous_column_name = @column_name;
	ELSE
		SET @previous_column_name = NULL;

	FETCH NEXT FROM cur INTO @table_name, @schema_name, @index_name, @column_name, @auto_created, @user_created, @has_filter, @filter_definition;
END

CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_index_name <> '' BEGIN
	IF @index_column_field <> '' BEGIN 
		SET @sql_script = @prefix_field + @index_column_field + @suffix_field;
		EXECUTE sp_addStatisticsCommand @sql_script;
	END

	EXECUTE sp_cloneObjectStatistics @source_database_name, @clone_database_name, @previous_table_name, @previous_schema_name, @previous_column_name, @previous_index_name;
END

GO

-----------------------------------------------------------------------
-- This SP clones data records of a table
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllDataFromTable', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllDataFromTable;
GO

CREATE PROCEDURE sp_cloneAllDataFromTable
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max),
	@table_name nvarchar(max),
	@schema_name nvarchar(max),
	@select_column_field nvarchar(max),
	@insert_column_field nvarchar(max)
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> CREATE CLONE DATA';

-- get all data from the given table of the source database
DECLARE @TempData TABLE(data_field varchar(max));

SET @sql_script = 
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT ' + @select_column_field + char(13) + 
	'FROM [' + @schema_name + '].[' + @table_name +'];'
INSERT @TempData EXECUTE sp_printAndExecute @sql_script;

DECLARE @data_field varchar(max);

DECLARE cur CURSOR LOCAL FOR
	SELECT data_field FROM @TempData;

OPEN cur;
FETCH NEXT FROM cur INTO @data_field;

-- loop through each record for input an insert command
WHILE @@FETCH_STATUS = 0 BEGIN
	SET @sql_script = 
		'USE [' + @clone_database_name + '];' + char(13) + 
		'INSERT INTO [' + @schema_name + '].[' + @table_name + '] (' + @insert_column_field + ')' + char(13) +
		'VALUES (' + @data_field + ');'

	EXECUTE sp_addCloneCommand @sql_script, 'DATA';

	FETCH NEXT FROM cur INTO @data_field;
END

CLOSE cur;
DEALLOCATE cur;

GO

-----------------------------------------------------------------------
-- This SP clones all tables and views with basic columns of the source database
-- Based on sys.tables, sys.columns and sys.indexes
-- Included identity, computed columns and heap partition
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneAllTableAndViews', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneAllTableAndViews;
GO

CREATE PROCEDURE sp_cloneAllTableAndViews
	@source_database_name nvarchar(max),
	@clone_database_name nvarchar(max),
	@clone_data_is_needed binary = 0
AS 

DECLARE @sql_script varchar(max);
PRINT '>>> CREATE CLONE TABLES';

-- get all tables and views from the source database
SET @sql_script = 
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT name AS table_name, object_id as object_id, SCHEMA_NAME(schema_id) as schema_name, type as type' + char(13) + 
	'FROM sys.tables;'
INSERT ##AllTableAndViews EXECUTE sp_printAndExecute @sql_script;

-- get all table columns and the heap partitions
DECLARE @TempTables TABLE(table_name nvarchar(max), schema_name nvarchar(max), data_space_name nvarchar(max), data_space_type nvarchar(max), 
		index_column_id bigint, column_name nvarchar(max), column_type nvarchar(max), column_max_length bigint, column_precision bigint, 
		column_scale bigint, column_collation_name nvarchar(max), column_is_nullable binary, column_is_ansi_padded binary, 
		column_is_rowguidcol binary, column_is_identity binary, column_is_filestream binary, column_is_replicated binary, 
		column_is_xml_document binary, column_is_sparse binary, computed_definition nvarchar(max), computed_is_persisted binary, 
		object_id bigint, column_id bigint, UNIQUE NONCLUSTERED(object_id, column_id));

-- create tables with columns
SET @sql_script =
	'USE [' + @source_database_name + '];' + char(13) + 
	'SELECT t.table_name AS table_name, t.schema_name as schema_name, ds.name AS data_space_name, ds.type_desc AS data_space_type, ' +
	'ic.column_id AS index_column_id, c.name AS column_name, ISNULL(TYPE_NAME(c.system_type_id), TYPE_NAME(c.user_type_id)) AS column_type, c.max_length AS column_max_length, ' + 
	'c.precision AS column_precision, c.scale AS column_scale, c.collation_name AS column_collation_name, c.is_nullable AS column_is_nullable, ' + 
	'c.is_ansi_padded AS column_is_ansi_padded, c.is_rowguidcol AS column_is_rowguidcol, c.is_identity AS column_is_identity, ' +
	'c.is_filestream AS column_is_filestream, c.is_replicated AS column_is_replicated, c.is_xml_document AS column_is_xml_document, ' +
	'cc.is_sparse AS column_is_sparse, cc.definition AS computed_definition, cc.is_persisted AS computed_is_persisted, c.object_id AS object_id, ' +
	'c.column_id AS column_id' + char(13) + 
	'FROM ##AllTableAndViews AS t' + char(13) +
	'LEFT JOIN sys.columns AS c ON c.object_id = t.object_id' + char(13) +
	'LEFT JOIN sys.computed_columns AS cc ON c.object_id = cc.object_id AND c.column_id = cc.column_id' + char(13) + 
	'LEFT JOIN sys.indexes AS i ON i.object_id = c.object_id AND i.type_desc = ''HEAP''' + char(13) +
	'LEFT JOIN sys.index_columns ic ON ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.column_id = c.column_id' + char(13) +
	'LEFT JOIN sys.data_spaces AS ds ON i.data_space_id = ds.data_space_id' + char(13) +
	'WHERE t.type = ''U'';';
INSERT @TempTables EXECUTE sp_printAndExecute @sql_script;

DECLARE @table_name nvarchar(max), @schema_name nvarchar(max), @index_description nvarchar(max), @data_space_name nvarchar(max), @data_space_type nvarchar(max), 
		@index_column_id bigint, @column_name nvarchar(max), @column_type nvarchar(max), @column_max_length bigint, @column_precision bigint, @column_scale bigint, 
		@column_collation_name nvarchar(max), @column_is_nullable binary, @column_is_ansi_padded binary, @column_is_rowguidcol binary, 
		@column_is_identity binary, @column_is_filestream binary, @column_is_replicated binary, @column_is_xml_document binary, @column_is_sparse binary, 
		@computed_definition nvarchar(max), @computed_is_persisted binary  
DECLARE cur CURSOR LOCAL FOR
	SELECT table_name, schema_name, data_space_name, data_space_type, index_column_id, column_name, column_type, column_max_length, column_precision, 
			column_scale, column_collation_name, column_is_nullable, column_is_ansi_padded, column_is_rowguidcol, column_is_identity, column_is_filestream, 
			column_is_replicated, column_is_xml_document, column_is_sparse, computed_definition, computed_is_persisted
	FROM @TempTables
	ORDER BY object_id, column_id;

OPEN cur;
FETCH NEXT FROM cur INTO @table_name, @schema_name, @data_space_name, @data_space_type, @index_column_id, @column_name, @column_type, @column_max_length, 
		@column_precision, @column_scale, @column_collation_name, @column_is_nullable, @column_is_ansi_padded, @column_is_rowguidcol, @column_is_identity, 
		@column_is_filestream, @column_is_replicated, @column_is_xml_document, @column_is_sparse, @computed_definition, @computed_is_persisted;

-- the following are used for checking the change of create table statement
DECLARE @previous_table_name nvarchar(max), @previous_schema_name nvarchar(max), @column_field nvarchar(max), @select_column_field nvarchar(max), 
		@insert_column_field nvarchar(max), @prefix_field nvarchar(max), @suffix_field nvarchar(max), @separator nvarchar(max), @ansi_padding_field1 varchar(max), 
		@ansi_padding_field2 varchar(max), @table_is_ansi_padded binary, @current_column_field nvarchar(max), @select_column_separator nvarchar(max), 
		@insert_column_separator nvarchar(max);
SET @previous_table_name = '';
SET @column_field = '';
SET @select_column_field = ''''' + ';
SET @insert_column_field = '';
SET @suffix_field = char(13) + ');';  
SET @separator = char(13);
SET @select_column_separator = '';
SET @insert_column_separator = '';

-- loop through each column and create in the clone database
WHILE @@FETCH_STATUS = 0 BEGIN
	-- only 'char', 'varchar', 'binary', 'varbinary' can set ansi_padded off
	IF @column_type NOT IN ('char', 'varchar', 'binary', 'varbinary') BEGIN
		SET @column_is_ansi_padded = 1; 
	END

	-- a table can have multiple columns
	-- the result table is ordered by object_id and column_id, so a new table should be created if the table name changes
	IF @previous_table_name <> @table_name BEGIN
		-- add the clone command before handling the next type statement
		IF @previous_table_name <> '' BEGIN
			SET @sql_script = @ansi_padding_field1 + @prefix_field + @column_field + @suffix_field + @ansi_padding_field2;
			EXECUTE sp_addCloneCommand @sql_script;
			EXECUTE sp_cloneObjectStatistics @source_database_name, @clone_database_name, @previous_table_name, @previous_schema_name;

			-- if need to copy data, then call clone data before reset all values
			IF (@clone_data_is_needed = 1) AND (@insert_column_field != '') BEGIN
				EXECUTE sp_cloneAllDataFromTable @source_database_name, @clone_database_name, @previous_table_name, @previous_schema_name, @select_column_field, @insert_column_field;
			END

			SET @column_field = '';
			SET @select_column_field = '';
			SET @insert_column_field = '';
			SET @suffix_field = char(13) + ');'; 
			SET @separator = char(13);
			SET @select_column_separator = '';
			SET @insert_column_separator = '';
		END

		PRINT '>>> Table [' + @table_name + '] is found ...';

		SET @prefix_field = 
			'USE [' + @clone_database_name + '];' + char(13) + 
			'CREATE TABLE [' + @schema_name + '].[' + @table_name + ']' + char(13) + 
			'(';

		IF @data_space_name IS NOT NULL AND @data_space_type <> 'PARTITION_SCHEME'
			SET @suffix_field = char(13) + ')' + char(13) + 'ON [' + @data_space_name + '];';

		-- set the default ansi padding field for the table as the first column
		IF @column_is_ansi_padded = 0 BEGIN
			SET @ansi_padding_field1 = 'SET ANSI_PADDING OFF;' + char(13);
			SET @ansi_padding_field2 = char(13) + 'SET ANSI_PADDING ON;';
			SET @table_is_ansi_padded = 0;
		END
		ELSE BEGIN
			SET @ansi_padding_field1 = 'SET ANSI_PADDING ON;' + char(13);
			SET @ansi_padding_field2 = char(13) + 'SET ANSI_PADDING OFF;';
			SET @table_is_ansi_padded = 1;
		END
	END

	PRINT '>>> Column [' + @column_name + '] is found in Table [' + @table_name + '] ...';

	SET @current_column_field = '[' + @column_name + ']';

	-- computed column
	IF @computed_definition IS NOT NULL BEGIN
		SET @current_column_field = @current_column_field + ' AS ' + @computed_definition;
			
		IF @computed_is_persisted = 1 BEGIN
			SET @current_column_field = @current_column_field + ' PERSISTED';
			
			IF @column_is_nullable = 0
				SET @current_column_field = @current_column_field + ' NOT NULL';
		END
	END
	-- normal column
	ELSE BEGIN
		SET @current_column_field = @current_column_field + ' ' + dbo.getColumnTypeString(@column_type, @column_precision, @column_scale, @column_max_length, @column_collation_name);
		
		IF @column_is_filestream = 1
			SET @current_column_field = @current_column_field + ' FILESTREAM';

		IF @column_is_nullable = 0
			SET @current_column_field = @current_column_field + ' NOT NULL';
		ELSE
			SET @current_column_field = @current_column_field + ' NULL';

		IF @column_is_identity = 1 BEGIN
			SET @current_column_field = @current_column_field + ' IDENTITY';
				
			IF @column_is_replicated = 0
				SET @current_column_field = @current_column_field + ' NOT FOR REPLICATION';
		END
		-- we don't need to input a value for identity and computed column
		ELSE BEGIN
			SET @select_column_field = @select_column_field + @select_column_separator + '[tempdb].[dbo].getValueStringByDataType(ISNULL(CONVERT(nvarchar(max), [' + @column_name + ']), ''NULL''), ''' + @column_type + ''')';
			SET @insert_column_field = @insert_column_field + @insert_column_separator + '[' + @column_name + ']';
			SET @select_column_separator = ' + '','' + ';
			SET @insert_column_separator = ', ';
		END

		IF @column_is_sparse = 1
			SET @current_column_field = @current_column_field + ' SPARSE';
	END

	-- if the column ansi padded value matches the table, create it as part of the table creation
	IF @column_is_ansi_padded = @table_is_ansi_padded BEGIN
		SET @column_field = @column_field + @separator + @current_column_field;
		SET @separator = ',' + char(13);

		-- handle partition scheme for partitioned table
		IF @data_space_type = 'PARTITION_SCHEME' AND @index_column_id IS NOT NULL
			SET @suffix_field = char(13) + ')' + char(13) + 'ON [' + @data_space_name + ']([' + @column_name + ']);';
	END
	-- otherwise, need to add the column after creating the table if the ansi padded value is different from the table
	ELSE BEGIN
		SET @ansi_padding_field2 = @ansi_padding_field2 + char(13) +
			'ALTER TABLE [' + @schema_name + '].[' + @table_name + ']' + char(13) +
			'ADD ' + @current_column_field;

		-- handle partition scheme for partitioned table
		IF @data_space_type = 'PARTITION_SCHEME' AND @index_column_id IS NOT NULL
			SET @ansi_padding_field2 = @ansi_padding_field2 + char(13) + 'ON [' + @data_space_name + ']([' + @column_name + ']);';
	END

	SET @previous_table_name = @table_name;
	SET @previous_schema_name = @schema_name;

	FETCH NEXT FROM cur INTO @table_name, @schema_name, @data_space_name, @data_space_type, @index_column_id, @column_name, @column_type, @column_max_length, 
			@column_precision, @column_scale, @column_collation_name, @column_is_nullable, @column_is_ansi_padded, @column_is_rowguidcol, @column_is_identity, 
			@column_is_filestream, @column_is_replicated, @column_is_xml_document, @column_is_sparse, @computed_definition, @computed_is_persisted;
END

CLOSE cur;
DEALLOCATE cur;

-- deal with the last call
IF @previous_table_name <> '' BEGIN
	SET @sql_script = @ansi_padding_field1 + @prefix_field + @column_field + @suffix_field + @ansi_padding_field2;
	EXECUTE sp_addCloneCommand @sql_script;
	EXECUTE sp_cloneObjectStatistics @source_database_name, @clone_database_name, @previous_table_name, @previous_schema_name;

	-- if need to copy data, then call clone data
	IF (@clone_data_is_needed = 1) AND (@insert_column_field != '') BEGIN
		EXECUTE sp_cloneAllDataFromTable @source_database_name, @clone_database_name, @previous_table_name, @previous_schema_name, @select_column_field, @insert_column_field;
	END
END

GO

--=====================================================================
-- Clone script section ends
--=====================================================================

--=====================================================================
-- Main function starts
--=====================================================================

-----------------------------------------------------------------------
-- This SP clones the source_db 
-- The clone database will be named as target_db
-- Usage: exec sp_cloneDatabase 'source_db', 'target_db';
-----------------------------------------------------------------------
IF OBJECT_ID('sp_cloneDatabase', 'P') IS NOT NULL 
	DROP PROCEDURE sp_cloneDatabase;
GO

CREATE PROCEDURE sp_cloneDatabase
	@source_database_name	nvarchar(max),
	@clone_database_name	nvarchar(max),
	@clone_data_is_needed	binary = 0,
	@clone_filename			nvarchar(max) = NULL,
	@clone_filemode			nvarchar(max) = 'EXPORT'
AS

IF OBJECT_ID('tempdb..##SQLScriptTable', 'U') IS NOT NULL DROP TABLE ##SQLScriptTable;
CREATE TABLE ##SQLScriptTable(sql_script varchar(max) NOT NULL, counter bigint IDENTITY PRIMARY KEY CLUSTERED);

IF OBJECT_ID('tempdb..##SQLScriptErrorTable', 'U') IS NOT NULL DROP TABLE ##SQLScriptErrorTable;
CREATE TABLE ##SQLScriptErrorTable(sql_script varchar(max) NOT NULL, counter bigint PRIMARY KEY CLUSTERED, error_message nvarchar(max));

IF OBJECT_ID('tempdb..##DataCommandTable', 'U') IS NOT NULL DROP TABLE ##DataCommandTable;
CREATE TABLE ##DataCommandTable(sql_script varchar(max) NOT NULL, counter bigint IDENTITY PRIMARY KEY CLUSTERED);

IF OBJECT_ID('tempdb..##DataCommandErrorTable', 'U') IS NOT NULL DROP TABLE ##DataCommandErrorTable;
CREATE TABLE ##DataCommandErrorTable(sql_script varchar(max) NOT NULL, counter bigint PRIMARY KEY CLUSTERED, error_message nvarchar(max));

IF OBJECT_ID('tempdb..##StatisticsCommandTable', 'U') IS NOT NULL DROP TABLE ##StatisticsCommandTable;
CREATE TABLE ##StatisticsCommandTable(sql_script varchar(max) NOT NULL, original_index_name nvarchar(max), clone_index_name nvarchar(max), counter bigint IDENTITY PRIMARY KEY CLUSTERED);

IF OBJECT_ID('tempdb..##StatisticsCommandErrorTable', 'U') IS NOT NULL DROP TABLE ##StatisticsCommandErrorTable;
CREATE TABLE ##StatisticsCommandErrorTable(sql_script varchar(max) NOT NULL, original_index_name nvarchar(max), clone_index_name nvarchar(max), counter bigint PRIMARY KEY CLUSTERED, error_message nvarchar(max));

IF OBJECT_ID('tempdb..##AutoCreatedStatisticsCommandTable', 'U') IS NOT NULL DROP TABLE ##AutoCreatedStatisticsCommandTable;
CREATE TABLE ##AutoCreatedStatisticsCommandTable(sql_script varchar(max) NOT NULL, table_name nvarchar(max), schema_name nvarchar(max), column_name nvarchar(max), original_index_name nvarchar(max));

-- we don't need the table for reading commands from file
IF @clone_filename IS NULL OR @clone_filemode = 'EXPORT' BEGIN
	IF OBJECT_ID('tempdb..##AllTableAndViews', 'U') IS NOT NULL DROP TABLE ##AllTableAndViews;
	CREATE TABLE ##AllTableAndViews(table_name nvarchar(max), object_id bigint PRIMARY KEY NONCLUSTERED, schema_name nvarchar(max), type nvarchar(max));
END

DECLARE @sql_script varchar(max), @fileExist int;
PRINT '>>> START AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';

PRINT '>>> CHECK DATABASES AND FILE EXISTENCE';

-- check for file existence if file option is on 
IF @clone_filename IS NOT NULL BEGIN
	EXECUTE @fileExist = sp_isFileExist @clone_filename;
	
	-- file object creation error, fatal
	IF @fileExist = -1 BEGIN
		RAISERROR (N'The COM File Object cannot be created with path [%s]. Please check with DBA.', -1, -1, @clone_filename);
		RETURN;
	END

	-- the file should not exist for write option
	IF @clone_filemode = 'EXPORT' AND @fileExist = 1 BEGIN
		RAISERROR (N'The file with path [%s] has already existed. Please check with DBA.', -1, -1, @clone_filename);
		RETURN;
	END

	-- the file should be exist for read option
	IF @clone_filemode = 'IMPORT' AND @fileExist = 0 BEGIN
		RAISERROR (N'The file with path [%s] does not exist. Please check with DBA.', -1, -1, @clone_filename);
		RETURN;
	END
END

-- we don't need the source DB for reading commands from file
IF @clone_filename IS NULL OR @clone_filemode = 'EXPORT' BEGIN
	-- check the existing of the input source database
	IF DB_ID(@source_database_name) IS NULL BEGIN
		RAISERROR (N'The source database [%s] does not exist. Please check with DBA.', -1, -1, @source_database_name);
		RETURN;
	END
END

-- we don't need the clone DB for writing commands to file
IF @clone_filename IS NULL OR @clone_filemode = 'IMPORT' BEGIN
	-- checking database existence
	IF DB_ID(@clone_database_name) IS NOT NULL BEGIN
		RAISERROR (N'The target database [%s] exists. Please check with DBA.', -1, -1, @clone_database_name);
		RETURN;
	END
END

-- phase 1: get clone and statistic commands
-- if we are in the reading file mode, we get all the commands from the file directly 
IF @clone_filename IS NOT NULL AND @clone_filemode = 'IMPORT' BEGIN
	PRINT '>>> READING COMMANDS FROM FILE AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
	EXECUTE sp_getCommandFromFile @clone_filename
END
-- otherwise, we get the clone commands from the original DB
ELSE BEGIN
	PRINT '>>> CLONING COMMANDS AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';

	-- create the clone database of the source database
	EXECUTE sp_createCloneDatabase @source_database_name, @clone_database_name;

	-- copy all schemas
	EXECUTE sp_cloneAllSchemas @source_database_name, @clone_database_name;

	-- copy all filegroups
	EXECUTE sp_cloneAllFileGroups @source_database_name, @clone_database_name;

	-- copy all partition functions and schemes
	EXECUTE sp_cloneAllPartitionFucntions @source_database_name, @clone_database_name;
	EXECUTE sp_cloneAllPartitionSchemes @source_database_name, @clone_database_name;

	-- copy all assemblies
	EXECUTE sp_cloneAllAssemblies @source_database_name, @clone_database_name;

	-- copy all types
	EXECUTE sp_cloneAllTypes @source_database_name, @clone_database_name;

	-- copy all tables/views and basic columns
	EXECUTE sp_cloneAllTableAndViews @source_database_name, @clone_database_name, @clone_data_is_needed;

	-- copy all computed column properties of the tables/views
	-- removed because computed columns are created with cloneAllTableAndViews
	-- EXECUTE sp_cloneAllComputedColumns @source_database_name, @clone_database_name;

	-- copy all modules of the tables/views
	EXECUTE sp_cloneAllModules @source_database_name, @clone_database_name;

	-- copy all index properties of the tables/views
	EXECUTE sp_cloneAllIndexes @source_database_name, @clone_database_name;

	-- copy all foreign keys
	EXECUTE sp_cloneAllForeignKeys @source_database_name, @clone_database_name;

	-- copy all other constraint properties of the tables/views
	EXECUTE sp_cloneAllCheckConstraints @source_database_name, @clone_database_name;
	EXECUTE sp_cloneAllDefaultConstraints @source_database_name, @clone_database_name;

	-- copy all index statistics of the tables/views
	EXECUTE sp_cloneIndexesStatistics @source_database_name, @clone_database_name;
END

-- phase 2: execute clone and statistic commands
-- if we are in the writing file mode, we copy all the commands to the file directly 
IF @clone_filename IS NOT NULL AND @clone_filemode = 'EXPORT' BEGIN
	PRINT '>>> WRITING COMMANDS TO FILE AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
	EXECUTE sp_copyCommandToFile @clone_filename
END
-- otherwise, we run the commands
ELSE BEGIN
	-- execute each sql command from the above sp
	-- currently using a repeating loop to solve the dependency issues
	-- later version can use sys.sql_expression_dependencies 
	PRINT '>>> APPLY CLONE COMMANDS AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
	DECLARE @PASS binary, @command_counter bigint;
	SET @PASS = 1;

	INSERT ##SQLScriptErrorTable SELECT *, NULL FROM ##SQLScriptTable;
	SELECT @command_counter = COUNT(*) FROM ##SQLScriptErrorTable;

	-- first, copy schema
	WHILE @PASS = 1 AND @command_counter > 0 BEGIN 
		SET @PASS = 0;

		DECLARE cur CURSOR LOCAL FOR
			SELECT sql_script FROM ##SQLScriptErrorTable ORDER BY counter;

		OPEN cur
		FETCH NEXT FROM cur INTO @sql_script;

		-- loop through each sql command and execute
		WHILE @@FETCH_STATUS = 0 BEGIN
			BEGIN TRY
				EXECUTE (@sql_script);
				SET @PASS = 1;
				PRINT 'Execution = PASS {' + char(13) + @sql_script + char(13) + '} ...';
				DELETE FROM ##SQLScriptErrorTable WHERE CURRENT OF cur;
			END TRY

			BEGIN CATCH
			END CATCH

			FETCH NEXT FROM cur INTO @sql_script;
		END

		CLOSE cur;
		DEALLOCATE cur;

		SELECT @command_counter = COUNT(*) FROM ##SQLScriptErrorTable;
	END

	-- if some commands fail
	IF @command_counter > 0 BEGIN
		PRINT '>>> SOME CLONE COMMANDS ARE NOT EXECUTABLE - PLEASE CHECK IF NEEDED ...';

		DECLARE cur CURSOR LOCAL FOR
			SELECT sql_script FROM ##SQLScriptErrorTable ORDER BY counter;

		OPEN cur
		FETCH NEXT FROM cur INTO @sql_script;

		-- loop through each command and execute
		WHILE @@FETCH_STATUS = 0 BEGIN
			BEGIN TRY
				EXECUTE (@sql_script);
				PRINT 'Execution = PASS {' + char(13) + @sql_script + char(13) + '} ...';

				DELETE FROM ##SQLScriptErrorTable 
				WHERE CURRENT OF cur;
			END TRY

			BEGIN CATCH
				UPDATE ##SQLScriptErrorTable
				SET error_message = ERROR_MESSAGE()
				WHERE CURRENT OF cur;

				PRINT 'STATEMENT:' + char(13) + @sql_script;
				PRINT 'ERROR: ' + ERROR_MESSAGE();
			END CATCH

			FETCH NEXT FROM cur INTO @sql_script;
		END

		CLOSE cur;
		DEALLOCATE cur;

		-- show all commands
		SELECT counter AS COMMAND_ID, sql_script AS CLONE_COMMAND FROM ##SQLScriptTable ORDER BY counter;

		-- show commands that are not executable
		SELECT counter AS COMMAND_ID, sql_script AS NON_EXCUTABLE_CLONE_COMMAND, error_message AS ERROR FROM ##SQLScriptErrorTable ORDER BY counter;
	END
	ELSE
		PRINT '>>> ALL OBJECTS ARE CLONED SUCCESSFULLY ...';

	INSERT ##DataCommandErrorTable SELECT *, NULL FROM ##DataCommandTable;

	-- second, copy data
	PRINT '>>> APPLY DATA COMMANDS AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
	SET @PASS = 1;

	DECLARE cur CURSOR LOCAL FOR
		SELECT sql_script FROM ##DataCommandErrorTable ORDER BY counter;

	OPEN cur
	FETCH NEXT FROM cur INTO @sql_script;

	-- loop through each data command and execute
	WHILE @@FETCH_STATUS = 0 BEGIN
		BEGIN TRY
			EXECUTE (@sql_script);
			PRINT 'Execution = PASS {' + char(13) + @sql_script + char(13) + '} ...';

			DELETE FROM ##DataCommandErrorTable 
			WHERE CURRENT OF cur;
		END TRY

		BEGIN CATCH
			UPDATE ##DataCommandErrorTable
			SET error_message = ERROR_MESSAGE()
			WHERE CURRENT OF cur;

			PRINT 'STATEMENT: ' + @sql_script;
			PRINT 'ERROR: ' + ERROR_MESSAGE();
			SET @PASS = 0;
		END CATCH

		FETCH NEXT FROM cur INTO @sql_script;
	END

	CLOSE cur;
	DEALLOCATE cur;

	-- if some commands fail	
	IF @PASS = 0 BEGIN
		PRINT '>>> SOME DATA CANNOT BE COPIED, PLEASE CHECK CORRESPONDING TABLES ...';

		-- show all data commands
		SELECT counter AS COMMAND_ID, sql_script AS DATA_COMMAND FROM ##DataCommandTable ORDER BY counter;

		-- show all non executeable data commands
		SELECT counter AS COMMAND_ID, sql_script AS NON_EXCUTABLE_DATA_COMMAND, error_message AS ERROR FROM ##DataCommandErrorTable ORDER BY counter;
	END
	ELSE
		PRINT '>>> ALL DATA IS COPIED SUCCESSFULLY ...';

	-- map auto created statistics from the original database to the clone database 
	PRINT '>>> MAP STATISTICS AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
	EXECUTE sp_mapAutoCreatedStatistics @clone_database_name;

	INSERT ##StatisticsCommandErrorTable SELECT *, NULL FROM ##StatisticsCommandTable;

	-- finally, copy statistics
	PRINT '>>> APPLY STATISTICS COMMANDS AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
	SET @PASS = 1;

	DECLARE cur CURSOR LOCAL FOR
		SELECT sql_script FROM ##StatisticsCommandErrorTable ORDER BY counter;

	OPEN cur
	FETCH NEXT FROM cur INTO @sql_script;

	-- loop through each statistics command and execute
	WHILE @@FETCH_STATUS = 0 BEGIN
		BEGIN TRY
			EXECUTE (@sql_script);
			PRINT 'Execution = PASS {' + char(13) + @sql_script + char(13) + '} ...';

			DELETE FROM ##StatisticsCommandErrorTable 
			WHERE CURRENT OF cur;
		END TRY

		BEGIN CATCH
			UPDATE ##StatisticsCommandErrorTable
			SET error_message = ERROR_MESSAGE()
			WHERE CURRENT OF cur;

			PRINT 'STATEMENT: ' + @sql_script;
			PRINT 'ERROR: ' + ERROR_MESSAGE();
			SET @PASS = 0;
		END CATCH

		FETCH NEXT FROM cur INTO @sql_script;
	END

	CLOSE cur;
	DEALLOCATE cur;

	-- if some commands fail	
	IF @PASS = 0 BEGIN
		PRINT '>>> SOME STATISTICS CANNOT BE COPIED, PLEASE CHECK CORRESPONDING OBJECTS ...';

		-- show all statistics commands
		SELECT counter AS COMMAND_ID, sql_script AS STATISTICS_COMMAND, original_index_name AS ORIGINAL_INDEX_NAME, clone_index_name AS CLONE_INDEX_NAME FROM ##StatisticsCommandTable ORDER BY counter;

		-- show all non executeable statistics commands
		SELECT counter AS COMMAND_ID, sql_script AS NON_EXCUTABLE_STATISTICS_COMMAND, original_index_name AS ORIGINAL_INDEX_NAME, clone_index_name AS CLONE_INDEX_NAME, error_message AS ERROR FROM ##StatisticsCommandErrorTable ORDER BY counter;
	END
	ELSE
		PRINT '>>> ALL STATISTICS ARE COPIED SUCCESSFULLY ...';

	--DROP TABLE ##SQLScriptTable;
	--DROP TABLE ##SQLScriptErrorTable;
	--DROP TABLE ##AllTableAndViews;
	--DROP TABLE ##StatisticsCommandTable;
	--DROP TABLE ##StatisticsCommandErrorTable;
	--DROP TABLE ##AutoCreatedStatisticsCommandTable;
	--DROP TABLE ##DataCommandTable;
	--DROP TABLE ##DataCommandErrorTable;
	PRINT '>>> COMPLETED AT (' + CONVERT(VARCHAR(8), GETDATE(), 108) + ', ' + CONVERT(VARCHAR(10), GETDATE(), 101) + ')';
END

GO

--=====================================================================
-- Main function ends
--=====================================================================

-- Example 1: clone the schema locally on the same instance
-- use tempdb
-- if db_id('dummy') is not null drop database dummy
-- EXEC sp_cloneDatabase 'Insight_Dev_700', 'dummy'

-- Example 2: clone the schema and data on the same instance
-- use tempdb
-- if db_id('dummy') is not null drop database dummy
-- EXEC sp_cloneDatabase 'Insight_Dev_700', 'dummy', 1

-- Example 3: clone backup the schema and data to a file (backup to a file)
-- use tempdb
-- if db_id('dummy') is not null drop database dummy
-- EXEC sp_cloneDatabase 'Insight_Dev_700', 'dummy', 1, 'D:\test.txt', 'EXPORT'

-- Example 4: clone restore the schema and data from a file (restore from a file)
-- use tempdb
-- if db_id('dummy') is not null drop database dummy
-- EXEC sp_cloneDatabase 'Insight_Dev_700', 'dummy', 1, 'D:\test.txt', 'IMPORT'