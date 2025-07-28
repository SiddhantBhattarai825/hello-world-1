CREATE TABLE [SBSC].[CustomerResponse] (
  [Id] [int] IDENTITY,
  [RequirementId] [int] NOT NULL,
  [CustomerId] [int] NOT NULL,
  [DisplayOrder] [int] NULL CONSTRAINT [DF__CustomerR__Displ__797309D9] DEFAULT (0),
  [FreeTextAnswer] [nvarchar](max) NULL,
  [AddedDate] [datetime] NOT NULL CONSTRAINT [DF__CustomerR__Added__7A672E12] DEFAULT (getutcdate()),
  [ModifiedDate] [datetime] NULL CONSTRAINT [DF__CustomerR__Modif__7B5B524B] DEFAULT (getutcdate()),
  [Comment] [nvarchar](max) NULL,
  [Recertification] [int] NOT NULL DEFAULT (0),
  [CustomerCertificationDetailsId] [int] NULL,
  CONSTRAINT [PK__Customer__3214EC071F18986F] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_CustomerResponse_Customer_Requirement]
  ON [SBSC].[CustomerResponse] ([CustomerId], [RequirementId])
  INCLUDE ([Id], [Recertification], [AddedDate])
GO

ALTER TABLE [SBSC].[CustomerResponse]
  ADD CONSTRAINT [FK_CustomerResponse_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [SBSC].[Customers] ([Id])
GO

ALTER TABLE [SBSC].[CustomerResponse] WITH NOCHECK
  ADD CONSTRAINT [FK_CustomerResponse_CustomerCertificationDetails] FOREIGN KEY ([CustomerCertificationDetailsId]) REFERENCES [SBSC].[CustomerCertificationDetails] ([Id])
GO