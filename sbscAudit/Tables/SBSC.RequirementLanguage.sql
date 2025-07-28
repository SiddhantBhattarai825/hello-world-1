CREATE TABLE [SBSC].[RequirementLanguage] (
  [Id] [int] IDENTITY,
  [RequirementId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [Headlines] [nvarchar](500) NULL,
  [Description] [nvarchar](max) NULL,
  [Notes] [nvarchar](max) NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__Requirem__3214EC079D81A5ED] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[RequirementLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementLanguage_Language] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[RequirementLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementLanguage_Requirement] FOREIGN KEY ([RequirementId]) REFERENCES [SBSC].[Requirement] ([Id]) ON DELETE CASCADE
GO