CREATE TABLE [SBSC].[AssignmentAddress] (
  [Id] [int] IDENTITY,
  [AddressId] [int] NULL,
  [CustomerCertificationAssignmentId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AssignmentAddress]
  ADD CONSTRAINT [FK__Assignmen__Addre__35DCF99B] FOREIGN KEY ([AddressId]) REFERENCES [SBSC].[Customer_Address] ([Id])
GO