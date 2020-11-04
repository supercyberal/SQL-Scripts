/*
Name:	Find Deadlocks for a server.
Date:	2013-04-12
*/

-- Get Deadlock Graph.
SELECT
     xed.value('@timestamp', 'datetime2(3)') AS CreationDate_UTC
	, CONVERT(DATETIME2, SWITCHOFFSET(CONVERT(DATETIMEOFFSET, xed.value('@timestamp', 'datetime2(3)')), DATENAME(TzOffset, SYSDATETIMEOFFSET()))) AS CreationDate_Local
     , xed.query('.') AS XEvent
FROM
(
    SELECT 
	   CAST([target_data] AS XML) AS TargetData
    FROM sys.dm_xe_session_targets AS st
    INNER JOIN sys.dm_xe_sessions AS s
	   ON s.address = st.event_session_address
    WHERE s.name = N'system_health'
    AND st.target_name = N'ring_buffer'
) AS Data
CROSS APPLY TargetData.nodes('RingBufferTarget/event[@name="xml_deadlock_report"]') AS XEventData (xed)
ORDER BY CreationDate_UTC DESC;

/*

SELECT  XEventData.XEvent.value('(data/value)[1]', 'varchar(max)') AS DeadlockGraph
FROM    ( SELECT    CAST(target_data AS XML) AS TargetData
          FROM      sys.dm_xe_session_targets st
                    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
          WHERE     name = 'system_health'
        ) AS Data
        CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData ( XEvent )
WHERE   XEventData.XEvent.value('@name', 'varchar(4000)') = 'xml_deadlock_report'



-- To get around the invalid XML problem, perform an inline replace before casting to XML as follows:
SELECT  CAST(REPLACE(REPLACE(XEventData.XEvent.value('(data/value)[1]',
                                                     'varchar(max)'),
                             '<victim-list>', '<deadlock><victim-list>'),
                     '<process-list>', '</victim-list><process-list>') AS XML) AS DeadlockGraph
FROM    ( SELECT    CAST(target_data AS XML) AS TargetData
          FROM      sys.dm_xe_session_targets st
                    JOIN sys.dm_xe_sessions s ON s.address = st.event_session_address
          WHERE     name = 'system_health'
        ) AS Data
        CROSS APPLY TargetData.nodes('//RingBufferTarget/event') AS XEventData ( XEvent )
WHERE   XEventData.XEvent.value('@name', 'varchar(4000)') = 'xml_deadlock_report'

*/

