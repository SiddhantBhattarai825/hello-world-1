CREATE TABLE [SBSC].[ImpersonateToken] (
  [ID] [int] IDENTITY,
  [JwtToken] [nvarchar](max) NOT NULL,
  [Identifier] [nvarchar](100) NOT NULL,
  [ValidTime] [datetime] NOT NULL,
  [IsUsed] [bit] NOT NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([ID])
)
GO