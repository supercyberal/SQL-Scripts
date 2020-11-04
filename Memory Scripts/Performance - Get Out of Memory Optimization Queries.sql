/***********************************************************************************************************************************************
Description:	Gets queries that couldn't have a plan generated due to out-of-memory for query plans.
				(Source: http://www.brentozar.com/blitzcache/compile-memory-limit-exceeded/)

Notes:			ACOSTA - 2014-06-09
				Created.
***********************************************************************************************************************************************/

USE [master]
GO

WITH XMLNAMESPACES('http://schemas.microsoft.com/sqlserver/2004/07/showplan' AS p)
SELECT  st.text,
        qp.query_plan
FROM    (
    SELECT  TOP 50 *
    FROM    sys.dm_exec_query_stats
    ORDER BY total_worker_time DESC
) AS qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) AS st
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) AS qp
WHERE qp.query_plan.exist('//p:StmtSimple/@StatementOptmEarlyAbortReason[.="MemoryLimitExceeded"]') = 1