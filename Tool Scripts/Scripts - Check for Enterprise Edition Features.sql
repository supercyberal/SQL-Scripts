:CONNECT [YOUR-SQLINSTANCE-HERE]

USE [master]
GO

SELECT @@VERSION

DECLARE
    @cSQLStmt NVARCHAR(512);

SET @cSQLStmt = '
USE [?]

    SELECT
	   SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS ComputerName
	   , DB_NAME() AS DBName 
	   , ef.*
    FROM [sys].[dm_db_persisted_sku_features] ef;
';

IF OBJECT_ID('master..sp_foreachdb') IS NOT NULL
    EXEC [dbo].[sp_foreachdb] @command = @cSQLStmt, @print_dbname = 1;
ELSE   
    EXEC [sys].[sp_MSforeachdb] @command1 = @cSQLStmt;
GO


    
