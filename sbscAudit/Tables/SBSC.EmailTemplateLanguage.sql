CREATE TABLE [SBSC].[EmailTemplateLanguage] (
  [Id] [int] IDENTITY,
  [LangId] [int] NOT NULL,
  [EmailTemplateId] [int] NOT NULL,
  [EmailSubject] [nvarchar](500) NULL,
  [EmailBody] [nvarchar](max) NULL,
  CONSTRAINT [PK_EmailTemplateLanguage] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_EmailTemplateLanguage] UNIQUE ([EmailTemplateId], [LangId])
)
GO

ALTER TABLE [SBSC].[EmailTemplateLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_EmailTemplateLanguage_EmailTemplate] FOREIGN KEY ([EmailTemplateId]) REFERENCES [SBSC].[EmailTemplate] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[EmailTemplateLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_EmailTemplateLanguage_LangId] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO