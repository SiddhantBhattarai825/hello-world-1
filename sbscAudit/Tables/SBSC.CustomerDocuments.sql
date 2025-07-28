CREATE TABLE [SBSC].[CustomerDocuments] (
  [Id] [int] NOT NULL,
  [CustomerResponseId] [int] NOT NULL,
  [DocumentName] [nvarchar](255) NOT NULL,
  [DocumentType] [nvarchar](100) NULL,
  [AddedDate] [datetime] NOT NULL
)
GO