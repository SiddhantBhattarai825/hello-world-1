CREATE TABLE [SBSC].[Customer_Auditors] (
  [CustomerId] [int] NOT NULL,
  [AuditorId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NULL,
  [Version] [decimal](5, 2) NULL,
  [AddressId] [int] NULL,
  [IsLeadAuditor] [bit] NULL CONSTRAINT [DF_Customer_Auditors_IsLeadAuditor] DEFAULT (0),
  CONSTRAINT [PK__Customer__272567B660E546B2] PRIMARY KEY CLUSTERED ([CustomerId], [AuditorId])
)
GO