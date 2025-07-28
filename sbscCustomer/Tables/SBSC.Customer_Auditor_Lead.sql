CREATE TABLE [SBSC].[Customer_Auditor_Lead] (
  [CustomerId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NOT NULL,
  [AuditorId] [int] NOT NULL,
  [Version] [decimal](5, 2) NOT NULL DEFAULT (1.0),
  PRIMARY KEY CLUSTERED ([CustomerId], [AuditorId])
)
GO