/*
Name:	Get audit info from the default trace.
Date:	2013-04-23
*/

DECLARE @TrcPath NVARCHAR(260);

SELECT 
	@TrcPath = path
FROM sys.traces
WHERE id = 1

SELECT *
FROM fn_trace_gettable(@TrcPath, default)
WHERE StartTime > '2013-05-23 13:30'
ORDER BY StartTime DESC;