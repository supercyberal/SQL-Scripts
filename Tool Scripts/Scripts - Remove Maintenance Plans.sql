-- Find the maintenance plan name and id that you want to delete.
-- Write down the id of the one you want to delete.

SELECT name, id FROM msdb.dbo.sysmaintplan_plans

DECLARE @uPlanID UNIQUEIDENTIFIER
SET @uPlanID = NULL
 

 -- Place the id of the maintenance plan you want to delete

-- into the below query to delete the entry from the log table

DELETE FROM msdb.dbo.sysmaintplan_log WHERE plan_id = @uPlanID

 -- Place the id of the maintenance plan you want to delete

-- into the below query and delete the entry from subplans table

DELETE FROM msdb.dbo.sysmaintplan_subplans WHERE plan_id = @uPlanID

 -- Place the id of the maintenance plan you want to delete

-- into the below query to delete the entry from the plans table

DELETE FROM msdb.dbo.sysmaintplan_plans WHERE id = @uPlanID

SELECT name, id FROM msdb.dbo.sysmaintplan_plans
