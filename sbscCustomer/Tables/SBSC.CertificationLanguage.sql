CREATE TABLE [SBSC].[CertificationLanguage] (
  [Id] [int] NOT NULL,
  [CertificationId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [CertificationName] [nvarchar](255) NULL,
  [Description] [nvarchar](max) NULL,
  [Published] [int] NOT NULL,
  [PublishedDate] [datetime] NULL,
  [IsDeleted] [bit] NULL
)
GO