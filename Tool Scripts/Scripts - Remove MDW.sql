USE [msdb]
GO

EXEC msdb.dbo.sp_syscollector_disable_collector
GO

UPDATE [msdb].[dbo].[syscollector_collection_sets_internal] SET [collection_job_id] = NULL, [upload_job_id] = NULL
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'collection_set_1_noncached_collect_and_upload')
EXEC msdb.dbo.sp_delete_job @job_name = N'collection_set_1_noncached_collect_and_upload', @delete_unused_schedule=1
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'collection_set_2_collection')
EXEC msdb.dbo.sp_delete_job @job_name = N'collection_set_2_collection', @delete_unused_schedule=1
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'collection_set_2_upload')
EXEC msdb.dbo.sp_delete_job @job_name = N'collection_set_2_upload', @delete_unused_schedule=1
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'collection_set_3_collection')
EXEC msdb.dbo.sp_delete_job @job_name = N'collection_set_3_collection', @delete_unused_schedule=1
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'collection_set_3_upload')
EXEC msdb.dbo.sp_delete_job @job_name = N'collection_set_3_upload', @delete_unused_schedule=1
GO

UPDATE [msdb].[dbo].[syscollector_config_store_internal] SET parameter_value=NULL WHERE parameter_name='MDWDatabase'
UPDATE [msdb].[dbo].[syscollector_config_store_internal] SET parameter_value=NULL WHERE parameter_name='MDWInstance'
GO