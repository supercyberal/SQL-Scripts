/***********************************************************************************************************************************************
Description: Get number of VLFs of a DB's log file.

Notes:
ACOSTA - 2013-12-20
	Created.
***********************************************************************************************************************************************/

DECLARE @tLogInfoRst TABLE (
	RecoveryUnitId INT NULL
	, FileID INT NOT NULL
	, FileSize BIGINT NOT NULL
	, StartOffSet BIGINT NOT NULL
	, FSeqNo BIGINT NOT NULL
	, [Status] TINYINT NOT NULL
	, Parity SMALLINT NOT NULL
	, CreateLSN VARCHAR(128) NOT NULL
);

IF CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR),4) AS DECIMAL(10,2)) >= 11
BEGIN
	INSERT @tLogInfoRst (
		[RecoveryUnitId]
		, [FileID]
		, [FileSize]
		, [StartOffSet]
		, [FSeqNo]
		, [Status]
		, [Parity]
		, [CreateLSN]
	)
	EXEC ('DBCC LOGINFO');	
END
ELSE
BEGIN
	INSERT @tLogInfoRst (		
		[FileID]
		, [FileSize]
		, [StartOffSet]
		, [FSeqNo]
		, [Status]
		, [Parity]
		, [CreateLSN]
	)
	EXEC ('DBCC LOGINFO');
END


SELECT
	CAST( ( ([FileSize] / 1024.) / 1024. ) AS DECIMAL(10,2) ) AS VLF_Size_MB
	, *
FROM @tLogInfoRst;

-- Get total size of log file.
SELECT	
	CAST( ( (SUM([FileSize]) / 1024.) / 1024. ) AS DECIMAL(10,2) ) AS VLF_Size_MB
FROM @tLogInfoRst;

