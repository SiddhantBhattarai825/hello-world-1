CREATE TABLE [SBSC].[PreviewToken] (
  [ID] [int] IDENTITY,
  [CertificationId] [int] NULL,
  [LangId] [int] NULL,
  [JwtToken] [nvarchar](max) NULL,
  [Identifier] [nvarchar](max) NULL,
  [ValidTime] [datetime] NULL,
  [IsUsed] [bit] NULL,
  PRIMARY KEY CLUSTERED ([ID])
)
GO