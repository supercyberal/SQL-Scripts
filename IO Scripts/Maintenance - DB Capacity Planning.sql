DECLARE	
	@vSQL_String AS NVARCHAR(MAX)
	, @vDatabase_Name AS NVARCHAR(500);

SELECT  name
INTO    #db
FROM    sys.databases;

WHILE (
	SELECT COUNT(*)
    FROM   #db
) > 0
BEGIN
    SELECT TOP 1
		@vDatabase_Name = name
    FROM #db

    SET @vSQL_String = '
        USE [' + @vDatabase_Name + '];

        INSERT INTO DBA_ADMIN..DBA_database_size_distribution
        SELECT
            @@servername as server_name
            , DB_NAME () AS database_name
            , REVERSE (SUBSTRING (REVERSE (CONVERT (VARCHAR (15), CONVERT (MONEY, ROUND ((A.total_size*CONVERT (BIGINT, 8192))/1048576.0, 0)), 1)), 4, 15)) AS total_size_mb
            , (
				CASE
					WHEN A.database_size >= B.total_pages THEN REVERSE (SUBSTRING (REVERSE (CONVERT (VARCHAR (15), CONVERT (MONEY, ROUND (((A.database_size-B.total_pages)*CONVERT (BIGINT, 8192))/1048576.0, 0)), 1)), 4, 15))
                ELSE 
					''0''
                END
			) AS unallocated_mb
            , REVERSE (SUBSTRING (REVERSE (CONVERT (VARCHAR (15), CONVERT (MONEY, ROUND ((B.total_pages*CONVERT (BIGINT, 8192))/1048576.0, 0)), 1)), 4, 15)) AS reserved_mb
            , REVERSE (SUBSTRING (REVERSE (CONVERT (VARCHAR (15), CONVERT (MONEY, ROUND ((B.pages*CONVERT (BIGINT, 8192))/1048576.0, 0)), 1)), 4, 15)) AS data_mb
            , REVERSE (SUBSTRING (REVERSE (CONVERT (VARCHAR (15), CONVERT (MONEY, ROUND (((B.used_pages-B.pages)*CONVERT (BIGINT, 8192))/1048576.0, 0)), 1)), 4, 15)) AS index_mb
            , REVERSE (SUBSTRING (REVERSE (CONVERT (VARCHAR (15), CONVERT (MONEY, ROUND (((B.total_pages-B.used_pages)*CONVERT (BIGINT, 8192))/1048576.0, 0)), 1)), 4, 15)) AS unused_mb
            , getdate()
        FROM
            (
                SELECT
                    SUM (CASE
                            WHEN DBF.type = 0 THEN DBF.size
                            ELSE 0
                            END) AS database_size
                    ,SUM (DBF.size) AS total_size
                FROM
                    [sys].[database_files] AS DBF
                WHERE
                    DBF.type IN (0,1)
            ) A

            CROSS JOIN

                (
                    SELECT
                        SUM (AU.total_pages) AS total_pages
                        ,SUM (AU.used_pages) AS used_pages
                        ,SUM (CASE
                                WHEN IT.internal_type IN (202,204) THEN 0
                                WHEN AU.type <> 1 THEN AU.used_pages
                                WHEN P.index_id <= 1 THEN AU.data_pages
                                ELSE 0
                                END) AS pages
                    FROM
                        [sys].[partitions] P
                        INNER JOIN [sys].[allocation_units] AU ON AU.container_id = P.partition_id
                        LEFT JOIN [sys].[internal_tables] IT ON IT.[object_id] = P.[object_id]
                ) B
    '

    BEGIN TRY
        EXEC (@vSQL_String)

        DELETE  FROM #db
        WHERE   name = @vDatabase_Name
    END TRY

    BEGIN CATCH
        INSERT  INTO DBA_ADMIN..DBA_database_size_distribution
        VALUES  (@@SERVERNAME, @vDatabase_Name, -1, -1, -1, -1, -1, -1,GETDATE())

        DELETE  FROM #db
        WHERE   name = @vDatabase_Name
    END CATCH
END
go
