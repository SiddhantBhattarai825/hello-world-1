CREATE TABLE [SBSC].[ActivityLogDetail] (
  [Id] [bigint] IDENTITY,
  [ActivityLogId] [bigint] NOT NULL,
  [ColumnName] [nvarchar](100) NOT NULL,
  [OldValue] [nvarchar](max) NULL,
  [NewValue] [nvarchar](max) NULL,
  CONSTRAINT [PK_ActivityLogDetail] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[ActivityLogDetail] WITH NOCHECK
  ADD CONSTRAINT [FK_ActivityLogDetail_ActivityLog] FOREIGN KEY ([ActivityLogId]) REFERENCES [SBSC].[ActivityLog] ([Id]) ON DELETE CASCADE
GO