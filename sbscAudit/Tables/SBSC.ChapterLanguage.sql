CREATE TABLE [SBSC].[ChapterLanguage] (
  [Id] [int] IDENTITY,
  [ChapterId] [int] NOT NULL,
  [ChapterTitle] [nvarchar](500) NULL,
  [ChapterDescription] [nvarchar](max) NULL,
  [LanguageId] [int] NOT NULL,
  [ModifiedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__ChapterL__3214EC27C0D39319] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[ChapterLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_ChapterLanguage_Chapter] FOREIGN KEY ([ChapterId]) REFERENCES [SBSC].[Chapter] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[ChapterLanguage] WITH NOCHECK
  ADD CONSTRAINT [FK_ChapterLanguage_LanguageId] FOREIGN KEY ([LanguageId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE CASCADE
GO