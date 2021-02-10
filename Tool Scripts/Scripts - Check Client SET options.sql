/*
Author: Tim Cartwright
Purpose: Allows you to check the server, and client SET options
https://docs.microsoft.com/en-us/sql/database-engine/configure-windows/configure-the-user-options-server-configuration-option?view=sql-server-2017
1 DISABLE_DEF_CNST_CHK Controls interim or deferred constraint checking.
2 IMPLICIT_TRANSACTIONS For dblib network library connections, controls whether a transaction is started implicitly when a statement is executed. The IMPLICIT_TRANSACTIONS setting has no effect on ODBC or OLEDB connections.
4 CURSOR_CLOSE_ON_COMMIT Controls behavior of cursors after a commit operation has been performed.
8 ANSI_WARNINGS Controls truncation and NULL in aggregate warnings.
16 ANSI_PADDING Controls padding of fixed-length variables.
32 ANSI_NULLS Controls NULL handling when using equality operators.
64 ARITHABORT Terminates a query when an overflow or divide-by-zero error occurs during query execution.
128 ARITHIGNORE Returns NULL when an overflow or divide-by-zero error occurs during a query.
256 QUOTED_IDENTIFIER Differentiates between single and double quotation marks when evaluating an expression.
512 NOCOUNT Turns off the message returned at the end of each statement that states how many rows were affected.
1024 ANSI_NULL_DFLT_ON Alters the session's behavior to use ANSI compatibility for nullability. New columns defined without explicit nullability are defined to allow nulls.
2048 ANSI_NULL_DFLT_OFF Alters the session's behavior not to use ANSI compatibility for nullability. New columns defined without explicit nullability do not allow nulls.
4096 CONCAT_NULL_YIELDS_NULL Returns NULL when concatenating a NULL value with a string.
8192 NUMERIC_ROUNDABORT Generates an error when a loss of precision occurs in an expression.
16384 XACT_ABORT Rolls back a transaction if a Transact-SQL statement raises a run-time error.
*/
DECLARE @options TABLE ([name] nvarchar(35),
    [minimum] int,
    [maximum] int,
    [config_value] int,
    [run_value] int)
DECLARE @optionsCheck TABLE([id] int NOT NULL IDENTITY,
    [setting_name] varchar(128))
DECLARE @current_value INT;
INSERT INTO @options
    ([name], [minimum], [maximum], [config_value], [run_value])
EXEC sp_configure 'user_options';
SELECT @current_value = [config_value]
FROM @options;
--SELECT name, minimum, maximum, config_value, run_value FROM @options
--SELECT @current_value
INSERT INTO @optionsCheck
    ([setting_name])
VALUES
    ('DISABLE_DEF_CNST_CHK'),
    ('IMPLICIT_TRANSACTIONS'),
    ('CURSOR_CLOSE_ON_COMMIT'),
    ('ANSI_WARNINGS'),
    ('ANSI_PADDING'),
    ('ANSI_NULLS'),
    ('ARITHABORT'),
    ('ARITHIGNORE'),
    ('QUOTED_IDENTIFIER'),
    ('NOCOUNT'),
    ('ANSI_NULL_DFLT_ON'),
    ('ANSI_NULL_DFLT_OFF'),
    ('CONCAT_NULL_YIELDS_NULL'),
    ('NUMERIC_ROUNDABORT'),
    ('XACT_ABORT')
SELECT 
    fn.[value],
    oc.[setting_name],
    [server_option] = CASE WHEN (@current_value & fn.[value]) = fn.[value] THEN 'ON' ELSE '-'
END,
[client_option] = CASE WHEN (@@options & fn.[value]) = fn.[value] THEN 'ON' ELSE '-'
END
FROM @optionsCheck oc
CROSS APPLY
(
SELECT [value] = CASE WHEN oc.id > 1 THEN POWER(2, oc.id - 1) ELSE 1 END
)
fn;
GO

/* TEST FOR ARITHABORT ON */
DECLARE @options TABLE ([name] nvarchar(35), [minimum] int, [maximum] int, [config_value] int, [run_value] int);

INSERT INTO @options ([name], [minimum], [maximum], [config_value], [run_value])
EXEC sp_configure 'user_options';

SELECT [setting] = 'ARITHABORT ' + CASE WHEN ([config_value] & 64) = 64 THEN 'ON' ELSE 'OFF' END
FROM @options;
GO

