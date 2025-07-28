CREATE TABLE [SBSC].[CertificationCategoryLanguage] (
  [Id] [int] IDENTITY,
  [CertificationCategoryId] [int] NOT NULL,
  [CertificationCategoryTitle] [nvarchar](100) NULL,
  [LanguageId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CertificationCategoryLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_CertificationCategoryLanguage_CertificationCategory] FOREIGN KEY ([CertificationCategoryId]) REFERENCES [SBSC].[CertificationCategory] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[CertificationCategoryLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_CertificationCategoryLanguage_Languages] FOREIGN KEY ([LanguageId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO