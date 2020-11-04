/***********************************************************************************************************************************************
Script to determine what statistics are being used for a certain query.
***********************************************************************************************************************************************/

SELECT * FROM [Table]
OPTION
(
    RECOMPILE
	, QUERYTRACEON 3604 --> Print results to the query message window.
    , QUERYTRACEON 9292 --> Reports about statistics objects considered as interesting by query optimizer during compilation or recompilation of query.
    , QUERYTRACEON 9204 --> Reports about statistics objects which are fully loaded and used by the optimizer for cardinality estimation.
	--, QUERYTRACEON 9130 --> Reveals hidden predicates.
	
)