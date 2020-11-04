/***********************************************************************************************************************************************
Description:	Identify what Table and Indexes have compression turned on.

Notes:

ACOSTA - 2013-11-01
	Created.
***********************************************************************************************************************************************/

USE [Tfs_BusinessIntelligenceCollection]
GO

SELECT
	CASE WHEN LEFT(ix.[name],2) = 'pk' THEN
		'ALTER TABLE [' + s.[name] + '].[' + st.[name] + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = NONE)'
	ELSE
		'ALTER INDEX [' + ix.[name] + '] ON [' + s.[name] +'].[' + st.[name] + '] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = NONE)'
	END
	,s.[name] AS Tbl_Sch_Name
	,st.name AS Tbl_Name
    ,ix.name AS IX_Name
    ,st.object_id
    ,sp.partition_id
    ,sp.partition_number
    ,sp.data_compression
    ,sp.data_compression_desc
FROM    sys.partitions SP
        INNER JOIN sys.tables ST ON st.object_id = sp.object_id	
		JOIN [sys].[schemas] s ON s.[schema_id] = st.[schema_id]	
        LEFT OUTER JOIN sys.indexes IX ON sp.object_id = ix.object_id
                                          AND sp.index_id = ix.index_id
WHERE   sp.data_compression <> 0
ORDER BY st.name, sp.index_id



/*
================> CHANGE AREA <================

*/