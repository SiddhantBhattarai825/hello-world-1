CREATE TABLE [SBSC].[UserType] (
  [Id] [int] IDENTITY,
  [Title] [nvarchar](500) NOT NULL,
  [Description] [nvarchar](max) NOT NULL,
  CONSTRAINT [PK_UserType] PRIMARY KEY CLUSTERED ([Id])
)
GO