--------------------------------------------------------------------------------------------------------------------------------------
-- Find high parallel costs.

SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

WITH XMLNAMESPACES (
    DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
)
SELECT --TOP 100
        [a].[CompleteQueryPlan],
        [a].[StatementText],
        [a].[StatementOptimizationLevel],
        [a].[StatementSubTreeCost],
        [a].[ParallelSubTreeXML],
        [a].[usecounts],
        [a].[size_in_bytes],
        [a].[Size_MB]
FROM    (
    SELECT  [eqp].[query_plan]                                   AS CompleteQueryPlan,
            n.value( '(@StatementText)[1]', 'VARCHAR(4000)' )    AS StatementText,
            n.value( '(@StatementOptmLevel)[1]', 'VARCHAR(25)' ) AS StatementOptimizationLevel,
            n.value( '(@StatementSubTreeCost)[1]', 'FLOAT' )     AS StatementSubTreeCost,
            n.query( '.' )                                       AS ParallelSubTreeXML,
            [ecp].[usecounts],
            [ecp].[size_in_bytes],
            ( [ecp].[size_in_bytes] / 1024. / 1024. )            AS Size_MB
    FROM    [sys].[dm_exec_cached_plans]                                  AS ecp
            CROSS APPLY [sys].[dm_exec_query_plan]( [ecp].[plan_handle] ) AS eqp
            CROSS APPLY query_plan.nodes( '/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple' ) AS qn(n)
    WHERE   n.query( '.' ).exist( '//RelOp[@PhysicalOp="Parallelism"]' ) = 1
) a
ORDER BY
    --a.size_in_bytes DESC
        [a].[StatementSubTreeCost] DESC;