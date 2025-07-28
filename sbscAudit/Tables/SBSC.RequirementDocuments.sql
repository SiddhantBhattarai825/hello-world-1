CREATE TABLE [SBSC].[RequirementDocuments] (
  [Id] [int] IDENTITY,
  [RequirementId] [int] NOT NULL,
  [DocumentName] [nvarchar](255) NOT NULL,
  [DocumentType] [nvarchar](50) NOT NULL,
  [AddedDate] [datetime] NOT NULL DEFAULT (getutcdate()),
  [UserType] [nvarchar](20) NOT NULL,
  [AdminId] [int] NULL,
  [CustomerId] [int] NULL,
  [AuditorId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[RequirementDocuments] WITH NOCHECK
  ADD CONSTRAINT [CK_RequirementDocuments_SingleUser] CHECK (((case when [AdminId] IS NOT NULL then (1) else (0) end+case when [CustomerId] IS NOT NULL then (1) else (0) end)+case when [AuditorId] IS NOT NULL then (1) else (0) end)=(1))
GO

ALTER TABLE [SBSC].[RequirementDocuments] WITH NOCHECK
  ADD CONSTRAINT [CK_RequirementDocuments_UserType] CHECK ([UserType]='Auditor' OR [UserType]='Customer' OR [UserType]='Admin')
GO

ALTER TABLE [SBSC].[RequirementDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementDocuments_Admin] FOREIGN KEY ([AdminId]) REFERENCES [SBSC].[AdminUser] ([Id])
GO

ALTER TABLE [SBSC].[RequirementDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementDocuments_Auditor] FOREIGN KEY ([AuditorId]) REFERENCES [SBSC].[Auditor] ([Id])
GO

ALTER TABLE [SBSC].[RequirementDocuments] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementDocuments_Requirement] FOREIGN KEY ([RequirementId]) REFERENCES [SBSC].[Requirement] ([Id])
GO