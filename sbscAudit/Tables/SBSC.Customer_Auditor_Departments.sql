CREATE TABLE [SBSC].[Customer_Auditor_Departments] (
  [CustomerId] [int] NOT NULL,
  [AuditorId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NOT NULL,
  [Version] [decimal](5, 2) NOT NULL,
  [AddressId] [int] NOT NULL,
  [DepartmentId] [int] NOT NULL
)
GO