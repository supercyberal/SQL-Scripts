/*******************************************
SERVER INFO: AM1ITDB001\APPDATA

REPORT LINE: 143
*******************************************/

USE [WhiteCaseDBInventory]
GO

/*
-- =============================================================================================================================================
-- START - PREPPING INFO - FOR INVENTORY UPDATE ON VISUAL STUDIO PROJECT
-- =============================================================================================================================================

-- 1. - LOAD MAPS INFO FROM EXCEL FILE TABS INTO STAGING SQLEngine AND SQLComponents STAGING TABLES.

==> Column Replace Info for Excel

-- DatabaseInstances Tab
Srv_Name	SQL_Inst_Name	SQL_Prod_Name	SQL_ver	SQL_SP	SQL_Ed	Clustered	Clust_Name	SQLSvcState	SQLSvcStartMode	Language	SQLSubDir	Curr_OS	OS_SP	OS_Arch_Type	Num_Procs	Num_Cores	Num_Lg_Cores	CPU	Mem	Log_Drives	Log_DiskSize_GB	Log_DiskSize_Free_Sapce_GB	Machine_Type

-- Components Tab
Srv_Name	Srv_Comp_Name	Srv_Comp_Ver	Srv_Comp_SP	Srv_Comp_Edition	Curr_OS	OS_SP	OS_Arch_Type	Num_Procs	Num_Cores	Num_Lg_Cores	CPU	Mem	Log_Drives	Log_DiskSize_GB	Log_DiskSize_Free_Sapce_GB

-- DatabaseSummary Tab
Srv_Name	SQL_Inst_Name	SQL_Prod_Name	DBName	DBSize_MB	DataFilesSize_MB	LogFilesSize_MB	LogFilesUsedSize_MB	LogFilesUsedSize_Pct	SQLConn	CompLevel	Status	Owner	CreateTimeStamp	LastBackupTimeStamp	NumTables	NumViews	NumProcs	NumFuncs	DataFileNames	FileGroups	FileSizes	MaxFileSize	FileGrowth	FileUsage

------------------------------------------------------------------------------------------------------------------------------------------------
-- 2. CHECK STAGING TABLES.

-- Check SAS tables.
SELECT * FROM [Staging].[SASCatalogAppOwners];
SELECT * FROM [Staging].[SASCatalogGlobalServers];

-- Check DB and Comp staging tables.
SELECT * FROM [Staging].[SQLEngine];
SELECT * FROM [Staging].[SQLComponents];

-- Check DB details staging table.
SELECT * FROM [Staging].[SQLDatabaseDetails];

-- Check server builds staging tables.
SELECT * FROM [Staging].[ServerBuilds];
SELECT * FROM [Staging].[ServerCompBuilds];

------------------------------------------------------------------------------------------------------------------------------------------------
-- 3. - LOAD SQLENGINE DATA - (Output generated is for all new and updated servers).

EXEC [Staging].[spLoadDBEngineData];

------------------------------------------------------------------------------------------------------------------------------------------------
-- 4. - LOAD SQLCOMPONENTS DATA

EXEC [Staging].[spLoadDBComponentsData];

------------------------------------------------------------------------------------------------------------------------------------------------
-- 5. - LOAD SASCATALOG APPINFO DATA

EXEC [Staging].[spLoadSASAppData];

------------------------------------------------------------------------------------------------------------------------------------------------
-- 6. - LOAD SQLDBDETAILS DATA

EXEC [Staging].[spLoadDBDetailsData];


-- =============================================================================================================================================
-- END - PREPPING INFO
-- =============================================================================================================================================
*/
GO

-- =============================================================================================================================================
-- Get SQL report.

EXEC [dbo].[spGetDBInventory] @cMachineNameList = '',									-- ==> Many Patterns: %6__,  am1[a-bd-z]%, am1HR__[8-9]__,  am1____[0-6]__, _______[0-7]__
                              @bActive = 1,												-- True of False of NULL for all status.
                              @cClusterNameList = '',									-- Cluster names to search
                              @cLocation = '',											-- Where do these live: AM, EM, AP
                              @cDBName = N'',											-- Which DB servers have this DB name.
                              @cVersion = N'',											-- SQL build number to search
                              @dCreateDate = NULL,										-- Date for when machines were added to W&C inventory
                              @cSQLServiceState = NULL,									-- SQL Server service status
                              @bClustered = NULL,										-- Is this machine in a WSFC cluster
                              @cProductName = '',										-- Parts of SQL Server product name to search
                              @cServerTypeList = 'Dev,QA,Prod',							-- List of Server Types to evaluate. Production,Dev,QA, etc.
                              @cEditionList = 'Ent,Stan,Unk',	-- List of editions to search. Use NULL for all types.
							  --@cEditionList = NULL,	-- List of editions to search. Use NULL for all types.
                              @cPatchingGroupList = '',									-- Which patchin group does my server belong to
                              @bIncComp = 1,											-- Should we search DB components
                              @bGetMachineNameOnly = 0,									-- Distinc List of MachineName for DBEngine and DBComponents
							  @bGetConnNameOnly = 0,									-- Distinc List of MachineName and Conn for DBEngine only
                              @bGetCombinedEngineComponentMachineNameOnly = 0,			-- Union List of DBEngine and DBComponents
                              @bGetComponetsWithoutDBServers = 1,						-- To only bring componets that DO NOT have an associated SQL engine.
                              @bGetReportForXLS = 1,									-- Output for SQL Report Spreadsheet
                              @bExcludeBypassedServers = 0,								-- Do I remove bypassed servers from my result set
                              @bOnlyNeededPatchingServers = 0,							-- Only include servers that require patching.
                              @bExecQueries = 1											-- Do we need to execute this
GO

-- =============================================================================================================================================
-- Changes DB info.

DECLARE @bEditMachineDetails BIT = 0;

IF @bEditMachineDetails = 1
BEGIN
	DECLARE @MachineInfo MachineEdit;

	INSERT @MachineInfo
	(
		[MachineName],
		[InstanceName],
		[Active],
		[MachineNotes],
		[ByPassLicense]
	)
	VALUES
	(   'AM1APWB900',   -- MachineName - varchar(64)
		'MSSQLSERVER',   -- InstanceName - varchar(64)
		0, -- Active - bit

		-- Examples for notes to change.
		'Server Decommissioned.',   -- MachineNotes - varchar(max)
		--'SSIS uninstalled.',
		--'This is for <APP NAME>. Not accounted for SQL license.'
		--'This is a DR server and therefore we dont need to count for licensing.'

		NULL  -- ByPassLicense - bit
	);

	EXEC [dbo].[spEditMachineDetails] @tblMachineDetails = @MachineInfo;    
END
GO

-- =============================================================================================================================================
-- GET LICENSE REPORT (License Count and SAS Catalog).

DECLARE @bShowReport BIT = 0;

IF @bShowReport = 1
	EXEC [dbo].[spGenerateReports] @cServerType = 'Production',-- varchar(64)
								   @bGetOnlyLicensedSrvs = 1,  -- bit
								   @iAllowEntCount = 180,      -- int
								   @iAllowStdCount = 424,      -- int
								   @bGetExtraInfoReturned = 0, -- bit
								   @bReturnCount = 0;          -- bit
GO

-- =============================================================================================================================================
-- GET SERVERS NOT IN MAPS BUT STILL ACTIVE IN INVENTORY DB

DECLARE @bShowReport BIT = 0;

IF @bShowReport = 1
	EXEC [dbo].[spGetServersNotInMAPSCollection] @iIncludeLapDeskBoxes = 0;
GO