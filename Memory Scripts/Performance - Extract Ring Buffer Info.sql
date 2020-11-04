/***********************************************************************************************************************************************
Name:		Extract info from the ring buffer (Article:	http://thesqldude.com/tag/ring-buffer/).

Notes:

ACOSTA - 2013-04-24
	Created.

ACOSTA - 2013-08-30
	Added memory info extraction.
***********************************************************************************************************************************************/

USE master
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Security Ring Buffer.

SELECT  CONVERT (VARCHAR(30), GETDATE(), 121) AS [RunTime] ,
        DATEADD(ms, x.[timestamp] - tme.ms_ticks, GETDATE()) AS [Notification_Time] ,
        x.xData.value('(//SPID)[1]', 'bigint') AS SPID ,
        x.xData.value('(//ErrorCode)[1]', 'varchar(255)') AS Error_Code ,
        x.xData.value('(//CallingAPIName)[1]', 'varchar(255)') AS [CallingAPIName] ,
        x.xData.value('(//APIName)[1]', 'varchar(255)') AS [APIName] ,
        x.xData.value('(//Record/@id)[1]', 'bigint') AS [Record Id] ,
        x.xData.value('(//Record/@type)[1]', 'varchar(30)') AS [Type] ,
        x.xData.value('(//Record/@time)[1]', 'bigint') AS [Record Time] ,
        tme.ms_ticks AS [Current Time]
FROM    (
			SELECT
				rbf.[timestamp]      
				, CAST(rbf.record AS XML) AS xData
			FROM sys.dm_os_ring_buffers rbf
			WHERE rbf.ring_buffer_type = 'RING_BUFFER_SECURITY_ERROR'
		) x
        CROSS JOIN sys.dm_os_sys_info tme
-- Find out about SPID info.
--WHERE x.xData.value('(//SPID)[1]', 'int') = 108
ORDER BY 2 DESC
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Connectivity Ring Buffer.

/*
For more network connectivity issues to be added to the log and severity 20 alerts to be sent, use the following traces:
DBCC TRACEON(3689, -1)
DBCC TRACEON(4029, -1)
*/

SELECT  CONVERT (VARCHAR(30), GETDATE(), 121) AS [RunTime]
        , DATEADD(ms, ( x.[timestamp] - tme.ms_ticks ), GETDATE()) AS Time_Stamp
        , x.xData.value('(//Record/ConnectivityTraceRecord/RecordType)[1]','varchar(50)') AS [Action]
        , x.xData.value('(//Record/ConnectivityTraceRecord/RecordSource)[1]','varchar(50)') AS [Source]
        , x.xData.value('(//Record/ConnectivityTraceRecord/Spid)[1]','int') AS [SPID]
        , x.xData.value('(//Record/ConnectivityTraceRecord/RemoteHost)[1]','varchar(100)') AS [RemoteHost]
        , x.xData.value('(//Record/ConnectivityTraceRecord/RemotePort)[1]','varchar(25)') AS [RemotePort]
        , x.xData.value('(//Record/ConnectivityTraceRecord/LocalPort)[1]','varchar(25)') AS [LocalPort]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsInputBufferError)[1]','varchar(25)') AS [TdsInputBufferError]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsOutputBufferError)[1]','varchar(25)') AS [TdsOutputBufferError]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsBuffersInformation/TdsInputBufferBytes)[1]','varchar(25)') AS [TdsInputBufferBytes]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/PhysicalConnectionIsKilled)[1]','int') AS [isPhysConnKilled]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/DisconnectDueToReadError)[1]','int') AS [DisconnectDueToReadError]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/NetworkErrorFoundInInputStream)[1]','int') AS [NetworkErrorFound]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/ErrorFoundBeforeLogin)[1]','int') AS [ErrorBeforeLogin]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/SessionIsKilled)[1]','int') AS [isSessionKilled]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/NormalDisconnect)[1]','int') AS [NormalDisconnect]
        , x.xData.value('(//Record/ConnectivityTraceRecord/TdsDisconnectFlags/NormalLogout)[1]','int') AS [NormalLogout]
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/TotalLoginTimeInMilliseconds)[1]', 'BIGINT') AS TotalLoginTimeInMilliseconds
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/LoginTaskEnqueuedInMilliseconds)[1]', 'BIGINT') AS LoginTaskEnqueuedInMilliseconds
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/NetworkWritesInMilliseconds)[1]', 'BIGINT') AS NetworkWritesInMilliseconds
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/NetworkReadsInMilliseconds)[1]', 'BIGINT') AS NetworkReadsInMilliseconds
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/SslProcessingInMilliseconds)[1]', 'BIGINT') AS SslProcessingInMilliseconds
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/SspiProcessingInMilliseconds)[1]', 'BIGINT') AS SspiProcessingInMilliseconds
		, x.xData.value('(//Record/ConnectivityTraceRecord/LoginTimers/LoginTriggerAndResourceGovernorProcessingInMilliseconds)[1]', 'BIGINT') AS LoginTriggerAndResourceGovernorProcessingInMilliseconds
        , x.xData.value('(//Record/@id)[1]', 'bigint') AS [Record Id]
        , x.xData.value('(//Record/@type)[1]', 'varchar(30)') AS [Type]
        , x.xData.value('(//Record/@time)[1]', 'bigint') AS [Record Time]
        , tme.ms_ticks AS [Current Time]
		, x.xData AS XML_Record
