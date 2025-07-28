CREATE TABLE [SBSC].[Customer_Auditor_Departments] (
  [CustomerId] [int] NOT NULL,
  [AuditorId] [int] NULL,
  [CertificateCode] [nvarchar](255) NOT NULL,
  [Version] [decimal](5, 2) NOT NULL,
  [AddressId] [int] NULL,
  [DepartmentId] [int] NULL,
  [CertificateNumber] [int] NULL,
  [RecordId] [int] IDENTITY,
  [Date] [date] NULL,
  CONSTRAINT [PK_CustomerAuditorDepartments] PRIMARY KEY CLUSTERED ([RecordId])
)
GO

CREATE UNIQUE INDEX [UX_CustomerCertificateAuditor]
  ON [SBSC].[Customer_Auditor_Departments] ([CustomerId], [CertificateCode], [AuditorId], [AddressId], [DepartmentId])
  WHERE ([AuditorId] IS NOT NULL)
GO

ALTER TABLE [SBSC].[Customer_Auditor_Departments] WITH NOCHECK
  ADD CONSTRAINT [FK_Customer_Auditor_Departments_Address] FOREIGN KEY ([AddressId]) REFERENCES [SBSC].[Customer_Address] ([Id])
GO