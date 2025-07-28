CREATE TABLE [SBSC].[DecisionRemarks] (
  [Id] [int] IDENTITY,
  [CustomerCertificationId] [int] NOT NULL,
  [Remarks] [nvarchar](max) NULL,
  [AuditorId] [int] NULL,
  [CreatedDate] [datetime] NULL DEFAULT (getdate()),
  [Recertification] [int] NULL DEFAULT (0),
  [ModifiedDate] [datetime] NULL,
  [CustomerCertificationDetailsId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[DecisionRemarks] WITH NOCHECK
  ADD CONSTRAINT [FK_DecisionRemarks_CustomerCertificationDetails] FOREIGN KEY ([CustomerCertificationDetailsId]) REFERENCES [SBSC].[CustomerCertificationDetails] ([Id])
GO

ALTER TABLE [SBSC].[DecisionRemarks]
  ADD CONSTRAINT [FK_DecisionRemarks_CustomerCertifications] FOREIGN KEY ([CustomerCertificationId]) REFERENCES [SBSC].[Customer_Certifications] ([CustomerCertificationId])
GO