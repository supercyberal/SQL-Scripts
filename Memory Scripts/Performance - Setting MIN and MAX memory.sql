/***********************************************************************************************************************************************
Description:	Used to set a server's MAX and MIN memory specifically for Virtualization environments. The idea is using Brent Ozar's
				recommendation (http://www.brentozar.com/archive/2012/11/how-to-set-sql-server-max-memory-for-vmware/)

Notes:
ACOSTA - 2013-08-29
	Created
	
ACOSTA - 2014-02-24
	Added variable @OSMem to dynamically calculate based on passed value for reserved OS amount.

ACOSTA - 2014-06-19
	Added variable @@ServerMemPct to calculate the percentage of the server memory and decide to set the server's mem based on 4GB or 10% of
	the server total memory whichever is highest.
***********************************************************************************************************************************************/

DECLARE 
	@OSMem INT	
	, @ServerMem DECIMAL(18,2)
	, @ServerMemPct DECIMAL(18,2);

-- Set just the whole number. Ex.: 2, 4, 16..
SET @ServerMem = <SET_PHYSICAL_RAM_HERE>
SET @ServerMemPct = @ServerMem * 0.1

-- OS reserved memory
SELECT @OSMem = (
	CASE WHEN @ServerMemPct > 4 THEN
		(@ServerMemPct * 1024)
	ELSE
		4096
	END
);

-- Max Mem
SELECT CAST((@ServerMem * 1024) - @OSMem AS INT) AS Max_Mem

-- Min Mem
SELECT CAST(((@ServerMem * 1024) * .75) - @OSMem AS INT) AS Min_Mem


/***************************************************************************************

EXEC [sys].[sp_configure] @configname = 'show advanced options', -- varchar(35)
    @configvalue = 1 -- int
RECONFIGURE

EXEC [sys].[sp_configure] @configname = 'max server memory (MB)', -- varchar(35)
    @configvalue = <Max_Size_Here> -- int
RECONFIGURE

EXEC [sys].[sp_configure] @configname = 'min server memory (MB)', -- varchar(35)
    @configvalue = <Min_Size_Here> -- int
RECONFIGURE

EXEC [sys].[sp_configure] @configname = 'show advanced options', -- varchar(35)
    @configvalue = 0 -- int
RECONFIGURE

***************************************************************************************/