-- =============================================================================================================================================
-- TOP 20 I/O Statements.

;WITH    high_io_queries
          AS (
               SELECT TOP 20
                query_hash
              , SUM(total_logical_reads + total_logical_writes) io
               FROM
                sys.dm_exec_query_stats
               WHERE
                query_hash <> 0x0
               GROUP BY
                query_hash
               ORDER BY
                SUM(total_logical_reads + total_logical_writes) DESC
             )
     SELECT
        @@servername AS servername
      , COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)), 'Resource') AS [DatabaseName]
      , COALESCE(OBJECT_NAME(st.objectid, st.dbid), '<none>') AS [object_name]
      , qs.query_hash
      , qs.total_logical_reads + total_logical_writes AS total_io
      , qs.execution_count
      , CAST(( total_logical_reads + total_logical_writes )
        / ( execution_count + 0.0 ) AS MONEY) AS average_io
      , io AS total_io_for_query
      , SUBSTRING(st.text, ( qs.statement_start_offset + 2 ) / 2,
                  ( CASE WHEN qs.statement_end_offset = -1
                         THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
                         ELSE qs.statement_end_offset
                    END - qs.statement_start_offset ) / 2) AS sql_text
      , qp.query_plan
     FROM
        sys.dm_exec_query_stats qs
     JOIN
        high_io_queries fq
        ON fq.query_hash = qs.query_hash
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
     CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
     OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
     WHERE
        pa.attribute = 'dbid'
     ORDER BY
        fq.io DESC
      , fq.query_hash
      , qs.total_logical_reads + total_logical_writes DESC
OPTION
        ( RECOMPILE )

-- =============================================================================================================================================
-- TOP 20 CPU Statements.

;WITH    high_cpu_queries
          AS (
               SELECT TOP 20
                query_hash
              , SUM(total_worker_time) cpuTime
               FROM
                sys.dm_exec_query_stats
               WHERE
                query_hash <> 0x0
               GROUP BY
                query_hash
               ORDER BY
                SUM(total_worker_time) DESC
             )
     SELECT
        @@servername AS server_name
      , COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)), 'Resource') AS [DatabaseName]
      , COALESCE(OBJECT_NAME(st.objectid, st.dbid), '<none>') AS [object_name]
      , qs.query_hash
      , qs.total_worker_time AS cpu_time
      , qs.execution_count
      , CAST(total_worker_time / ( execution_count + 0.0 ) AS MONEY) AS average_CPU_in_microseconds
      , cpuTime AS total_cpu_for_query
      , SUBSTRING(st.text, ( qs.statement_start_offset + 2 ) / 2,
                  ( CASE WHEN qs.statement_end_offset = -1
                         THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
                         ELSE qs.statement_end_offset
                    END - qs.statement_start_offset ) / 2) AS sql_text
      , qp.query_plan
     FROM
        sys.dm_exec_query_stats qs
     JOIN
        high_cpu_queries hcq
        ON hcq.query_hash = qs.query_hash
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
     CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
     OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
     WHERE
        pa.attribute = 'dbid'
     ORDER BY
        hcq.cpuTime DESC
      , hcq.query_hash
      , qs.total_worker_time DESC
OPTION
        ( RECOMPILE )

-- =============================================================================================================================================
-- TOP 20 Frequecy Statements.

;WITH    frequent_queries
          AS (
               SELECT TOP 20
                query_hash
              , SUM(execution_count) executions
               FROM
                sys.dm_exec_query_stats
               WHERE
                query_hash <> 0x0
               GROUP BY
                query_hash
               ORDER BY
                SUM(execution_count) DESC
             )
     SELECT
        @@servername AS server_name
      , COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)), 'Resource') AS [DatabaseName]
      , COALESCE(OBJECT_NAME(st.objectid, st.dbid), '<none>') AS [object_name]
      , qs.query_hash
      , qs.execution_count
      , executions AS total_executions_for_query
      , SUBSTRING(st.text, ( qs.statement_start_offset + 2 ) / 2,
                  ( CASE WHEN qs.statement_end_offset = -1
                         THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
                         ELSE qs.statement_end_offset
                    END - qs.statement_start_offset ) / 2) AS sql_text
      , qp.query_plan
     FROM
        sys.dm_exec_query_stats qs
     JOIN
        frequent_queries fq
        ON fq.query_hash = qs.query_hash
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
     CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
     OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
     WHERE
        pa.attribute = 'dbid'
     ORDER BY
        fq.executions DESC
      , fq.query_hash
      , qs.execution_count DESC
OPTION
        ( RECOMPILE )

-- =============================================================================================================================================
-- TOP 20 Duration Statements.

;WITH    long_queries
          AS (
               SELECT TOP 20
                query_hash
              , SUM(total_elapsed_time) elapsed_time
               FROM
                sys.dm_exec_query_stats
               WHERE
                query_hash <> 0x0
               GROUP BY
                query_hash
               ORDER BY
                SUM(total_elapsed_time) DESC
             )
     SELECT
        @@servername AS server_name
      , COALESCE(DB_NAME(st.dbid), DB_NAME(CAST(pa.value AS INT)), 'Resource') AS [DatabaseName]
      , COALESCE(OBJECT_NAME(st.objectid, st.dbid), '<none>') AS [object_name]
      , qs.query_hash
      , qs.total_elapsed_time
      , qs.execution_count
      , CAST(total_elapsed_time / ( execution_count + 0.0 ) AS MONEY) AS average_duration_in_ms
      , elapsed_time AS total_elapsed_time_for_query
      , SUBSTRING(st.text, ( qs.statement_start_offset + 2 ) / 2,
                  ( CASE WHEN qs.statement_end_offset = -1
                         THEN LEN(CONVERT(NVARCHAR(MAX), st.text)) * 2
                         ELSE qs.statement_end_offset
                    END - qs.statement_start_offset ) / 2) AS sql_text
      , qp.query_plan
     FROM
        sys.dm_exec_query_stats qs
     JOIN
        long_queries lq
        ON lq.query_hash = qs.query_hash
     CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
     CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
     OUTER APPLY sys.dm_exec_plan_attributes(qs.plan_handle) pa
     WHERE
        pa.attribute = 'dbid'
     ORDER BY
        lq.elapsed_time DESC
      , lq.query_hash
      , qs.total_elapsed_time DESC
OPTION
        ( RECOMPILE )