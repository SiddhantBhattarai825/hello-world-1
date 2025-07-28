CREATE TABLE [SBSC].[Chapter] (
  [Id] [int] NOT NULL,
  [Title] [nvarchar](100) NOT NULL,
  [IsVisible] [bit] NULL,
  [IsWarning] [bit] NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  [CertificationId] [int] NOT NULL,
  [DisplayOrder] [int] NULL
)
GO