USE msdb;
GO

SELECT j.job_id
      ,s.srvname
      ,j.name
      ,j.description
      ,js.step_id
      ,js.step_name
      ,js.command
      ,j.enabled 
      ,js.last_run_date
      ,js.last_run_time
      ,j.date_created
      ,j.date_modified
FROM  dbo.sysjobs j
JOIN  dbo.sysjobsteps js
      ON    js.job_id = j.job_id 
JOIN  master.dbo.sysservers s
      ON    s.srvid = j.originating_server_id
WHERE js.command LIKE N'%%'
order by name, step_id
GO
