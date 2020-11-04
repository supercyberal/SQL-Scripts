/***********************************************************************************************************************************************
Description:	Get AlwaysOn Availability Groups status info.

Notes:			ACOSTA - 2014-04-02
				Created.
***********************************************************************************************************************************************/

-- Ger active replica from Listener/Cluster.
SELECT @@SERVERNAME

-- Get cluster info.
SELECT * FROM sys.dm_hadr_cluster

-- Get quorum info.
SELECT * FROM sys.dm_hadr_cluster_members

-- Get IP info.
SELECT * FROM sys.dm_hadr_cluster_networks

SELECT  *
FROM    sys.availability_groups_cluster

SELECT  *
FROM    sys.dm_hadr_availability_group_states

SELECT  *
FROM    sys.availability_replicas

SELECT  *
FROM    sys.dm_hadr_availability_replica_cluster_nodes

SELECT  *
FROM    sys.dm_hadr_availability_replica_cluster_states

SELECT  *
FROM    sys.dm_hadr_availability_replica_states

--SELECT  *
--FROM    sys.dm_hadr_auto_page_repair

SELECT  *
FROM    sys.dm_hadr_database_replica_states

SELECT  *
FROM    sys.dm_hadr_database_replica_cluster_states
SELECT  *
FROM    sys.availability_group_listener_ip_addresses
SELECT  *
FROM    sys.availability_group_listeners
SELECT  *
FROM    sys.dm_tcp_listener_states