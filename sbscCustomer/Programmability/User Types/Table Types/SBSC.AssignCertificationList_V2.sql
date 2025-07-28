CREATE TYPE [SBSC].[AssignCertificationList_V2] AS TABLE (
  [CertificationId] [int] NOT NULL,
  [Address] [nvarchar](max) NULL,
  [AddressId] [int] NULL,
  [Recertification] [int] NOT NULL
)
GO