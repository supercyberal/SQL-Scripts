----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 0 - Search queries.

DECLARE @tblTables TABLE (
	TableName nvarchar(256)
)
insert INTO @tblTables(TableName) VALUES ('')


SELECT * FROM 
(
	SELECT 
		deqs.last_execution_time AS [Time]
		, dest.TEXT AS [Query]
		, deqs.*
		, deqp.query_plan
	FROM sys.dm_exec_query_stats AS deqs
	CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest
	CROSS APPLY sys.dm_exec_query_plan(deqs.plan_handle) AS deqp 

	--Get execution time.
	--WHERE deqs.last_execution_time BETWEEN '2013-05-23 13:20' AND '2013-05-23 13:30'

	--AND dest.TEXT like '%UNCOM%'
) a
JOIN @tblTables t ON a.[Query] LIKE '%' + t.TableName + '%'
ORDER BY a.last_execution_time DESC

----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 0.5 - Search queries.

SELECT  
     query_plan AS CompleteQueryPlan, 
     n.value('(@StatementText)[1]', 'VARCHAR(4000)') AS StatementText, 
     n.value('(@StatementOptmLevel)[1]', 'VARCHAR(25)') AS StatementOptimizationLevel, 
     n.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)') AS StatementSubTreeCost, 
     n.query('.') AS ParallelSubTreeXML,  
     ecp.usecounts, 
     ecp.size_in_bytes 
FROM sys.dm_exec_cached_plans AS ecp 
CROSS APPLY sys.dm_exec_query_plan(plan_handle) AS eqp 
CROSS APPLY query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') AS qn(n) 
WHERE n.value('(@StatementText)[1]', 'VARCHAR(4000)') 
    LIKE '%spGetNames%' -- Alter the search text to find your stored proc here

----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 0.6 - Search queries by query hash or query plan hash

SELECT
	[dest].[text] AS Query
	, DB_NAME([eqp].[dbid]) AS DBName
	, [eqp].[query_plan]
	, [deqs].*
FROM [sys].[dm_exec_query_stats] AS [deqs]
CROSS APPLY sys.dm_exec_sql_text(deqs.[sql_handle]) AS dest
CROSS APPLY sys.dm_exec_query_plan([deqs].[plan_handle]) AS eqp 
WHERE [deqs].[query_hash] = 0x0
OR [deqs].[query_plan_hash] = 0x0

----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 1 - Timeout Plan

