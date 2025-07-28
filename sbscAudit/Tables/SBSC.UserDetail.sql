CREATE TABLE [SBSC].[UserDetail] (
  [Id] [int] IDENTITY,
  [UserId] [int] NOT NULL,
  [FullName] [nvarchar](500) NOT NULL,
  [DateOfBirth] [nvarchar](500) NOT NULL,
  [Email] [nvarchar](500) NOT NULL,
  [CompanyName] [nvarchar](500) NOT NULL,
  [CompanyVAT] [nvarchar](500) NOT NULL,
  [SocialSecurityNumber] [nvarchar](500) NOT NULL,
  [AddedDate] [datetime] NOT NULL,
  [AddedBy] [int] NOT NULL,
  [ModifiedBy] [int] NOT NULL,
  [ModifiedDate] [datetime] NOT NULL,
  CONSTRAINT [PK_UserDetail] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[UserDetail] WITH NOCHECK
  ADD CONSTRAINT [FK_UserDetail_User] FOREIGN KEY ([UserId]) REFERENCES [SBSC].[User] ([Id])
GO