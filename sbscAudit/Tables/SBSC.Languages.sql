CREATE TABLE [SBSC].[Languages] (
  [Id] [int] IDENTITY,
  [LanguageCode] [nvarchar](10) NOT NULL,
  [LanguageName] [nvarchar](50) NOT NULL,
  [IsActive] [bit] NOT NULL DEFAULT (1),
  [IsDefault] [bit] NOT NULL DEFAULT (0),
  [IsDeleted] [bit] NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_Languages_LanguageCode] UNIQUE ([LanguageCode])
)
GO