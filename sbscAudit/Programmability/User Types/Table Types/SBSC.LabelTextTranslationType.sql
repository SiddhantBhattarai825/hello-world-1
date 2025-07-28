CREATE TYPE [SBSC].[LabelTextTranslationType] AS TABLE (
  [Id] [int] NULL,
  [LabelId] [int] NULL,
  [LangId] [int] NULL,
  [Value] [nvarchar](max) NULL
)
GO