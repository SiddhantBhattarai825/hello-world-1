CREATE TABLE [SBSC].[AssignmentOccasions] (
  [Id] [int] IDENTITY,
  [FromDate] [date] NULL,
  [ToDate] [date] NULL,
  [AssignedTime] [datetime] NULL,
  [CustomerId] [int] NULL,
  [Status] [smallint] NULL,
  [LastUpdatedDate] [datetime] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_AssignmentOccasions_Customer]
  ON [SBSC].[AssignmentOccasions] ([CustomerId], [Id])
GO

CREATE INDEX [IX_AssignmentOccasions_CustomerId_Status_LastUpdated]
  ON [SBSC].[AssignmentOccasions] ([CustomerId], [Status])
  INCLUDE ([Id], [FromDate], [ToDate], [AssignedTime], [LastUpdatedDate])
GO