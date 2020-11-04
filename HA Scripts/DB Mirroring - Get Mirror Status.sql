/***********************************************************************************************************************************************
Description:	Get DB mirroring status info. RUN THIS IN SQLCMD MODE.

Notes:			ACOSTA - 2014-04-02
				Created.
***********************************************************************************************************************************************/

-- Run at the witness server.
:CONNECT PRI01P4ITSQL

SELECT
	[database_name]
	, [principal_server_name]
	, [mirror_server_name]
	, [safety_level_desc]
	, [role_sequence_number]
	, [is_suspended]
	, [partner_sync_state_desc]
FROM [sys].[database_mirroring_witnesses] dmwk
GO

-- Run this at the Principal/Mirror server.
:CONNECT PRI05P1SQL

SELECT  DB_NAME(database_id) AS DatabaseName
       ,CASE WHEN mirroring_guid IS NOT NULL THEN 'Mirroring is On'
             ELSE 'No mirror configured'
        END AS IsMirrorOn
       ,mirroring_state_desc
       ,CASE WHEN mirroring_safety_level = 1 THEN 'High Performance'
             WHEN mirroring_safety_level = 2 THEN 'High Safety'
             ELSE NULL
        END AS MirrorSafety
       ,mirroring_role_desc
       ,mirroring_partner_instance AS MirrorServer
FROM    sys.database_mirroring
