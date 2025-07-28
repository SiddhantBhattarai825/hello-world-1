CREATE TABLE [SBSC].[Customer_Auditors] (
  [CustomerId] [int] NOT NULL,
  [AuditorId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NULL,
  [Version] [decimal](5, 2) NULL,
  [AddressId] [int] NOT NULL,
  [IsLeadAuditor] [bit] NULL
)
GO