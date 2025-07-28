CREATE TABLE [SBSC].[CommentThread] (
  [Id] [int] IDENTITY,
  [RequirementId] [int] NOT NULL,
  [CustomerId] [int] NULL,
  [AuditorId] [int] NULL,
  [ParentCommentId] [int] NULL,
  [Comment] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NOT NULL CONSTRAINT [DF__CommentTh__Creat__6BAEFA67] DEFAULT (getutcdate()),
  [ModifiedDate] [datetime] NULL,
  [CustomerCommentTurn] [bit] NULL,
  [ReadStatus] [bit] NULL CONSTRAINT [DF_CommentThread_ReadStatus] DEFAULT (0),
  [Recertification] [int] NOT NULL DEFAULT (0),
  [CustomerCertificationDetailsId] [int] NULL,
  CONSTRAINT [PK__CommentT__3214EC07C9717D49] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_CommentThread_Customer_Requirement]
  ON [SBSC].[CommentThread] ([CustomerId], [RequirementId])
  INCLUDE ([Id], [Recertification], [CreatedDate], [AuditorId])
GO

ALTER TABLE [SBSC].[CommentThread] WITH NOCHECK
  ADD CONSTRAINT [FK_CommentThread_CustomerCertificationDetails] FOREIGN KEY ([CustomerCertificationDetailsId]) REFERENCES [SBSC].[CustomerCertificationDetails] ([Id])
GO

ALTER TABLE [SBSC].[CommentThread]
  ADD CONSTRAINT [FK_CommentThread_Customers] FOREIGN KEY ([CustomerId]) REFERENCES [SBSC].[Customers] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[CommentThread] WITH NOCHECK
  ADD CONSTRAINT [FK_CommentThread_ParentComment] FOREIGN KEY ([ParentCommentId]) REFERENCES [SBSC].[CommentThread] ([Id])
GO