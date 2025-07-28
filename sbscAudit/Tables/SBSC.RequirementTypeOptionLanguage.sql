CREATE TABLE [SBSC].[RequirementTypeOptionLanguage] (
  [Id] [int] IDENTITY,
  [RequirementTypeOptionId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [AnswerOptions] [nvarchar](500) NULL,
  [Description] [nvarchar](max) NULL,
  [HelpText] [nvarchar](max) NULL,
  CONSTRAINT [PK__Requirem__3214EC07DB49DC5D] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[RequirementTypeOptionLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementOptionLanguage_Language] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[RequirementTypeOptionLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementOptionLanguage_RequirementTypeOption] FOREIGN KEY ([RequirementTypeOptionId]) REFERENCES [SBSC].[RequirementTypeOption] ([Id]) ON DELETE CASCADE
GO