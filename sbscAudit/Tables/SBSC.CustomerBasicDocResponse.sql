CREATE TABLE [SBSC].[CustomerBasicDocResponse] (
  [Id] [int] NOT NULL,
  [BasicDocId] [int] NOT NULL,
  [CustomerId] [int] NOT NULL,
  [DisplayOrder] [int] NULL,
  [FreeTextAnswer] [nvarchar](max) NULL,
  [AddedDate] [datetime] NOT NULL,
  [ModifiedDate] [datetime] NOT NULL,
  [Comment] [nvarchar](max) NULL,
  [CustomerCertificationDetailsId] [int] NULL
)
GO