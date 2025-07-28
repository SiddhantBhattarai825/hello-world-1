CREATE TABLE [SBSC].[Customer_Certifications] (
  [CustomerCertificationId] [int] NOT NULL,
  [CustomerId] [int] NOT NULL,
  [CertificateId] [int] NOT NULL,
  [CertificateNumber] [nvarchar](50) NULL,
  [Validity] [int] NULL,
  [AuditYears] [nvarchar](255) NULL,
  [IssueDate] [date] NULL,
  [ExpiryDate] [date] NULL,
  [CreatedDate] [datetime] NOT NULL,
  [SubmissionStatus] [smallint] NULL,
  [DeviationEndDate] [datetime] NULL,
  [Recertification] [int] NOT NULL
)
GO