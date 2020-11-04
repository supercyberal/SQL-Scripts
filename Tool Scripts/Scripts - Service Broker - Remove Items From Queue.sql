/***********************************************************************************************************************************************
Description:	Responsible to remove all items from a Service Broker queue.

Notes:			ACOSTA - 2016-12-19
				Created.
***********************************************************************************************************************************************/

DECLARE @conversation_handle UNIQUEIDENTIFIER;

WHILE ( 1 = 1 )
BEGIN
    WAITFOR
	( 
		RECEIVE TOP(1)
		@conversation_handle = [conversation_handle]		
		FROM [dbo].[OlaHallengrenMaintenanceTaskQueue] -- Name of your queue.
	), TIMEOUT 5000;
 
    IF ( @@ROWCOUNT = 0 )
    BEGIN			
        BREAK;
    END;

    END CONVERSATION @conversation_handle WITH CLEANUP;
END;
