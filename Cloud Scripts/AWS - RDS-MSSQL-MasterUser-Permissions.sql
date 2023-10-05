USE [master]
GO

-- REPLACE <UserName> WITH CORRECT USER INFO

USE [master]
GO

GRANT ALTER ANY CONNECTION, ADMINISTER BULK OPERATIONS, ALTER ANY CREDENTIAL, ALTER ANY LINKED SERVER, ALTER ANY LOGIN, ALTER SERVER STATE, ALTER TRACE, CONNECT SQL, CREATE ANY DATABASE, VIEW ANY DATABASE, VIEW ANY DEFINITION, VIEW SERVER STATE TO [<UserName>] WITH GRANT OPTION;
EXEC sp_addsrvrolemember '<UserName>', 'processadmin';
EXEC sp_addsrvrolemember '<UserName>', 'setupadmin';
GRANT ADMINISTER BULK OPERATIONS TO [<UserName>] WITH GRANT OPTION;
GRANT ALTER ANY SERVER AUDIT TO [<UserName>] WITH GRANT OPTION;
GRANT ALTER ANY CREDENTIAL TO [<UserName>] WITH GRANT OPTION;
GO

USE [msdb]
GO

GRANT EXEC ON msdb.dbo.sysmail_delete_profile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_delete_account_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_help_status_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_send_dbmail TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_delete_mailitems_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_delete_log_sp TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysmail_mailattachments TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysmail_event_log TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysmail_allitems TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysmail_sentitems TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysmail_unsentitems TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysmail_faileditems TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_help_queue_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_help_account_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_help_profile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_help_profileaccount_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_help_principalprofile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_delete_principalprofile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_sysmail_delete_mailitems_sp TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.rds_fn_sysmail_mailattachments TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.rds_fn_sysmail_event_log TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.rds_fn_sysmail_allitems TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_update_profile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_update_principalprofile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_update_profileaccount_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_drop_ssrs_databases TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_drop_ssis_database TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_failover_time TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_backup_database TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_restore_database TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_restore_log TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_finish_restore TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_cancel_task TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_task_status TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_cdc_enable_db TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_cdc_disable_db TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_shrink_tempdbfile TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_msdtc_transaction_tracing TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.rds_fn_get_audit_file TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysjobs TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysjobhistory TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.sysjobactivity TO [<UserName>] WITH GRANT OPTION;
GRANT ALTER ON ROLE::[SQLAgentOperatorRole] TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_gather_file_details TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.rds_fn_list_file_details TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_download_from_s3 TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_upload_to_s3 TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_delete_from_filesystem TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_msbi_task TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.rds_sqlagent_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_enum_login_for_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_enum_proxy_for_subsystem TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_add_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_delete_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_update_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_grant_login_to_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sp_revoke_login_from_proxy TO [<UserName>] WITH GRANT OPTION;
GRANT SELECT ON msdb.dbo.rds_fn_task_status TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_add_profile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_add_principalprofile_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_add_account_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_add_profileaccount_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_update_account_sp TO [<UserName>] WITH GRANT OPTION;
GRANT EXEC ON msdb.dbo.sysmail_delete_profileaccount_sp TO [<UserName>] WITH GRANT OPTION;
GO