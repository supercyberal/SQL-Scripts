SELECT
    database_name = 
        DB_NAME(mf.database_id),    
    logical_name = 
        mf.name,
    file_name = 
        mf.physical_name,
    size_gb = 
        (mf.size * 8) / 1024 / 1024,
    max_size_gb =
        CONVERT
        (
            bigint,
            CASE
                WHEN mf.max_size = -1
                THEN 0
                ELSE (mf.max_size * 8.) / 1024 / 1024
            END
        ),
    autogrowth_mb = 
        CASE 
            WHEN mf.is_percent_growth = 1
            THEN RTRIM(mf.growth) + N'%'
            WHEN (mf.growth * 8 / 1024) < 1024
            THEN RTRIM((mf.growth * 8) / 1024) + ' MB'
            WHEN (mf.growth * 8 / 1024) >= 1024
            THEN RTRIM((mf.growth * 8) / 1024 / 1024) + ' GB'
         END,
    usage = 
        CASE
            WHEN mf.type = 0
            THEN 'data'
            WHEN mf.type = 1
            THEN 'log'
            WHEN mf.type = 2
            THEN 'filestream'
            WHEN mf.type = 3
            THEN 'nope'
            WHEN mf.type = 4
            THEN 'fulltext'
        END
FROM sys.master_files AS mf
WHERE mf.database_id > 4
AND   mf.type = 1
ORDER BY
    mf.database_id,
    mf.type,
    mf.file_id
OPTION(RECOMPILE);