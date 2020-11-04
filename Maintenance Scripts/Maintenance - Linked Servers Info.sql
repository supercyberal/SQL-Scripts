/*
Name:	Extract linked server's info.
Date:	2013-04-12
*/

SELECT  ss.server_id ,
        ss.name ,
        'Server ' = CASE ss.Server_id
                      WHEN 0 THEN 'Current Server'
                      ELSE 'Remote Server'
                    END ,
        ss.product ,
        ss.provider ,
        ss.catalog ,
        'Local Login ' = CASE sl.uses_self_credential
                           WHEN 1 THEN 'Uses Self Credentials'
                           ELSE ssp.name
                         END ,
        'Remote Login Name' = sl.remote_name ,
        'RPC Out Enabled' = CASE ss.is_rpc_out_enabled
                              WHEN 1 THEN 'True'
                              ELSE 'False'
                            END ,
        'Data Access Enabled' = CASE ss.is_data_access_enabled
                                  WHEN 1 THEN 'True'
                                  ELSE 'False'
                                END ,
        ss.modify_date
FROM    sys.servers ss
        LEFT JOIN sys.linked_logins sl ON ss.server_id = sl.server_id
        LEFT JOIN sys.server_principals ssp ON ssp.principal_id = sl.local_principal_id