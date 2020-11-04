IF OBJECT_ID('TempDB..#ServerStats') IS NOT NULL
    DROP TABLE #ServerStats;

CREATE TABLE #ServerStats
(
    create_time DATETIME
    , component_type sysname
    , component_name sysname
    , state INT
    , state_desc sysname
    , data XML
);
INSERT INTO #ServerStats
EXECUTE [sys].[sp_server_diagnostics];

-- System
SELECT
    'System' AS "System"
    , data.value('(/system/@systemCpuUtilization)[1]', 'bigint') AS [System CPU]
    , data.value('(/system/@sqlCpuUtilization)[1]', 'bigint') AS [SQL CPU]
    , data.value('(/system/@nonYieldingTasksReported)[1]', 'bigint') AS [Non-yielding Tasks]
    , data.value('(/system/@pageFaults)[1]', 'bigint') AS [Page Faults]
    , data.value('(/system/@latchWarnings)[1]', 'bigint') AS [Latch Warnings]
FROM #ServerStats
WHERE component_name LIKE 'system';

-- Memory
SELECT
    'Memory' AS [Memory]
    , CAST(data.value('(/resource/memoryReport/entry[@description="Working Set"]/@value)[1]','float') / 1024. / 1024. AS DECIMAL(10,2)) AS [Memory Used by SQL Server (MB)]
    , CAST(data.value('(/resource/memoryReport/entry[@description="Available Physical Memory"]/@value)[1]','float') / 1024. / 1024. AS DECIMAL(10,2)) AS [Physical Memory Available (MB)]
    , data.value('(/resource/@lastNotification)[1]', 'varchar(100)') AS [Last Notification]
    , data.value('(/resource/@outOfMemoryExceptions)[1]', 'bigint') AS [Out of Memory Exceptions]
FROM #ServerStats
WHERE component_name LIKE 'resource';

-- Nonpreemptive waits by duration
SELECT
    'Non Preemptive by duration' AS [Non-Preemptive Wait]
    , tbl.evt.value('(@waitType)', 'varchar(100)') AS [Wait Type]
    , tbl.evt.value('(@waits)', 'bigint') AS [Waits]
    , tbl.evt.value('(@averageWaitTime)', 'bigint') AS [AVG Wait Time]
    , tbl.evt.value('(@maxWaitTime)', 'bigint') AS [Max Wait Time]
FROM #ServerStats
CROSS APPLY data.nodes('/queryProcessing/topWaits/nonPreemptive/byDuration/wait') AS tbl ( evt )
WHERE component_name LIKE 'query_processing';

-- Preemptive waits by duration
SELECT
    'Preemptive by duration' AS [Preemptive-Wait]
    , tbl.evt.value('(@waitType)', 'varchar(100)') AS [Wait Type]
    , tbl.evt.value('(@waits)', 'bigint') AS [Waits]
    , tbl.evt.value('(@averageWaitTime)', 'bigint') AS [AVG Wait Time]
    , tbl.evt.value('(@maxWaitTime)', 'bigint') AS [Max Wait Time]
FROM #ServerStats
CROSS APPLY data.nodes('/queryProcessing/topWaits/preemptive/byDuration/wait') AS tbl ( evt )
WHERE component_name LIKE 'query_processing';

-- Blocked Process Reports
SELECT
    'Blocked Process Report' AS [Blocked Process Report]
    , tbl.evt.query('.') AS [Report XML]
FROM #ServerStats
CROSS APPLY data.nodes('/queryProcessing/blockingTasks/blocked-process-report') AS tbl ( evt )
WHERE component_name LIKE 'query_processing';

-- IO report
SELECT
    'IO Subsystem' AS [IO Subsystem]
    , data.value('(/ioSubsystem/@ioLatchTimeouts)[1]', 'bigint') AS [Latch Timeouts]
    , data.value('(/ioSubsystem/@totalLongIos)[1]', 'bigint') AS [Total Long IOs]
FROM #ServerStats
WHERE component_name LIKE 'io_subsystem';

-- Event information
SELECT
    tbl.evt.value('(@name)', 'varchar(100)') AS [Event Name]
    , tbl.evt.value('(@package)', 'varchar(100)') AS [Package]
    , tbl.evt.value('(@timestamp)', 'datetime') AS [Event Time]
    , tbl.evt.query('.') AS [Event Data]
FROM #ServerStats
CROSS APPLY data.nodes('/events/session/RingBufferTarget/event') AS tbl ( evt )
WHERE component_name LIKE 'events';