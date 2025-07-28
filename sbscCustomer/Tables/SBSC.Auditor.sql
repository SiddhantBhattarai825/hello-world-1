CREATE TABLE [SBSC].[Auditor] (
  [Id] [int] NOT NULL,
  [Name] [nvarchar](500) NOT NULL,
  [IsSBSCAuditor] [bit] NOT NULL,
  [Status] [bit] NOT NULL,
  [UserType] [varchar](10) NULL
)
GO