FROM    (
			SELECT
				rbf.[timestamp]      
				, CAST(rbf.record AS XML) AS xData
			FROM sys.dm_os_ring_buffers rbf
			WHERE rbf.ring_buffer_type = 'RING_BUFFER_CONNECTIVITY'
		) x
        CROSS JOIN sys.dm_os_sys_info tme
-- Find out about SPID info.
--WHERE   x.xData.value('(//Record/ConnectivityTraceRecord/Spid)[1]','int') <> 0
WHERE x.xData.value('(//Record/ConnectivityTraceRecord/RecordType)[1]','varchar(50)') = 'LoginTimers'
ORDER BY 2 DESC
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Exception Ring Buffer.

SELECT  CONVERT (VARCHAR(30), GETDATE(), 121) AS [RunTime] ,
        DATEADD(ms, ( rbf.[timestamp] - tme.ms_ticks ), GETDATE()) AS Time_Stamp ,
        CAST(record AS XML).value('(//Exception//Error)[1]', 'varchar(255)') AS [Error] ,
        CAST(record AS XML).value('(//Exception/Severity)[1]', 'varchar(255)') AS [Severity] ,
        CAST(record AS XML).value('(//Exception/State)[1]', 'varchar(255)') AS [State] ,
        msg.description ,
        CAST(record AS XML).value('(//Exception/UserDefined)[1]', 'int') AS [isUserDefinedError] ,
        CAST(record AS XML).value('(//Record/@id)[1]', 'bigint') AS [Record Id] ,
        CAST(record AS XML).value('(//Record/@type)[1]', 'varchar(30)') AS [Type] ,
        CAST(record AS XML).value('(//Record/@time)[1]', 'bigint') AS [Record Time] ,
        tme.ms_ticks AS [Current Time] ,
		CAST(record AS XML) AS XML_Record
FROM    sys.dm_os_ring_buffers rbf
        CROSS JOIN sys.dm_os_sys_info tme
        CROSS JOIN sys.sysmessages msg
WHERE   rbf.ring_buffer_type = 'RING_BUFFER_EXCEPTION' --and cast(record as xml).value('(//SPID)[1]', 'int') <> 0 in (122,90,161,179)
        AND msg.error = CAST(record AS XML).value('(//Exception//Error)[1]','varchar(500)')
        AND msg.msglangid = 1033
		-- Specify a certain error number to seach.
        --AND [Error] = 4002
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Resource Ring Buffer.

SELECT  CONVERT (VARCHAR(30), GETDATE(), 121) AS [RunTime] ,
        DATEADD(ms, ( rbf.[timestamp] - tme.ms_ticks ), GETDATE()) AS [Notification_Time] ,
        CAST(record AS XML).value('(//Record/ResourceMonitor/Notification)[1]','varchar(30)') AS [Notification_type] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/MemoryUtilization)[1]','bigint') AS [MemoryUtilization %] ,
        CAST(record AS XML).value('(//Record/MemoryNode/@id)[1]', 'bigint') AS [Node Id] ,
        CAST(record AS XML).value('(//Record/ResourceMonitor/IndicatorsProcess)[1]','int') AS [Process_Indicator] ,
        CAST(record AS XML).value('(//Record/ResourceMonitor/IndicatorsSystem)[1]','int') AS [System_Indicator] ,
        CAST(record AS XML).value('(//Record/MemoryNode/ReservedMemory)[1]','bigint') AS [SQL_ReservedMemory_KB] ,
        CAST(record AS XML).value('(//Record/MemoryNode/CommittedMemory)[1]','bigint') AS [SQL_CommittedMemory_KB] ,
        CAST(record AS XML).value('(//Record/MemoryNode/AWEMemory)[1]','bigint') AS [SQL_AWEMemory] ,
        CAST(record AS XML).value('(//Record/MemoryNode/SinglePagesMemory)[1]','bigint') AS [SinglePagesMemory] ,
        CAST(record AS XML).value('(//Record/MemoryNode/MultiplePagesMemory)[1]','bigint') AS [MultiplePagesMemory] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/TotalPhysicalMemory)[1]','bigint') AS [TotalPhysicalMemory_KB] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/AvailablePhysicalMemory)[1]','bigint') AS [AvailablePhysicalMemory_KB] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/TotalPageFile)[1]','bigint') AS [TotalPageFile_KB] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/AvailablePageFile)[1]','bigint') AS [AvailablePageFile_KB] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/TotalVirtualAddressSpace)[1]','bigint') AS [TotalVirtualAddressSpace_KB] ,
        CAST(record AS XML).value('(//Record/MemoryRecord/AvailableVirtualAddressSpace)[1]','bigint') AS [AvailableVirtualAddressSpace_KB] ,
        CAST(record AS XML).value('(//Record/@id)[1]', 'bigint') AS [Record Id] ,
        CAST(record AS XML).value('(//Record/@type)[1]', 'varchar(30)') AS [Type] ,
        CAST(record AS XML).value('(//Record/@time)[1]', 'bigint') AS [Record Time] ,
        tme.ms_ticks AS [Current Time]
