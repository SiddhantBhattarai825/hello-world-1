CREATE TYPE [SBSC].[CustomerDocumentsType] AS TABLE (
  [DocumentName] [nvarchar](255) NOT NULL,
  [DocumentType] [nvarchar](100) NOT NULL,
  [Size] [nvarchar](20) NULL,
  [UploadId] [nvarchar](100) NULL,
  [DownloadLink] [nvarchar](max) NULL
)
GO