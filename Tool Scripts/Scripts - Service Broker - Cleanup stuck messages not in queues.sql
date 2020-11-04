/***********************************************************************************************************************************************
Description:	Clean-up stuck Service Broker messages where they don't belong to any queue setup.
Notes:			ACOSTA - 2016-01-28
				Created.
***********************************************************************************************************************************************/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT OFF;

DECLARE 	
	@Rows INT
	, @count INT = 0
	, @handle UNIQUEIDENTIFIER;

-- Retrieve orphaned conversation handles that belong to auto-generated SqlDependency queues and iterate over each of them
DECLARE [handleCursor] CURSOR LOCAL FAST_FORWARD
FOR 
SELECT [conversation_handle]
FROM sys.conversation_endpoints
WHERE
    [far_service] COLLATE SQL_Latin1_General_CP1_CI_AS LIKE 'SqlQueryNotificationService-%' COLLATE SQL_Latin1_General_CP1_CI_AS AND
    [far_service] COLLATE SQL_Latin1_General_CP1_CI_AS NOT IN (SELECT name COLLATE SQL_Latin1_General_CP1_CI_AS FROM sys.service_queues);

SELECT @Rows = COUNT(1) FROM sys.conversation_endpoints
WHERE
    far_service COLLATE SQL_Latin1_General_CP1_CI_AS like 'SqlQueryNotificationService-%' COLLATE SQL_Latin1_General_CP1_CI_AS AND
    far_service COLLATE SQL_Latin1_General_CP1_CI_AS NOT IN (SELECT name COLLATE SQL_Latin1_General_CP1_CI_AS FROM sys.service_queues);

WHILE @Rows > 0
BEGIN
    OPEN [handleCursor];

    FETCH NEXT FROM [handleCursor]
    INTO @handle

    BEGIN TRANSACTION;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- End the conversation and clean up any remaining references to it
        END CONVERSATION @handle WITH CLEANUP;

        -- Move to the next item
        FETCH NEXT FROM handleCursor INTO @handle;
        SET @count += 1;
    END

    COMMIT TRANSACTION;
    PRINT @count

    CLOSE [handleCursor];

    IF @count > 100000    
        BREAK;

    SELECT @Rows = COUNT(1) FROM sys.conversation_endpoints
    WHERE
        far_service COLLATE SQL_Latin1_General_CP1_CI_AS like 'SqlQueryNotificationService-%' COLLATE SQL_Latin1_General_CP1_CI_AS AND
        far_service COLLATE SQL_Latin1_General_CP1_CI_AS NOT IN (SELECT name COLLATE SQL_Latin1_General_CP1_CI_AS FROM sys.service_queues)
END

DEALLOCATE [handleCursor];