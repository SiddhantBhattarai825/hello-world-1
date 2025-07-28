CREATE TABLE [SBSC].[AuditorNotes] (
  [Id] [int] NOT NULL,
  [AuditorCustomerResponseId] [int] NULL,
  [AuditorId] [int] NULL,
  [Note] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NOT NULL,
  [CustomerResponseId] [int] NOT NULL
)
GO