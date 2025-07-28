CREATE TABLE [SBSC].[CustomerBasicDocuments] (
  [ID] [int] IDENTITY,
  [CustomerBasicDocResponseId] [int] NOT NULL,
  [DocumentName] [nvarchar](255) NOT NULL,
  [DocumentType] [nvarchar](100) NOT NULL,
  [AddedDate] [datetime] NOT NULL DEFAULT (getutcdate()),
  [DownloadLink] [nvarchar](max) NULL,
  PRIMARY KEY CLUSTERED ([ID])
)
GO

ALTER TABLE [SBSC].[CustomerBasicDocuments]
  ADD CONSTRAINT [FK_CustomerBasicDocuments_CustomerBasicDocResponse] FOREIGN KEY ([CustomerBasicDocResponseId]) REFERENCES [SBSC].[CustomerBasicDocResponse] ([Id]) ON DELETE CASCADE
GO