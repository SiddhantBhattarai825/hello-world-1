CREATE TABLE [SBSC].[Languages] (
  [Id] [int] NOT NULL,
  [LanguageCode] [nvarchar](10) NOT NULL,
  [LanguageName] [nvarchar](50) NULL,
  [IsActive] [bit] NULL,
  [IsDefault] [bit] NULL
)
GO