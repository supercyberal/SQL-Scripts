CREATE TABLE [dbo].[Servers](
[instance_name] [nvarchar](128) NOT NULL,
[instance_name_short] [nvarchar](128) NOT NULL,
[server_name] [nvarchar](128) NOT NULL,
[server_name_short] [nvarchar](128) NOT NULL,
[Environment] [varchar](7) NOT NULL,
CONSTRAINT [PK_Server_Instance] PRIMARY KEY CLUSTERED
(
[instance_name_short] ASC
)
) ON [DataPrimary]
 
GO
 
CREATE SCHEMA [Server]
GO
 
CREATE TABLE [Server].[PhysicalNodes](
[Server_Name] [nvarchar](128) NOT NULL,
[Node_Name] [nvarchar](128) NOT NULL
) ON [DataPrimary]
 
GO
 
CREATE TABLE [Server].[System_Info](
[Server_Name] [nvarchar](128) NOT NULL,
[Model] [varchar](200) NULL,
[Manufacturer] [varchar](50) NULL,
[Description] [varchar](100) NULL,
[DNSHostName] [varchar](30) NULL,
[Domain] [varchar](30) NULL,
[DomainRole] [smallint] NULL,
[PartOfDomain] [varchar](5) NULL,
[NumberOfProcessors] [smallint] NULL,
[NumberOfCores] [smallint] NULL,
[SystemType] [varchar](50) NULL,
[TotalPhysicalMemory] [bigint] NULL,
[UserName] [varchar](50) NULL,
[Workgroup] [varchar](50) NULL,
CONSTRAINT [PK_Server_Name] PRIMARY KEY CLUSTERED
(
[Server_Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DataPrimary]
) ON [DataPrimary]
 
GO
 
CREATE TABLE [Server].[Memory_Info](
[Server_Name] [nvarchar](128) NOT NULL,
[Name] [varchar](50) NULL,
[Capacity] [bigint] NULL,
[DeviceLocator] [varchar](20) NULL,
[Tag] [varchar](50) NULL
) ON [DataPrimary]
 
GO
 
CREATE TABLE [Server].[OS_Info](
[Server_Name] [nvarchar](128) NOT NULL,
[OSName] [varchar](200) NULL,
[OSVersion] [varchar](20) NULL,
[OSLanguage] [varchar](5) NULL,
[OSProductSuite] [varchar](5) NULL,
[OSType] [varchar](5) NULL,
[ServicePackMajorVersion] [smallint] NULL,
[ServicePackMinorVersion] [smallint] NULL
) ON [DataPrimary]
 
GO
 
CREATE TABLE [Server].[Disk_Info](
[Server_Name] [nvarchar](128) NOT NULL,
[Disk_Name] [varchar](50) NULL,
[Label] [varchar](50) NULL,
[DriveLetter] [varchar](5) NULL,
[Capacity] [bigint] NULL,
[FreeSpace] [bigint] NULL,
[Run_Date] [date] NULL
) ON [DataPrimary]
 
GO