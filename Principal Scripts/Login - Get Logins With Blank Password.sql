/***********************************************************************************************************************************************
Description:	To list SQL logins without a password set ("Blank").
Author:			Alvaro Costa
Notes:			2016-04-20
				Created.
***********************************************************************************************************************************************/

USE [master]
GO

SELECT  SERVERPROPERTY('machinename') AS 'Server Name',
        ISNULL(SERVERPROPERTY('instancename'), SERVERPROPERTY('machinename')) AS 'Instance Name',
        [name] AS 'Login With Blank Password',
        [is_disabled],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 3
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_SysAdminMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 2
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_PublicMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 4
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_SecurityAdminMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 5
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_ServerAdminMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 6
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_SetupAdminMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 7
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_ProcessAdminMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 8
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_DiskAdminMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 9
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_DBCreaterMember],
        ISNULL(( SELECT 1
                 FROM   [sys].[server_role_members] [RM]
                        INNER JOIN [master].[sys].[server_principals] [Role] ON [RM].[role_principal_id] = [Role].[principal_id]
                                                                        AND [Role].[principal_id] = 10
                                                                        AND [RM].[member_principal_id] = [master].[sys].[sql_logins].[principal_id]
               ), 0) AS [is_BulkAdminMember]
FROM    [master].[sys].[sql_logins]
WHERE   PWDCOMPARE('', password_hash) = 1
ORDER BY [name]
OPTION  ( MAXDOP 1 );
GO