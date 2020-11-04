USE [master];
GO

-- Create the event session
CREATE EVENT SESSION [CommandTimeouts]
ON SERVER
    ADD EVENT [sqlserver].[attention]
    (ACTION
     (
         [sqlserver].[client_app_name],
         [sqlserver].[client_hostname],
         [sqlserver].[client_pid],
         [sqlserver].[database_name],
         [sqlserver].[server_principal_name],
         [sqlserver].[session_id],
         [sqlserver].[sql_text]
     )
    )
    ADD TARGET [package0].[event_file]
    (SET [filename] = N'D:\Temp\CommandTimeouts.xel');
GO


-- Start the event session
ALTER EVENT SESSION [CommandTimeouts]
ON SERVER STATE = START;
GO

-- Query the event session data
SELECT [SessionEvents].[SessionEventData_XML].[value](N'(@timestamp)[1]', N'DATETIME2(7)') AS [EventDateTime_UTC],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="client_app_name"]/value)[1]', N'NVARCHAR(1000)') AS [ClientAppName],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="client_hostname"]/value)[1]', N'NVARCHAR(1000)') AS [ClientHostName],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="client_pid"]/value)[1]', N'BIGINT') AS [ClientProcessId],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="database_name"]/value)[1]', N'SYSNAME') AS [DatabaseName],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="server_principal_name"]/value)[1]', N'SYSNAME') AS [ServerPrincipalName],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="session_id"]/value)[1]', N'BIGINT') AS [SessionId],
       [SessionEvents].[SessionEventData_XML].[value](N'(action[@name="sql_text"]/value)[1]', N'NVARCHAR(MAX)') AS [SQLText]
FROM
(
    SELECT CAST([event_data] AS XML) AS [EventData_XML]
    FROM [sys].[fn_xe_file_target_read_file](N'D:\Temp\CommandTimeouts*.xel', NULL, NULL, NULL)
) AS [SessionEventData]
    CROSS APPLY [SessionEventData].[EventData_XML].[nodes](N'//event') AS [SessionEvents]([SessionEventData_XML]);
GO

-- Stop the event session
ALTER EVENT SESSION [CommandTimeouts] ON SERVER STATE = STOP;
GO

-- Drop the event session
DROP EVENT SESSION [CommandTimeouts] ON SERVER;
GO