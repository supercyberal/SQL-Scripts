SET NOCOUNT On;
GO
print'===================================================='
print'==================@@SERVERNAME======================'
select @@SERVERNAME
print'===================@@VERSION========================'
select @@VERSION
print'===================   Server Info   ========================'
select 
cpu_count as "Logical CPU",
physical_memory_kb/1024 as "RAM in MB",
scheduler_count as "Logical Schedulers",
scheduler_total_count-scheduler_count as "Other Schedulers",
affinity_type_desc,
virtual_machine_type_desc,
case when cpu_count = hyperthread_ratio then 'No' else 'Yes' end as "Is_Hyperthreading_On"
from sys.dm_os_sys_info
print'========================================================='
print'===================MSInfo32========================'
go
xp_msver
go
print'===================SP_Configure========================'
go
sp_configure 'show advanced options',1
go
reconfigure
go
sp_configure 
go
print'===================Cluster_Nodes========================'
SELECT * FROM sys.dm_os_cluster_nodes 
go
print'===================CurrentNodeName========================'
SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS [CurrentNodeName] 
Go
print'===================OS_sys_info========================'
SELECT sqlserver_start_time FROM sys.dm_os_sys_info
print'===================SP_Helpdb========================'
Go
Sp_helpdb
go
print'===================Loaded Modules========================'
select * from sys.dm_os_loaded_modules where company not like '%Microsoft Corporation%'
print'========================================================='
print'=======================END================================'
SET NOCOUNT OFF;
GO