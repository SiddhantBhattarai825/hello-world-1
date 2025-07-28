CREATE TABLE [SBSC].[AuditLog] (
  [Id] [bigint] IDENTITY,
  [IpAddress] [nvarchar](20) NULL,
  [Action] [nvarchar](10) NULL,
  [ExecutedSpName] [nvarchar](200) NULL,
  [UpdatedDate] [datetime] NULL,
  [UpdatedBy] [bigint] NULL,
  [PageName] [nvarchar](100) NULL,
  [RowId] [bigint] NULL,
  CONSTRAINT [PK_AuditLog] PRIMARY KEY CLUSTERED ([Id])
)
GO