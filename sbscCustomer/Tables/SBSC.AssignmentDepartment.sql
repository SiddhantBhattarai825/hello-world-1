CREATE TABLE [SBSC].[AssignmentDepartment] (
  [Id] [int] IDENTITY,
  [DepartmentId] [int] NULL,
  [CustomerCertificationAssignmentId] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AssignmentDepartment]
  ADD FOREIGN KEY ([DepartmentId]) REFERENCES [SBSC].[Customer_Department] ([Id])
GO