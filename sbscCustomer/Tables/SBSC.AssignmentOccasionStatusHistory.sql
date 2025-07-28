CREATE TABLE [SBSC].[AssignmentOccasionStatusHistory] (
  [Id] [int] IDENTITY,
  [AssignmentOccasionId] [int] NULL,
  [Status] [int] NULL,
  [StatusDate] [datetime2] NULL,
  [SubmittedByUserType] [nvarchar](10) NULL,
  [SubmittedBy] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AssignmentOccasionStatusHistory]
  ADD FOREIGN KEY ([AssignmentOccasionId]) REFERENCES [SBSC].[AssignmentOccasions] ([Id])
GO