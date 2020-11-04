USE master;
GO

IF OBJECT_ID('sp_AllocationMetadata') IS NOT NULL
    DROP PROCEDURE sp_AllocationMetadata;
GO

CREATE PROCEDURE sp_AllocationMetadata
    (
     @object VARCHAR(128) = NULL
    )
AS
    SELECT  OBJECT_NAME(sp.object_id) AS [Object Name]
           ,sp.index_id AS [Index ID]
           ,sa.allocation_unit_id AS [Alloc Unit ID]
           ,sa.type_desc AS [Alloc Unit Type]
           ,'(' + CONVERT (VARCHAR(6), CONVERT (INT, SUBSTRING(sa.first_page,
                                                              6, 1)
            + SUBSTRING(sa.first_page, 5, 1))) + ':'
            + CONVERT (VARCHAR(20), CONVERT (INT, SUBSTRING(sa.first_page, 4,
                                                            1)
            + SUBSTRING(sa.first_page, 3, 1) + SUBSTRING(sa.first_page, 2, 1)
            + SUBSTRING(sa.first_page, 1, 1))) + ')' AS [First Page]
           ,'(' + CONVERT (VARCHAR(6), CONVERT (INT, SUBSTRING(sa.root_page, 6,
                                                              1)
            + SUBSTRING(sa.root_page, 5, 1))) + ':'
            + CONVERT (VARCHAR(20), CONVERT (INT, SUBSTRING(sa.root_page, 4, 1)
            + SUBSTRING(sa.root_page, 3, 1) + SUBSTRING(sa.root_page, 2, 1)
            + SUBSTRING(sa.root_page, 1, 1))) + ')' AS [Root Page]
           ,'('
            + CONVERT (VARCHAR(6), CONVERT (INT, SUBSTRING(sa.first_iam_page,
                                                           6, 1)
            + SUBSTRING(sa.first_iam_page, 5, 1))) + ':'
            + CONVERT (VARCHAR(20), CONVERT (INT, SUBSTRING(sa.first_iam_page,
                                                            4, 1)
            + SUBSTRING(sa.first_iam_page, 3, 1) + SUBSTRING(sa.first_iam_page,
                                                             2, 1)
            + SUBSTRING(sa.first_iam_page, 1, 1))) + ')' AS [First IAM Page]
    FROM    sys.system_internals_allocation_units AS sa
           ,sys.partitions AS sp
    WHERE   sa.container_id = sp.partition_id
            AND sp.object_id = (CASE WHEN (@object IS NULL) THEN sp.object_id
                                     ELSE OBJECT_ID(@object)
                                END);
GO

EXEC sys.sp_MS_marksystemobject sp_AllocationMetadata;
GO