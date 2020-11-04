-- Get client connection info.
SELECT  [c].[session_id],
        [s].[host_name],
        [c].[client_net_address],
        CASE WHEN [T].[dbid] = 32767 THEN 'RESOURCEDB'
             ELSE DB_NAME([T].[dbid])
        END AS [DATABASE_NAME],
        [c].[protocol_type],
        [s].[client_interface_name],
        [driver_version] = CASE SUBSTRING(CAST([c].[protocol_version] AS BINARY(4)), 1, 1)
                           WHEN 0x70 THEN 'SQL Server 7.0'
                           WHEN 0x71 THEN 'SQL Server 2000'
                           WHEN 0x72 THEN 'SQL Server 2005'
                           WHEN 0x73 THEN 'SQL Server 2008'
                           WHEN 0x74 THEN 'SQL Server 2012 or above'
                           ELSE 'Unknown driver'
                         END,
        [s].[login_name],
        [c].[connect_time],
        [s].[login_time]
FROM    [sys].[dm_exec_connections] [c]
        JOIN [sys].[dm_exec_sessions] AS [s] ON [c].[session_id] = [s].[session_id]
        CROSS APPLY [sys].[dm_exec_sql_text]([c].[most_recent_sql_handle]) AS [T]  
--where client_net_address = '158.53.82.34'
--where s.host_name = 'AP1MSWR103'
--where DB_NAME(T.DBID) = 'AM1gmms02'
ORDER BY [s].[host_name],
        [c].[session_id];
