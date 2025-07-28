CREATE TABLE [SBSC].[RequirementAnswerOptions] (
  [Id] [int] IDENTITY,
  [RequirementId] [int] NOT NULL,
  [DisplayOrder] [int] NULL,
  [Value] [int] NULL,
  [RequirementTypeOptionId] [int] NULL,
  [IsCritical] [bit] NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[RequirementAnswerOptions] WITH NOCHECK
  ADD CONSTRAINT [FK_AnswerOptions_Requirement] FOREIGN KEY ([RequirementId]) REFERENCES [SBSC].[Requirement] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[RequirementAnswerOptions]
  ADD CONSTRAINT [FK_AnswerOptions_RequirementTypeOption] FOREIGN KEY ([RequirementTypeOptionId]) REFERENCES [SBSC].[RequirementTypeOption] ([Id]) ON DELETE SET NULL
GO