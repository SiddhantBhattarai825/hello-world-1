CREATE TABLE [SBSC].[DocumentLanguage] (
  [Id] [int] IDENTITY,
  [DocId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [Headlines] [nvarchar](255) NULL,
  [Description] [nvarchar](max) NULL,
  CONSTRAINT [PK__Document__3214EC077D061D4C] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[DocumentLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK__DocumentL__DocId__66161CA2] FOREIGN KEY ([DocId]) REFERENCES [SBSC].[Documents] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[DocumentLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK__DocumentL__LangI__670A40DB] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO