-- Check Resource_Semaphore sizes.
SELECT
    [resource_semaphore_id]
    , [target_memory_kb] / 1024. AS target_memory_MB
    , [max_target_memory_kb] / 1024. AS max_target_memory_MB
    , [total_memory_kb] / 1024. AS total_memory_MB
    , [available_memory_kb] / 1024. AS available_memory_MB
    , * 
FROM [sys].[dm_exec_query_resource_semaphores]

-- Checking Memory pending sessions.
SELECT * FROM [sys].[dm_exec_query_memory_grants]