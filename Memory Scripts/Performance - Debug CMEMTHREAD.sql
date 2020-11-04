/***********************************************************************************************************************************************
Description:	Debugging CMEMTHREAD waits. 
				Based on article: https://blogs.msdn.microsoft.com/psssql/2012/12/20/how-it-works-cmemthread-and-debugging-them/

Notes:			ACOSTA - 2016-06-28
				Created.
***********************************************************************************************************************************************/

SELECT  [type],
        [pages_in_bytes],
        CASE WHEN ( 0x20 = [creation_options] & 0x20 )
             THEN 'Global PMO. Cannot be partitioned by CPU/NUMA Node. TF 8048 not applicable.'
             WHEN ( 0x40 = [creation_options] & 0x40 ) THEN 'Partitioned by CPU.TF 8048 not applicable.'
             WHEN ( 0x80 = [creation_options] & 0x80 ) THEN 'Partitioned by Node. Use TF 8048 to further partition by CPU'
             ELSE 'UNKNOWN'
        END
FROM    [sys].[dm_os_memory_objects]
ORDER BY [pages_in_bytes] DESC; 
