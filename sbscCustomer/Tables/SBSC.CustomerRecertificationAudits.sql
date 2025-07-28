CREATE TABLE [SBSC].[CustomerRecertificationAudits] (
  [Id] [int] IDENTITY,
  [CustomerCertificationId] [int] NOT NULL,
  [JobId] [nvarchar](100) NOT NULL,
  [AuditYear] [int] NOT NULL,
  [AuditDate] [datetime] NULL,
  [Recertification] [int] NOT NULL DEFAULT (0),
  [CreatedDate] [datetime] NOT NULL DEFAULT (getutcdate()),
  [CustomerCertificationDetailsId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CustomerRecertificationAudits]
  ADD CONSTRAINT [FK_CustomerRecertificationAudits_CustomerCertifications] FOREIGN KEY ([CustomerCertificationId]) REFERENCES [SBSC].[Customer_Certifications] ([CustomerCertificationId]) ON DELETE CASCADE
GO