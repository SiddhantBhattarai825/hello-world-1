CREATE TABLE [SBSC].[RevokedTokens] (
  [Id] [int] IDENTITY,
  [Token] [nvarchar](max) NULL,
  [RevokedAt] [datetime] NOT NULL,
  CONSTRAINT [PK_RevokedTokens] PRIMARY KEY CLUSTERED ([Id])
)
GO