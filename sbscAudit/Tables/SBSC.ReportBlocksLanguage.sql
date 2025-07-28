CREATE TABLE [SBSC].[ReportBlocksLanguage] (
  [Id] [int] IDENTITY,
  [ReportBlockId] [int] NOT NULL,
  [Headlines] [nvarchar](255) NULL,
  [LangId] [int] NOT NULL,
  CONSTRAINT [PK__ReportBl__3214EC07FE0477C5] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IDX_ReportBlocksLanguage_ReportBlockId_LangId]
  ON [SBSC].[ReportBlocksLanguage] ([ReportBlockId], [LangId])
GO

ALTER TABLE [SBSC].[ReportBlocksLanguage]
  ADD CONSTRAINT [FK_ReportBlocksLanguage_LangId] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[ReportBlocksLanguage]
  ADD CONSTRAINT [FK_ReportBlocksLanguage_ReportBlockId] FOREIGN KEY ([ReportBlockId]) REFERENCES [SBSC].[ReportBlocks] ([Id]) ON DELETE CASCADE
GO