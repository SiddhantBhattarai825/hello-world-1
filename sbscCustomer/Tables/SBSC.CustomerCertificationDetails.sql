CREATE TABLE [SBSC].[CustomerCertificationDetails] (
  [Id] [int] IDENTITY,
  [CustomerCertificationId] [int] NOT NULL,
  [AddressId] [int] NULL,
  [DepartmentId] [int] NULL,
  [Recertification] [smallint] NOT NULL DEFAULT (0),
  [Status] [smallint] NULL,
  [DeviationEndDate] [datetime] NULL,
  [CreatedDate] [datetime] NOT NULL DEFAULT (getutcdate()),
  [IssueDate] [datetime] NULL,
  [ExpiryDate] [datetime] NULL,
  [UpdatedByCustomer] [bit] NULL,
  [UpdatedByAuditor] [bit] NULL,
  PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_CustomerCertificationDetails_Combination] UNIQUE ([CustomerCertificationId], [AddressId], [DepartmentId], [Recertification])
)
GO

CREATE INDEX [IX_CustomerCertificationDetails_Id_Status]
  ON [SBSC].[CustomerCertificationDetails] ([Id], [Status])
  INCLUDE ([CustomerCertificationId], [DepartmentId], [AddressId], [Recertification], [UpdatedByAuditor], [UpdatedByCustomer])
GO

ALTER TABLE [SBSC].[CustomerCertificationDetails]
  ADD FOREIGN KEY ([CustomerCertificationId]) REFERENCES [SBSC].[Customer_Certifications] ([CustomerCertificationId]) ON DELETE CASCADE
GO