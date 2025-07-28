CREATE TYPE [SBSC].[EmailTemplateLanguageType] AS TABLE (
  [LangId] [int] NULL,
  [EmailTemplateId] [int] NULL,
  [EmailSubject] [nvarchar](255) NULL,
  [EmailBody] [nvarchar](max) NULL
)
GO