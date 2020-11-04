/*
Name:	Get size per table.
Date:	2013-04-16
*/

SELECT * FROM (
SELECT 
    t.NAME AS TableName,
    p.rows AS RowCounts,

    -- Size in KB
    SUM(a.total_pages) * 8 AS TotalSpaceKB, 
    SUM(a.used_pages) * 8 AS UsedSpaceKB, 
    (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB,

    -- Size in MB
    CAST( (SUM(a.total_pages) * 8) / 1024. AS DECIMAL(10,2) ) AS TotalSpaceMB, 
    CAST( (SUM(a.used_pages) * 8) / 1024. AS DECIMAL(10,2) ) AS UsedSpaceMB, 
    CAST( ((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024. AS DECIMAL(10,2) ) AS UnusedSpaceMB
FROM 
    sys.tables t
INNER JOIN      
    sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN 
    sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN 
    sys.allocation_units a ON p.partition_id = a.container_id
WHERE 
    t.NAME NOT LIKE 'dt%' 
    AND t.is_ms_shipped = 0
    AND i.OBJECT_ID > 255 
GROUP BY 
    t.Name, p.Rows
) a
ORDER BY a.TotalSpaceKB DESC
    


