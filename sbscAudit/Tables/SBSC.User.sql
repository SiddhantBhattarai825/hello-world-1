CREATE TABLE [SBSC].[User] (
  [Id] [int] IDENTITY,
  [Username] [nvarchar](100) NOT NULL,
  [Password] [nvarchar](100) NOT NULL,
  [MemberId] [int] NOT NULL,
  [UserTypeId] [int] NOT NULL,
  CONSTRAINT [PK_User] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[User] WITH NOCHECK
  ADD CONSTRAINT [FK_User_UserType] FOREIGN KEY ([UserTypeId]) REFERENCES [SBSC].[UserType] ([Id])
GO