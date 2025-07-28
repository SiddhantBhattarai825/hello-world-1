CREATE TYPE [SBSC].[CertificationListType] AS TABLE (
  [CertificateId] [int] NOT NULL,
  [LocationName] [nvarchar](max) NULL,
  [CustomerCertificationId] [int] NULL,
  [Recertification] [int] NULL
)
GO