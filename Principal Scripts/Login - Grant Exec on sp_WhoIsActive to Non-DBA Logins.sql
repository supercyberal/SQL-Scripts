USE [master]
GO

-- ============================================================================================================
-- Setup Certificate for sp_WhoIsActive.

CREATE CERTIFICATE WhoIsActive_Permissions 
ENCRYPTION BY PASSWORD = 'wh0!$@ctive!' 
WITH SUBJECT = 'Who is Active', 
EXPIRY_DATE = '9999-12-31' 
GO

CREATE LOGIN WhoIsActive_NonDBALogin
FROM CERTIFICATE WhoIsActive_Permissions 
GO

GRANT VIEW SERVER STATE 
TO WhoIsActive_NonDBALogin 
GO

ADD SIGNATURE TO [dbo].[sp_WhoIsActive] 
BY CERTIFICATE WhoIsActive_Permissions
WITH PASSWORD = 'wh0!$@ctive!' 
GO

-- ============================================================================================================
-- Grant Exec on sp_WhoIsActive to Non-DBA Login/Roles

GRANT EXEC ON [dbo].[sp_WhoIsActive] TO PUBLIC
GO
