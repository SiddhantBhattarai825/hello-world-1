CREATE TABLE [SBSC].[RequirementChapters] (
  [Id] [int] NOT NULL,
  [RequirementId] [int] NULL,
  [ChapterId] [int] NULL,
  [ReferenceNo] [nvarchar](50) NULL,
  [IsWarning] [bit] NULL,
  [DispalyOrder] [int] NULL
)
GO