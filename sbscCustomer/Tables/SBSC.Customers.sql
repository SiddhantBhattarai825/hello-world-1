CREATE TABLE [SBSC].[Customers] (
  [Id] [int] IDENTITY,
  [CompanyName] [nvarchar](200) NOT NULL,
  [CustomerName] [nvarchar](500) NOT NULL,
  [CaseId] [bigint] NOT NULL,
  [OrgNo] [nvarchar](50) NOT NULL,
  [CreatedDate] [datetime] NULL CONSTRAINT [DF_Customers_CreatedDate] DEFAULT (getutcdate()),
  [DefaultAuditor] [int] NULL,
  [UserType] [varchar](10) NULL DEFAULT ('Customer'),
  [RelatedCustomerId] [int] NULL,
  [CaseNumber] [nvarchar](max) NULL,
  [VATNo] [nvarchar](max) NULL,
  [ContactNumber] [nvarchar](100) NULL,
  [IsAnonymizes] [bit] NOT NULL CONSTRAINT [DF_Customers_IsAnonymizes] DEFAULT (0),
  [ContactCellPhone] [nvarchar](100) NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK_Customers] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[Customers]
  ADD CONSTRAINT [FK_Customers_RelatedCustomerId] FOREIGN KEY ([RelatedCustomerId]) REFERENCES [SBSC].[Customers] ([Id])
GO