CREATE TYPE [SBSC].[AnswerOption] AS TABLE (
  [Id] [int] NULL,
  [AnswerDefault] [nvarchar](500) NULL,
  [HelpTextDefault] [nvarchar](max) NULL,
  [AnswerLang] [nvarchar](500) NULL,
  [HelpTextLang] [nvarchar](max) NULL,
  [DisplayOrder] [int] NULL,
  [Value] [int] NULL,
  [IsCritical] [bit] NULL
)
GO