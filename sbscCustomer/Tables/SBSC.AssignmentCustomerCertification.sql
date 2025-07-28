CREATE TABLE [SBSC].[AssignmentCustomerCertification] (
  [Id] [int] IDENTITY,
  [CustomerCertificationId] [int] NULL,
  [Recertification] [int] NULL,
  [AssignmentId] [int] NULL,
  [CustomerCertificationDetailsId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_AssignmentCustomerCertification_AssignmentId]
  ON [SBSC].[AssignmentCustomerCertification] ([AssignmentId])
  INCLUDE ([CustomerCertificationDetailsId], [CustomerCertificationId])
GO

ALTER TABLE [SBSC].[AssignmentCustomerCertification]
  ADD FOREIGN KEY ([CustomerCertificationId]) REFERENCES [SBSC].[Customer_Certifications] ([CustomerCertificationId]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[AssignmentCustomerCertification]
  ADD CONSTRAINT [FK_AssignmentCustomerCertification_AssignmentOccasions] FOREIGN KEY ([AssignmentId]) REFERENCES [SBSC].[AssignmentOccasions] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[AssignmentCustomerCertification] WITH NOCHECK
  ADD CONSTRAINT [FK_AssignmentCustomerCertification_CustomerCertificationDetails] FOREIGN KEY ([CustomerCertificationDetailsId]) REFERENCES [SBSC].[CustomerCertificationDetails] ([Id])
GO