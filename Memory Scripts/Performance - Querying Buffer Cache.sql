/***********************************************************************************************************************************************
Description:	Get buffer cache info per database in the server.
Date:			2013-06-20
Author:			Alvaro Costa
***********************************************************************************************************************************************/

USE master
GO

-- Get page count per DB.
SELECT
	(CASE WHEN ([is_modified] = 1) THEN 'Dirty' ELSE 'Clean' END) AS 'Page State'
	, (CASE WHEN ([database_id] = 32767) THEN 'Resource Database' ELSE DB_NAME (database_id) END) AS 'Database Name'
	, CAST( (SUM(free_space_in_bytes) / 1024. / 1024.) AS DECIMAL(10,2)) AS 'Total Free Space (MB)'
	, COUNT (*) AS 'Page Count'
FROM sys.dm_os_buffer_descriptors
GROUP BY [database_id], [is_modified]
ORDER BY [database_id], [is_modified];
GO

-- Get page info per DB.
SELECT TOP 10
	DB_NAME (database_id) AS Database_Name
	, file_id
	, page_id
	, page_level
	, allocation_unit_id
	, page_type
	, row_count
	, free_space_in_bytes
	, is_modified
	, numa_node
FROM sys.dm_os_buffer_descriptors
WHERE DB_NAME (database_id) = '<DBName>'
ORDER BY page_type;
GO