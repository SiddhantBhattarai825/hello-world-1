CREATE TABLE [SBSC].[RequirementType] (
  [Id] [int] IDENTITY,
  [IsVisible] [int] NULL,
  [IsActive] [int] NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  [Name] [nvarchar](100) NOT NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO