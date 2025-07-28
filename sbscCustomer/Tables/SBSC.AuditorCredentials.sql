CREATE TABLE [SBSC].[AuditorCredentials] (
  [ID] [int] NOT NULL,
  [Email] [nvarchar](100) NOT NULL,
  [IsActive] [bit] NULL,
  [AuditorId] [int] NULL,
  [DefaultLangId] [int] NULL
)
GO