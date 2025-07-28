CREATE TABLE [SBSC].[LabelTextTranslations] (
  [Id] [int] IDENTITY,
  [LabelTextId] [int] NOT NULL,
  [LanguageId] [int] NOT NULL,
  [TranslatedTitle] [nvarchar](255) NOT NULL,
  [TranslatedDescription] [nvarchar](max) NULL,
  PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_LabelTextTranslations_LabelTextId_LanguageId] UNIQUE ([LabelTextId], [LanguageId])
)
GO

ALTER TABLE [SBSC].[LabelTextTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LabelTextTranslations_LabelTexts] FOREIGN KEY ([LabelTextId]) REFERENCES [SBSC].[LabelTexts] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[LabelTextTranslations] WITH NOCHECK
  ADD CONSTRAINT [FK_LabelTextTranslations_Languages] FOREIGN KEY ([LanguageId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO