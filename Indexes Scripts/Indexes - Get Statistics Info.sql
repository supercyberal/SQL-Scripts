/***********************************************************************************************************************************************
Description:	Get indexes statistics info.

Notes:			ACOSTA - 2016-09-27
				Created.
***********************************************************************************************************************************************/

USE [<DB-NAME-HERE>]
GO

-- Search tables and get its desired objectid.
SELECT * FROM [sys].[objects] AS [o]
WHERE [o].[name] LIKE '%'

-- Set ObjectID value into variable.
DECLARE @iObjID INT = 0;

SELECT  s.*
        , STATS_DATE([s].[object_id], [s].[stats_id]) AS [Stat_Date]
		, [st].*
FROM    [sys].[stats] AS [s]
CROSS APPLY (
	SELECT * 
	FROM [sys].[dm_db_stats_properties](s.[object_id],s.[stats_id]) AS [ddsp]
) st
WHERE   [s].[object_id] = OBJECT_ID(@iObjID);