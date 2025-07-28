CREATE TABLE [SBSC].[ReportCustomerCertifications] (
  [Id] [int] IDENTITY,
  [CustomerCertificationId] [int] NOT NULL,
  [ReportBlockId] [int] NOT NULL,
  [Details] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NULL DEFAULT (getdate()),
  [AuditorId] [int] NULL,
  [Recertification] [int] NOT NULL DEFAULT (0),
  [ModifiedDate] [datetime] NULL,
  [CustomerCertificationDetailsId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IDX_ReportCustomerCertifications_CustomerCertificationId_ReportBlockCertificationId]
  ON [SBSC].[ReportCustomerCertifications] ([CustomerCertificationId], [ReportBlockId])
GO

ALTER TABLE [SBSC].[ReportCustomerCertifications]
  ADD CONSTRAINT [FK_ReportCustomerCertifications_ReportBlockId] FOREIGN KEY ([ReportBlockId]) REFERENCES [SBSC].[ReportBlocks] ([Id]) ON DELETE CASCADE
GO