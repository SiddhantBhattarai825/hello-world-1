CREATE TABLE [SBSC].[AdminUserDetail] (
  [Id] [int] IDENTITY,
  [AdminUserId] [int] NOT NULL,
  [FullName] [nvarchar](500) NOT NULL,
  [DateOfBirth] [nvarchar](500) NULL,
  [AddedDate] [datetime] NULL,
  [AddedBy] [int] NULL,
  [ModifiedBy] [int] NULL,
  [ModifiedDate] [datetime] NULL,
  CONSTRAINT [PK_AdminUserDetail] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AdminUserDetail] WITH NOCHECK
  ADD CONSTRAINT [FK_AdminUserDetail_AdminUser] FOREIGN KEY ([AdminUserId]) REFERENCES [SBSC].[AdminUser] ([Id]) ON DELETE CASCADE
GO