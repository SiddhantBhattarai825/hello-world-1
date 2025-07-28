CREATE TABLE [SBSC].[Customers] (
  [Id] [int] NOT NULL,
  [CompanyName] [nvarchar](200) NOT NULL,
  [CustomerName] [nvarchar](500) NOT NULL,
  [CaseId] [bigint] NOT NULL,
  [OrgNo] [nvarchar](50) NOT NULL,
  [CreatedDate] [datetime] NOT NULL,
  [DefaultAuditor] [int] NULL,
  [UserType] [varchar](10) NULL,
  [RelatedCustomerId] [int] NULL,
  [CaseNumber] [nvarchar](max) NULL,
  [VATNo] [nvarchar](max) NULL,
  [ContactNumber] [nvarchar](100) NULL,
  [ContactCellPhone] [nvarchar](100) NULL,
  [IsAnonymizes] [bit] NOT NULL
)
GO