FROM    sys.dm_os_ring_buffers rbf
        CROSS JOIN sys.dm_os_sys_info tme
WHERE   rbf.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR' 
and cast(record as xml).value('(//Record/ResourceMonitor/Notification)[1]', 'varchar(30)') = 'RESOURCE_MEMPHYSICAL_LOW'
ORDER BY 2 DESC
GO

------------------------------------------------------------------------------------------------------------------------------------------------
-- Memory Info.
		

WITH    RingBuffer
        AS (SELECT    CAST(dorb.record AS XML) AS xRecord
                    ,dorb.timestamp
            FROM      sys.dm_os_ring_buffers AS dorb
            WHERE     dorb.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
            )
SELECT  xr.value('(ResourceMonitor/Notification)[1]', 'varchar(75)') AS RmNotification
        ,xr.value('(ResourceMonitor/IndicatorsProcess)[1]', 'tinyint') AS IndicatorsProcess
        ,xr.value('(ResourceMonitor/IndicatorsSystem)[1]', 'tinyint') AS IndicatorsSystem
        ,DATEADD(ms, -1 * dosi.ms_ticks - rb.timestamp, GETDATE()) AS RmDateTime
FROM    RingBuffer AS rb
        CROSS APPLY rb.xRecord.nodes('Record') record (xr)
        CROSS JOIN sys.dm_os_sys_info AS dosi
ORDER BY RmDateTime DESC;


/*
This query shows the basic information available from the DMO and shows off one additional piece of information embedded in the results, 
the actual date and time derived from the timestamp value. If all you’re interested in is the fact of the memory issue, you can stop here. 
But if you’re interested in a little diagnostic work on top of this, you’re going to want to pull the rest of the memory information that’s 
available like this:
*/

WITH    RingBuffer
          AS (SELECT    CAST(dorb.record AS XML) AS xRecord
                       ,dorb.timestamp
              FROM      sys.dm_os_ring_buffers AS dorb
              WHERE     dorb.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
             )
SELECT  xr.value('(ResourceMonitor/Notification)[1]', 'varchar(75)') AS RmNotification
        ,xr.value('(ResourceMonitor/IndicatorsProcess)[1]', 'tinyint') AS IndicatorsProcess
        ,xr.value('(ResourceMonitor/IndicatorsSystem)[1]', 'tinyint') AS IndicatorsSystem
        ,DATEADD(ms, -1 * dosi.ms_ticks - rb.timestamp, GETDATE()) AS RmDateTime
        ,xr.value('(MemoryNode/TargetMemory)[1]', 'bigint') AS TargetMemory
        ,xr.value('(MemoryNode/ReserveMemory)[1]', 'bigint') AS ReserveMemory
        ,xr.value('(MemoryNode/CommittedMemory)[1]', 'bigint') AS CommitedMemory
        ,xr.value('(MemoryNode/SharedMemory)[1]', 'bigint') AS SharedMemory
        ,xr.value('(MemoryNode/PagesMemory)[1]', 'bigint') AS PagesMemory
        ,xr.value('(MemoryRecord/MemoryUtilization)[1]', 'bigint') AS MemoryUtilization
        ,xr.value('(MemoryRecord/TotalPhysicalMemory)[1]', 'bigint') AS TotalPhysicalMemory
        ,xr.value('(MemoryRecord/AvailablePhysicalMemory)[1]', 'bigint') AS AvailablePhysicalMemory
        ,xr.value('(MemoryRecord/TotalPageFile)[1]', 'bigint') AS TotalPageFile
        ,xr.value('(MemoryRecord/AvailablePageFile)[1]', 'bigint') AS AvailablePageFile
        ,xr.value('(MemoryRecord/TotalVirtualAddressSpace)[1]', 'bigint') AS TotalVirtualAddressSpace
        ,xr.value('(MemoryRecord/AvailableVirtualAddressSpace)[1]',
                    'bigint') AS AvailableVirtualAddressSpace
        ,xr.value('(MemoryRecord/AvailableExtendedVirtualAddressSpace)[1]',
                    'bigint') AS AvailableExtendedVirtualAddressSpace
FROM    RingBuffer AS rb
        CROSS APPLY rb.xRecord.nodes('Record') record (xr)
        CROSS JOIN sys.dm_os_sys_info AS dosi
ORDER BY RmDateTime DESC;