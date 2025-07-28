CREATE TABLE [SBSC].[CertificationLanguage] (
  [Id] [int] IDENTITY,
  [CertificationId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [CertificationName] [nvarchar](255) NULL,
  [Description] [nvarchar](max) NULL,
  [Published] [int] NULL CONSTRAINT [DF_CertificationLanguage_Published] DEFAULT (0),
  [PublishedDate] [datetime] NULL DEFAULT (NULL),
  [IsDeleted] [bit] NULL DEFAULT (0),
  [UpdatedAt] [datetime] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CertificationLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_CertificationLanguage_Certification_Cascade] FOREIGN KEY ([CertificationId]) REFERENCES [SBSC].[Certification] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[CertificationLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_CertificationLanguage_Languages] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO