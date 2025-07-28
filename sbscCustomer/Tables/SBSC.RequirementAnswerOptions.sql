CREATE TABLE [SBSC].[RequirementAnswerOptions] (
  [Id] [int] NOT NULL,
  [RequirementId] [int] NOT NULL,
  [DisplayOrder] [int] NULL,
  [Value] [int] NULL,
  [RequirementTypeOptionId] [int] NULL,
  [IsCritical] [bit] NULL
)
GO