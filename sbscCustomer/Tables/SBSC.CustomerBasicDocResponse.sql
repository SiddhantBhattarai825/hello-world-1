CREATE TABLE [SBSC].[CustomerBasicDocResponse] (
  [Id] [int] IDENTITY,
  [BasicDocId] [int] NOT NULL,
  [CustomerId] [int] NOT NULL,
  [DisplayOrder] [int] NULL CONSTRAINT [DF__CustomerBasicDocResponse_DisplayOrder] DEFAULT (0),
  [FreeTextAnswer] [nvarchar](max) NULL,
  [AddedDate] [datetime] NOT NULL CONSTRAINT [DF__CustomerBasicDocResponse_AddedDate] DEFAULT (getutcdate()),
  [ModifiedDate] [datetime] NULL CONSTRAINT [DF__CustomerBasicDocResponse_ModifiedDate] DEFAULT (getutcdate()),
  [Comment] [nvarchar](max) NULL,
  [CustomerCertificationDetailsId] [int] NULL,
  CONSTRAINT [PK__CustomerBasicDocResponse] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CustomerBasicDocResponse]
  ADD CONSTRAINT [FK_CustomerBasicDocResponse_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [SBSC].[Customers] ([Id])
GO