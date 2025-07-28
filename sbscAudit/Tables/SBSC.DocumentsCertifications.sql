CREATE TABLE [SBSC].[DocumentsCertifications] (
  [Id] [int] IDENTITY,
  [DocId] [int] NOT NULL,
  [CertificationId] [int] NOT NULL,
  [DisplayOrder] [int] NULL,
  [IsWarning] [bit] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[DocumentsCertifications] WITH NOCHECK
  ADD CONSTRAINT [FK__Documents__Certi__6ADAD1BF] FOREIGN KEY ([CertificationId]) REFERENCES [SBSC].[Certification] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[DocumentsCertifications] WITH NOCHECK
  ADD CONSTRAINT [FK__Documents__DocId__69E6AD86] FOREIGN KEY ([DocId]) REFERENCES [SBSC].[Documents] ([Id]) ON DELETE CASCADE
GO