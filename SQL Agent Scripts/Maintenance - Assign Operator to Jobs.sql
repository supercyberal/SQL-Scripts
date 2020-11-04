/*
Name:	Assign DBA operator to jobs
Date:	2013-04-12
*/

-- Find out jobs without alert operators.
SELECT  [name] ,
        [date_created] ,
        [enabled]
FROM    msdb.dbo.sysjobs
WHERE   [enabled] = 1
		AND [notify_level_email] = 0;
GO

-- Find active operator.
SELECT  [id] ,
        [name] ,
        [enabled]
FROM    msdb.dbo.sysoperators
WHERE   [enabled] = 1
ORDER BY [name];
GO

-- Find if DBMail is setup is started.
EXEC msdb.dbo.sysmail_help_status_sp;

-- Update jobs with operators.
DECLARE @iOpId INT

SELECT  @iOpId = [id]
FROM    msdb.dbo.sysoperators
WHERE   [enabled] = 1
AND name = 'IT-Databases';

UPDATE  s
SET     s.[notify_level_email] = 2 ,
		-- Paste the ID of the operator.
        s.[notify_email_operator_id] = @iOpId
FROM    msdb.dbo.sysjobs s
WHERE   s.[notify_level_email] = 0
        AND s.[enabled] = 1;
GO