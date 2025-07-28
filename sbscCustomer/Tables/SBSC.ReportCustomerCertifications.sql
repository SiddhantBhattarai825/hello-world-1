CREATE TABLE [SBSC].[ReportCustomerCertifications] (
  [Id] [int] NOT NULL,
  [CustomerCertificationId] [int] NULL,
  [ReportBlockId] [int] NULL,
  [Details] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NULL,
  [AuditorId] [int] NULL,
  [Recertification] [int] NULL,
  [ModifiedDate] [datetime] NULL,
  [CustomerCertificationDetailsId] [int] NULL
)
GO