WITH XMLNAMESPACES(DEFAULT N'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),  QueryPlans 
AS  ( 
SELECT  RelOp.pln.value(N'@StatementOptmEarlyAbortReason', N'varchar(50)') AS TerminationReason, 
        RelOp.pln.value(N'@StatementOptmLevel', N'varchar(50)') AS OptimizationLevel, 
        --dest.text, 
        SUBSTRING(dest.text, (deqs.statement_start_offset / 2) + 1, 
                  (deqs.statement_end_offset - deqs.statement_start_offset) 
                  / 2 + 1) AS StatementText, 
        deqp.query_plan, 
        deqp.dbid, 
        deqs.execution_count, 
        deqs.total_elapsed_time, 
        deqs.total_logical_reads, 
        deqs.total_logical_writes 
FROM    sys.dm_exec_query_stats AS deqs 
        CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest 
        CROSS APPLY sys.dm_exec_query_plan(deqs.plan_handle) AS deqp 
        CROSS APPLY deqp.query_plan.nodes(N'//StmtSimple') RelOp (pln) 
WHERE   deqs.statement_end_offset > -1        
)   
SELECT  DB_NAME(qp.dbid), 
        * 
FROM    QueryPlans AS qp 
WHERE   qp.TerminationReason = 'Timeout'
ORDER BY qp.execution_count DESC ;

----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 2 - Timeout Plan

SELECT  DB_NAME(deqp.dbid), 
        SUBSTRING(dest.text, (deqs.statement_start_offset / 2) + 1, 
                  (CASE deqs.statement_end_offset 
                     WHEN -1 THEN DATALENGTH(dest.text) 
                     ELSE deqs.statement_end_offset 
                   END - deqs.statement_start_offset) / 2 + 1) AS StatementText, 
        deqs.statement_end_offset, 
        deqs.statement_start_offset, 
        deqp.query_plan, 
        deqs.execution_count, 
        deqs.total_elapsed_time, 
        deqs.total_logical_reads, 
        deqs.total_logical_writes 
FROM    sys.dm_exec_query_stats AS deqs 
        CROSS APPLY sys.dm_exec_query_plan(deqs.plan_handle) AS deqp 
        CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest 
WHERE   CAST(deqp.query_plan AS NVARCHAR(MAX)) LIKE '%StatementOptmEarlyAbortReason="TimeOut"%';

----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 3 - Timeout

SELECT  DB_NAME(detqp.dbid), 
        SUBSTRING(dest.text, (deqs.statement_start_offset / 2) + 1, 
                  (CASE deqs.statement_end_offset 
                     WHEN -1 THEN DATALENGTH(dest.text) 
                     ELSE deqs.statement_end_offset 
                   END - deqs.statement_start_offset) / 2 + 1) AS StatementText, 
        CAST(detqp.query_plan AS XML), 
        deqs.execution_count, 
        deqs.total_elapsed_time, 
        deqs.total_logical_reads, 
        deqs.total_logical_writes 
FROM    sys.dm_exec_query_stats AS deqs 
        CROSS APPLY sys.dm_exec_text_query_plan(deqs.plan_handle, 
                                                deqs.statement_start_offset, 
                                                deqs.statement_end_offset) AS detqp 
        CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest 
WHERE   detqp.query_plan LIKE '%StatementOptmEarlyAbortReason="TimeOut"%';

----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 4 - Most consuming queries.

SELECT TOP 10   
   qs.execution_count,
   (qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) AS [Total IO], 
   (qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) /qs.execution_count AS [Avg IO],       
   AvgPhysicalReads  = isnull( qs.total_physical_reads/ qs.execution_count, 0 ),  
   MinPhysicalReads  = qs.min_physical_reads,  
   MaxPhysicalReads  = qs.max_physical_reads,  
   AvgPhysicalReads_kbsize  = isnull( qs.total_physical_reads/ qs.execution_count, 0 ) *8,  
   MinPhysicalReads_kbsize  = qs.min_physical_reads*8,  
   MaxPhysicalReads_kbsize  = qs.max_physical_reads*8,  
   CreationDateTime = qs.creation_time,  
   SUBSTRING(qt.[text], qs.statement_start_offset/2, (   
       CASE    
           WHEN qs.statement_end_offset = -1 THEN LEN(CONVERT(NVARCHAR(MAX), qt.[text])) * 2    
           ELSE qs.statement_end_offset    
       END - qs.statement_start_offset)/2    
   ) AS query_text,   
   qt.[dbid],   
   qt.objectid,   
   tp.query_plan,  
   tp.query_plan.exist('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan";  
/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple/QueryPlan/MissingIndexes') missing_index_info  
FROM    
   sys.dm_exec_query_stats qs   
   CROSS APPLY sys.dm_exec_sql_text (qs.[sql_handle]) AS qt   
   OUTER APPLY sys.dm_exec_query_plan(qs.plan_handle) tp   
WHERE DB_NAME([qt].[dbid]) = '<SOME-DB-NAME>'
ORDER BY AvgPhysicalReads DESC  


----------------------------------------------------------------------------------------------------------------------------------------------
-- Version 5 - Plan cache info.

SELECT 
	DatabaseName=db_name(qrytxt.dbid), 
	ObjectName=Object_Name(qrytxt.objectid),
	qrytxt.text, 
	qryplan.query_plan,
	cacheobjtype, 
	usecounts,
	objtype,
	[cp].[size_in_bytes]
FROM sys.dm_exec_cached_plans cp
OUTER APPLY sys.dm_exec_sql_text(cp.plan_handle) qrytxt
OUTER APPLY sys.dm_exec_query_plan(cp.plan_handle) qryplan
--WHERE objtype='<Oject_Type>'

SELECT  cp.objtype AS ObjectType
       ,OBJECT_NAME(st.objectid, st.dbid) AS ObjectName
       ,cp.usecounts AS ExecutionCount
       ,st.TEXT AS QueryText
       ,qp.query_plan AS QueryPlan
FROM    sys.dm_exec_cached_plans AS cp
        CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) AS qp
        CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) AS st

;WITH ctePlanCache AS (
	SELECT 
		DatabaseName=db_name(qrytxt.dbid), 
		ObjectName=Object_Name(qrytxt.objectid),
		qrytxt.dbid,
		qrytxt.objectid,
		qrytxt.text, 
		qryplan.query_plan,
		cacheobjtype, 
		objtype,
		[cp].[size_in_bytes]
	FROM sys.dm_exec_cached_plans cp
	CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) qrytxt
	CROSS APPLY sys.dm_exec_query_plan(cp.plan_handle) qryplan
)
SELECT * FROM [ctePlanCache] cte
ORDER BY [DatabaseName]

COMPUTE SUM([cte].[size_in_bytes])

----------------------------------------------------------------------------------------------------------------------------------------------
-- Check for plan generations.

SELECT  [qs].[plan_generation_num]
       ,[qs].[execution_count]
       ,DB_NAME([st].[dbid]) AS [DbName]
       ,[st].[objectid]
       ,[st].[text]
FROM    [sys].[dm_exec_query_stats] [qs]
        CROSS APPLY [sys].[dm_exec_sql_text]([qs].[sql_handle]) AS [st]
ORDER BY [qs].[plan_generation_num] DESC;

----------------------------------------------------------------------------------------------------------------------------------------------
-- Check for types of plans cached.

SELECT  [objtype]
       ,COUNT(*) AS [number_of_plans]
       ,SUM(CAST([size_in_bytes] AS BIGINT)) / 1024 / 1024 AS [size_in_MBs]
       ,AVG([usecounts]) AS [avg_use_count]
FROM    [sys].[dm_exec_cached_plans]
GROUP BY [objtype];