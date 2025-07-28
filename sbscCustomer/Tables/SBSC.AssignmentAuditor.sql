CREATE TABLE [SBSC].[AssignmentAuditor] (
  [Id] [int] IDENTITY,
  [AssignmentId] [int] NULL,
  [AuditorId] [int] NULL,
  [IsLeadAuditor] [bit] NULL,
  CONSTRAINT [PK__Assignme__3214EC0732FA642D] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_AssignmentAuditor_Auditor]
  ON [SBSC].[AssignmentAuditor] ([AuditorId], [AssignmentId])
GO

ALTER TABLE [SBSC].[AssignmentAuditor]
  ADD CONSTRAINT [FK_AssignmentAuditor_AssignmentOccasions] FOREIGN KEY ([AssignmentId]) REFERENCES [SBSC].[AssignmentOccasions] ([Id]) ON DELETE CASCADE
GO