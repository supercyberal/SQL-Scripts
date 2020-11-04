/***********************************************************************************************************************************************
Description:	Creates a numbers table in the master DB.

Notes:
ACOSTA - 2013-12-05
	Created.
***********************************************************************************************************************************************/

USE master
GO

IF OBJECT_ID('Numbers') IS NOT NULL
	DROP TABLE dbo.Numbers;

CREATE TABLE dbo.Numbers (
	Num INT NOT NULL 	
	
	CONSTRAINT PK_Numbers PRIMARY KEY (Num)
)

INSERT dbo.Numbers (Num)
SELECT
	(a.Number * 256) + b.Number AS Number
FROM 
	(
		SELECT number
		FROM master..spt_values
		WHERE 
			type = 'P'
			AND number <= 255
	) a (Number),
	(
		SELECT number
		FROM master..spt_values
		WHERE 
			type = 'P'
			AND number <= 255
	) b (Number);

