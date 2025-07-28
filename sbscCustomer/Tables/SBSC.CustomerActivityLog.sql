CREATE TABLE [SBSC].[CustomerActivityLog] (
  [Id] [bigint] IDENTITY,
  [IpAddress] [nvarchar](45) NULL,
  [Action] [nvarchar](10) NULL,
  [EventType] [nvarchar](50) NULL,
  [ExecutedSpName] [nvarchar](200) NULL,
  [UpdatedDate] [datetime2] NOT NULL,
  [UpdatedBy] [varchar](50) NULL,
  [PageName] [nvarchar](200) NULL,
  [TableName] [nvarchar](100) NOT NULL,
  [Browser] [nvarchar](200) NULL,
  [Details] [nvarchar](max) NULL,
  [EditedByEmail] [nvarchar](256) NULL,
  [TargetEmail] [nvarchar](256) NULL,
  CONSTRAINT [PK_ActivityLog] PRIMARY KEY CLUSTERED ([Id])
)
GO