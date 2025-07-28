CREATE TABLE [SBSC].[ReportBlocksCertifications] (
  [Id] [int] IDENTITY,
  [ReportBlockId] [int] NOT NULL,
  [CertificationId] [int] NOT NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IDX_ReportBlocksCertifications_ReportBlockId]
  ON [SBSC].[ReportBlocksCertifications] ([ReportBlockId])
GO

ALTER TABLE [SBSC].[ReportBlocksCertifications]
  ADD CONSTRAINT [FK_ReportBlocksCertifications_CertificationId] FOREIGN KEY ([CertificationId]) REFERENCES [SBSC].[Certification] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[ReportBlocksCertifications]
  ADD CONSTRAINT [FK_ReportBlocksCertifications_ReportBlockId] FOREIGN KEY ([ReportBlockId]) REFERENCES [SBSC].[ReportBlocks] ([Id]) ON DELETE CASCADE
GO