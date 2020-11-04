USE master
GO

DECLARE
	@iCount INT
	, @bExecStmt BIT
	, @sSQLStmt NVARCHAR(MAX)
	, @sLogSize VARCHAR(12)
	, @sDataSize VARCHAR(12)
	, @iNumberDataFiles INT
	, @sLogFolder VARCHAR(256)
	, @sDataFolder VARCHAR(256);

SET @iCount = 1;

-- Set the log and data folder appropreately without an ending back slash. Ex.: F:\Data

-- LOG FOLDER
SET @sLogFolder = 'T:\SQLData';

-- DATA FOLDER
SET @sDataFolder = 'T:\SQLData';


-- Set data files size.
SET @sDataSize = '2048MB';

-- Set log file size.
SET @sLogSize = '512MB';

-- If 1 then the statment will be executed.
SET @bExecStmt = 0

-- Number of data files.
SET @iNumberDataFiles = (
	SELECT
		CASE WHEN COUNT(1) >= 8 THEN 8 ELSE COUNT(1) END AS Cnt_Proc
	FROM sys.[dm_os_schedulers] dos
	WHERE [scheduler_id] < 255
);	

IF (@sDataFolder IS NOT NULL) AND (@sLogFolder IS NOT NULL)
BEGIN
	------------------------------------------------------------------------------------------------------------------------------------------------
	-- Data

	SET @sSQLStmt = N'
-- Modify Primary Data File.
ALTER DATABASE [tempdb] MODIFY FILE (
	NAME = ''tempdev''
	, SIZE = ' + @sDataSize + '
	, FILEGROWTH = 512MB
	, FILENAME = ''' + @sDataFolder + '\tempdb.mdf''
)
	';

	-- Add extra data files.
	WHILE @iCount <= (@iNumberDataFiles - 1)
	BEGIN
		SET @sSQLStmt = @sSQLStmt + N'
-- Add Data File and Set Autogrow (Last Data File).
ALTER DATABASE [tempdb] ADD FILE (
	NAME = ''tempdev' + CAST( (@iCount + 1) AS VARCHAR(4) ) + '''
	, SIZE = ' + @sDataSize + '
	, FILEGROWTH = 512MB
	, FILENAME = ''' + @sDataFolder + '\tempdb' + CAST( (@iCount + 1) AS VARCHAR(4) ) + '.ndf''
)';		

		SET @iCount = @iCount + 1;
	END

	------------------------------------------------------------------------------------------------------------------------------------------------
	-- Log.

	SET @sSQLStmt = @sSQLStmt + N'
-- Modify Log File.
ALTER DATABASE [tempdb] MODIFY FILE (
	NAME = ''templog''
	, SIZE = ' + @sLogSize + '
	, FILEGROWTH = 512MB
	, FILENAME = ''' + @sLogFolder + '\templog.ldf''
)
	';

    ------------------------------------------------------------------------------------------------------------------------------------------------
    -- Execute.

    IF @bExecStmt = 1
	   EXEC [sys].[sp_executesql] @sSQLStmt;
    ELSE
	   PRINT (@sSQLStmt)
END
