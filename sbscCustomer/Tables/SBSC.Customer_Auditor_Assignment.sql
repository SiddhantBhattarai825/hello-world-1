CREATE TABLE [SBSC].[Customer_Auditor_Assignment] (
  [CustomerId] [int] NOT NULL,
  [AuditorId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NOT NULL,
  [Version] [decimal](5, 2) NOT NULL CONSTRAINT [DF__Customer___Versi__40F9A68C] DEFAULT (1.0),
  [AddressId] [int] NOT NULL,
  [DepartmentId] [int] NOT NULL,
  [CertificateNumber] [int] NULL,
  [Date] [date] NULL,
  CONSTRAINT [PK_Customer_Auditor_Assignment] PRIMARY KEY CLUSTERED ([CustomerId], [AuditorId], [AddressId], [DepartmentId])
)
GO

ALTER TABLE [SBSC].[Customer_Auditor_Assignment]
  ADD CONSTRAINT [FK_Customer_Auditor_Assignment_Address] FOREIGN KEY ([AddressId]) REFERENCES [SBSC].[Customer_Address] ([Id])
GO

ALTER TABLE [SBSC].[Customer_Auditor_Assignment]
  ADD CONSTRAINT [FK_Customer_Auditor_Assignment_Department] FOREIGN KEY ([DepartmentId]) REFERENCES [SBSC].[Customer_Department] ([Id])
GO