CREATE TABLE [SBSC].[Auditor_Certifications] (
  [AuditorId] [int] NOT NULL,
  [CertificationId] [int] NOT NULL,
  [IsDefault] [bit] NULL,
  PRIMARY KEY CLUSTERED ([AuditorId], [CertificationId])
)
GO

ALTER TABLE [SBSC].[Auditor_Certifications] WITH NOCHECK
  ADD FOREIGN KEY ([AuditorId]) REFERENCES [SBSC].[Auditor] ([Id])
GO

ALTER TABLE [SBSC].[Auditor_Certifications] WITH NOCHECK
  ADD CONSTRAINT [FK__Auditor_C__Certi__049AA3C2] FOREIGN KEY ([CertificationId]) REFERENCES [SBSC].[Certification] ([Id])
GO