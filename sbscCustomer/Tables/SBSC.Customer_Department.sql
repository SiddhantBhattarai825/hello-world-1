CREATE TABLE [SBSC].[Customer_Department] (
  [Id] [int] IDENTITY,
  [CustomerId] [int] NOT NULL,
  [DepartmentName] [nvarchar](500) NOT NULL,
  [Remarks] [nvarchar](max) NULL,
  CONSTRAINT [PK_Customer_Department] PRIMARY KEY CLUSTERED ([Id])
)
GO