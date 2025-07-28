CREATE TABLE [SBSC].[ReportBlocks] (
  [Id] [int] IDENTITY,
  [DisplayOrder] [int] NOT NULL,
  [IsDefault] [bit] NOT NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__ReportBl__3214EC07EBF41F2B] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IDX_ReportBlocks_DisplayOrder]
  ON [SBSC].[ReportBlocks] ([DisplayOrder])
GO