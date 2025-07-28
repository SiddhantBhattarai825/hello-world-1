CREATE TABLE [SBSC].[DocumentCommentThread] (
  [Id] [int] IDENTITY,
  [DocumentId] [int] NOT NULL,
  [CustomerId] [int] NULL,
  [AuditorId] [int] NULL,
  [ParentCommentId] [int] NULL,
  [Comment] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NOT NULL CONSTRAINT [DF__DocCommentTh__Creat__6BAEFA67] DEFAULT (getutcdate()),
  [ModifiedDate] [datetime] NULL,
  [CustomerCommentTurn] [bit] NULL,
  [ReadStatus] [bit] NULL CONSTRAINT [DF_DocCommentThread_ReadStatus] DEFAULT (0),
  [Recertification] [int] NOT NULL DEFAULT (0),
  [IsApproved] [bit] NULL,
  [CustomerCertificationDetailsId] [int] NULL,
  CONSTRAINT [PK__DocCommentT__3214EC07C9717D49] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_DocumentCommentThread_Customer_Cert]
  ON [SBSC].[DocumentCommentThread] ([CustomerId], [DocumentId])
  INCLUDE ([Id], [Recertification], [CreatedDate], [AuditorId])
GO

ALTER TABLE [SBSC].[DocumentCommentThread]
  ADD CONSTRAINT [FK_DocCommentThread_Auditors] FOREIGN KEY ([CustomerId]) REFERENCES [SBSC].[Customers] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[DocumentCommentThread]
  ADD CONSTRAINT [FK_DocCommentThread_ParentComment] FOREIGN KEY ([ParentCommentId]) REFERENCES [SBSC].[DocumentCommentThread] ([Id])
GO

ALTER TABLE [SBSC].[DocumentCommentThread] WITH NOCHECK
  ADD CONSTRAINT [FK_DocumentCommentThread_CustomerCertificationDetails] FOREIGN KEY ([CustomerCertificationDetailsId]) REFERENCES [SBSC].[CustomerCertificationDetails] ([Id])
GO