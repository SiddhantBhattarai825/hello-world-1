CREATE TABLE [SBSC].[RequirementAnswerOptionsLanguage] (
  [Id] [int] IDENTITY,
  [AnswerOptionId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [Answer] [nvarchar](500) NULL,
  [HelpText] [nvarchar](max) NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__Requirem__3214EC07D77192EB] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[RequirementAnswerOptionsLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_AnswerOptionLanguage_AnswerOptions] FOREIGN KEY ([AnswerOptionId]) REFERENCES [SBSC].[RequirementAnswerOptions] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[RequirementAnswerOptionsLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_AnswerOptionLanguage_Language] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO