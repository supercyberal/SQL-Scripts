SELECT      DISTINCT
            [s2].[name],
            [s2].[enabled],
            [s].[command],
            [s].[step_name],
            'EXEC [msdb]..[sp_update_job] @job_name = N''' + [s2].[name] + ''', @notify_level_email = 2,@notify_email_operator_name = ''WC-DBAs'';' AS [Update-Notifications],
            [s2].[notify_level_email],
            [s2].[notify_email_operator_id]
FROM        [msdb]..[sysjobsteps]  AS [s]
            JOIN [msdb]..[sysjobs] AS [s2]
                ON [s2].[job_id] = [s].[job_id]
WHERE       [s2].[enabled] = 1
            AND [s].[command] LIKE '%DatabaseBackup%'
			--AND [s].[command] LIKE '%IndexOptimize%'
			--AND [s2].[notify_email_operator_id] = 0
ORDER BY    [s2].[name];
GO