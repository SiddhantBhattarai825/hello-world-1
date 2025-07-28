CREATE TABLE [SBSC].[RequirementTypeOption] (
  [Id] [int] IDENTITY,
  [RequirementTypeId] [int] NOT NULL,
  [IsVisible] [int] NULL,
  [IsActive] [int] NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  [Score] [decimal](5, 2) NOT NULL DEFAULT (0),
  [DisplayOrder] [int] NOT NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([Id])
)
GO