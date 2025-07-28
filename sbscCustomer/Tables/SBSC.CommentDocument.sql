CREATE TABLE [SBSC].[CommentDocument] (
  [Id] [int] IDENTITY,
  [CommentId] [int] NOT NULL,
  [DocumentName] [nvarchar](255) NOT NULL,
  [DocumentType] [nvarchar](100) NOT NULL,
  [AddedDate] [datetime] NOT NULL,
  [UploadId] [nvarchar](100) NULL,
  [Size] [nvarchar](20) NULL,
  [DownloadLink] [nvarchar](max) NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CommentDocument]
  ADD CONSTRAINT [FK_CommentDocument_CommentThread] FOREIGN KEY ([CommentId]) REFERENCES [SBSC].[CommentThread] ([Id]) ON DELETE CASCADE
GO