CREATE TABLE [SBSC].[Customer_Certifications] (
  [CustomerCertificationId] [int] IDENTITY,
  [CustomerId] [int] NOT NULL,
  [CertificateId] [int] NOT NULL,
  [CertificateNumber] [nvarchar](50) NULL,
  [Validity] [int] NULL,
  [AuditYears] [nvarchar](255) NULL,
  [IssueDate] [date] NULL,
  [ExpiryDate] [date] NULL,
  [CreatedDate] [datetime] NOT NULL CONSTRAINT [DF__Customer___Creat__5224328E] DEFAULT (getdate()),
  [SubmissionStatus] [smallint] NULL,
  [DeviationEndDate] [datetime] NULL,
  [Recertification] [int] NOT NULL DEFAULT (0),
  [ValidityPeriod] [int] NOT NULL DEFAULT (0),
  CONSTRAINT [PK_CustomerCertifications] PRIMARY KEY CLUSTERED ([CustomerCertificationId]),
  CONSTRAINT [UQ_CustomerCertifications_CertificateNumber] UNIQUE ([CustomerId], [CertificateId])
)
GO

ALTER TABLE [SBSC].[Customer_Certifications]
  ADD CONSTRAINT [FK_Customer_Certifications_Customer] FOREIGN KEY ([CustomerId]) REFERENCES [SBSC].[Customers] ([Id])
GO