CREATE TABLE [SBSC].[Certification] (
  [Id] [int] NOT NULL,
  [CertificateTypeId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NULL,
  [Validity] [int] NULL,
  [IsVisible] [int] NULL,
  [IsActive] [int] NULL,
  [AddedDate] [datetime] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [datetime] NULL,
  [ModifiedBy] [int] NULL,
  [AuditYears] [nvarchar](255) NULL,
  [Published] [int] NOT NULL,
  [Version] [decimal](5, 2) NULL,
  [IsAuditorInitiated] [smallint] NULL,
  [ParentCertificationId] [int] NULL,
  [IsDeleted] [bit] NULL
)
GO