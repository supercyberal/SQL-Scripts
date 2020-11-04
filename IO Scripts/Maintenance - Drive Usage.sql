USE [master]
GO

DECLARE
	@hr INT
	, @fso INT
	, @drive CHAR(1)
	, @odrive INT
	, @TotalSize VARCHAR(20)
	, @MB BIGINT
	, @tableHTML NVARCHAR(max)

SET @MB = 1048576;

IF OBJECT_ID('tempdb..#drives') IS NOT NULL
	DROP TABLE #drives;

CREATE TABLE #drives (
	Drive CHAR(1) PRIMARY KEY
	, ServerName AS @@SERVERNAME
	, Date_Captured AS GETDATE()	
	, FreeSpace INT NULL
	, TotalSize INT NULL
	, Free_Percent AS CAST(( FreeSpace / ( TotalSize * 1.0 ) ) * 100.0 AS DECIMAL(10,2))
	, Send_Alert BIT NULL DEFAULT 0
);

INSERT  #drives ( Drive, FreeSpace )
EXEC master.dbo.xp_fixeddrives;

EXEC @hr= sp_OACreate 'Scripting.FileSystemObject', @fso OUT;

IF @hr <> 0 
    EXEC sp_OAGetErrorInfo @fso;

DECLARE dcur CURSOR LOCAL FAST_FORWARD
FOR
    SELECT  
		Drive
    FROM #drives;

OPEN dcur;

FETCH NEXT FROM dcur INTO @drive;

WHILE @@FETCH_STATUS = 0 
BEGIN
    EXEC @hr = sp_OAMethod @fso, 'GetDrive', @odrive OUT, @drive;

    IF @hr <> 0 
        EXEC sp_OAGetErrorInfo @fso;

    EXEC @hr = sp_OAGetProperty @odrive, 'TotalSize', @TotalSize OUT;
    
    IF @hr <> 0 
        EXEC sp_OAGetErrorInfo @odrive;

    UPDATE  #drives
    SET     TotalSize = @TotalSize / @MB
    WHERE   Drive = @drive;

    FETCH NEXT FROM dcur INTO @drive;
END

CLOSE dcur;
DEALLOCATE dcur;

EXEC @hr= sp_OADestroy @fso;

IF @hr <> 0 
    EXEC sp_OAGetErrorInfo @fso;

-- Get drive info.
SELECT
	ServerName
	, Drive
	, TotalSize AS [Total (MB)]
	, FreeSpace AS [Free (MB)]

	-- Space in MB
	, CAST( (TotalSize / 1024.) AS DECIMAL(10,2) ) AS [Total (GB)]
	, CAST( (FreeSpace / 1024.) AS DECIMAL(10,2) ) AS [Free (GB)]	

	-- Space in TB
	, CAST( (TotalSize / 1024. / 1024.) AS DECIMAL(10,2) ) AS [Total (TB)]
	, CAST( (FreeSpace / 1024. / 1024.) AS DECIMAL(10,2) ) AS [Free (TB)]	

	, Free_Percent AS [Free (%)]
	, Date_Captured
FROM #drives;


