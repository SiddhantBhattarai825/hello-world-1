CREATE TABLE [SBSC].[CustomerCertificationDetails] (
  [Id] [int] NOT NULL,
  [CustomerCertificationId] [int] NOT NULL,
  [AddressId] [int] NULL,
  [DepartmentId] [int] NULL,
  [Recertification] [smallint] NOT NULL,
  [Status] [smallint] NULL,
  [DeviationEndDate] [datetime] NULL,
  [CreatedDate] [datetime] NOT NULL,
  [IssueDate] [datetime] NULL,
  [ExpiryDate] [datetime] NULL
)
GO