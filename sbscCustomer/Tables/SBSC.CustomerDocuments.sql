CREATE TABLE [SBSC].[CustomerDocuments] (
  [ID] [int] IDENTITY,
  [CustomerResponseId] [int] NOT NULL,
  [DocumentName] [nvarchar](255) NOT NULL,
  [DocumentType] [nvarchar](100) NOT NULL,
  [AddedDate] [datetime] NOT NULL DEFAULT (getutcdate()),
  [UploadId] [nvarchar](100) NULL,
  [Size] [nvarchar](20) NULL,
  [DownloadLink] [nvarchar](max) NULL,
  PRIMARY KEY CLUSTERED ([ID])
)
GO

ALTER TABLE [SBSC].[CustomerDocuments]
  ADD CONSTRAINT [FK_CustomerDocuments_CustomerResponse] FOREIGN KEY ([CustomerResponseId]) REFERENCES [SBSC].[CustomerResponse] ([Id]) ON DELETE CASCADE
GO