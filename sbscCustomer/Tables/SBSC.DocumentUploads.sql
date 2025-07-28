CREATE TABLE [SBSC].[DocumentUploads] (
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

ALTER TABLE [SBSC].[DocumentUploads]
  ADD CONSTRAINT [FK_DocumentUploads_DocCommentThread] FOREIGN KEY ([CommentId]) REFERENCES [SBSC].[DocumentCommentThread] ([Id]) ON DELETE CASCADE
GO