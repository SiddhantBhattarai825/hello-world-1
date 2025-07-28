CREATE TABLE [SBSC].[CertificationCategory] (
  [Id] [int] IDENTITY,
  [Title] [nvarchar](100) NOT NULL,
  [IsVisible] [int] NULL,
  [IsActive] [int] NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO