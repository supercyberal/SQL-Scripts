 /**********************************************************************************************************************************************
 Description:	Calculate VMWare CPU Ready time percentage.
				Based on KB: https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2002181

Notes:			ACOSTA - 2016-12-08
				Created
 **********************************************************************************************************************************************/
 
 DECLARE 
	@iReadyTimeSummation NUMERIC(10,2) = 0.00
	/*
	CPU ready summation value
	Realtime: 20 seconds
	Past Day: 5 minutes (300 seconds)
	Past Week: 30 minutes (1800 seconds)
	Past Month: 2 hours (7200 seconds)
	Past Year: 1 day (86400 seconds)
	*/
	, @iTimeRange INT = 20
	, @iNumCPUs INT = 00

 
 SELECT 
	-- From SQL Skills - Jonathan Kahayas
	(@iReadyTimeSummation / (@iTimeRange * 1000)) * 100. AS [CPU_Ready_Pct (SQLSkils)]
	, ((@iReadyTimeSummation / (@iTimeRange * 1000)) * 100.) / @iNumCPUs AS [CPU_Ready_Pct_ByCPUs (SQLSkills)]
	
	-- From VMWare
	, @iReadyTimeSummation / (@iTimeRange * 10) AS [CPU_Ready_Pct (VMWare)]
	, (@iReadyTimeSummation / (@iTimeRange * 10)) / @iNumCPUs AS [CPU_Ready_Pct_ByCPUs (VMWare)]





	