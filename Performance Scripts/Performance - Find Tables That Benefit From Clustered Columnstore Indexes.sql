-- picking the tables that qualify CCI
-- Key logic is
-- (a) Table does not have CCI
-- (b) At least one partition has > 1 million rows and does not have 
--     unsupported types for CCI
-- (c) Range queries account for > 50% of all operations
-- (d) DML Update/Delete operations < 10% of all operations

SELECT [summary_table].[table_id],
       [summary_table].[table_name]
FROM
(
    SELECT QUOTENAME(OBJECT_SCHEMA_NAME([dmv_ops_stats].[object_id])) + N'.'
           + QUOTENAME(OBJECT_NAME([dmv_ops_stats].[object_id])) AS [table_name],
           [dmv_ops_stats].[object_id] AS [table_id],
           SUM([dmv_ops_stats].[leaf_delete_count] + [dmv_ops_stats].[range_scan_count]
               + [dmv_ops_stats].[singleton_lookup_count] + [dmv_ops_stats].[leaf_update_count]
              ) AS [total_ops_count],
           SUM([dmv_ops_stats].[leaf_delete_count] + [dmv_ops_stats].[leaf_update_count]) AS [total_dml_count],
           SUM([dmv_ops_stats].[range_scan_count] + [dmv_ops_stats].[singleton_lookup_count]) AS [total_query_count],
           SUM([dmv_ops_stats].[range_scan_count]) AS [range_scan_count]
    FROM [sys].[dm_db_index_operational_stats](DB_ID(),
                                               NULL,
                                               NULL,
                                               NULL
                                              ) AS [dmv_ops_stats]
    WHERE (
              [dmv_ops_stats].[index_id] = 0
              OR [dmv_ops_stats].[index_id] = 1
          )
          AND [dmv_ops_stats].[object_id] IN
              (
                  SELECT DISTINCT
                      [p].[object_id]
                  FROM [sys].[partitions] AS [p]
                  WHERE [p].[data_compression] <= 2
                        AND (
                                [p].[index_id] = 0
                                OR [p].[index_id] = 1
                            )
                        AND [p].[rows] > 1048576
                        AND [p].[object_id] IN
                            (
                                SELECT DISTINCT
                                    [p].[object_id]
                                FROM [sys].[partitions] AS [p],
                                     [sys].[sysobjects] AS [o]
                                WHERE [o].[type] = 'u'
                                      AND [p].[object_id] = [o].[id]
                            )
              )
          AND [dmv_ops_stats].[object_id] NOT IN
              (
                  SELECT DISTINCT
                      [object_id]
                  FROM [sys].[columns]
                  WHERE [user_type_id] IN ( 34, 35, 241 )
                        OR (
                               (
                                   [user_type_id] = 165
                                   OR [user_type_id] = 167
                               )
                               AND [max_length] = -1
                           )
              )
          AND [dmv_ops_stats].[object_id] NOT IN
              (
                  SELECT DISTINCT
                      [object_id]
                  FROM [sys].[partitions]
                  WHERE [data_compression] > 2
              )
    GROUP BY [dmv_ops_stats].[object_id]
) AS [summary_table]
WHERE (
          ([summary_table].[total_dml_count] * 100.0 / NULLIF([summary_table].[total_ops_count], 0) < 10.0)
          AND ([summary_table].[range_scan_count] * 100.0 / NULLIF([summary_table].[total_query_count], 0) > 50.0)
      );