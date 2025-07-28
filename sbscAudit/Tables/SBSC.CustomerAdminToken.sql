CREATE TABLE [SBSC].[CustomerAdminToken] (
  [Id] [int] IDENTITY,
  [AdminId] [int] NULL,
  [Email] [nvarchar](max) NULL,
  [JwtToken] [nvarchar](max) NULL,
  [Identifier] [nvarchar](max) NULL,
  [ValidTime] [datetime] NULL,
  [IsUsed] [bit] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO