CREATE TYPE [SBSC].[ChapterSectionType] AS TABLE (
  [TempId] [int] NOT NULL,
  [Title] [nvarchar](255) NULL,
  [Description] [nvarchar](max) NULL,
  [ParentTempId] [int] NULL,
  [DisplayOrder] [int] NULL,
  [IsWarning] [bit] NULL DEFAULT (0),
  [IsVisible] [bit] NULL DEFAULT (1),
  [DefaultLangId] [int] NULL,
  [Level] [int] NULL,
  [TitleLang] [nvarchar](255) NULL,
  [DescriptionLang] [nvarchar](max) NULL,
  [LangId] [int] NULL
)
GO