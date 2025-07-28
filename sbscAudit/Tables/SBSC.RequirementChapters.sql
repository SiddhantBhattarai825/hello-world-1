CREATE TABLE [SBSC].[RequirementChapters] (
  [Id] [int] IDENTITY,
  [RequirementId] [int] NOT NULL,
  [ChapterId] [int] NOT NULL,
  [ReferenceNo] [nvarchar](50) NULL,
  [IsWarning] [bit] NULL,
  [DispalyOrder] [int] NULL,
  PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_RequirementChapters_RequirementId_ChapterId] UNIQUE ([RequirementId], [ChapterId])
)
GO

CREATE INDEX [IX_RequirementChapters_ChapterId]
  ON [SBSC].[RequirementChapters] ([ChapterId])
GO

CREATE INDEX [IX_RequirementChapters_RequirementId]
  ON [SBSC].[RequirementChapters] ([RequirementId])
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[TRG_RequirementChapters_ValidateChapter]
ON [SBSC].[RequirementChapters]
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN SBSC.Chapter ch ON ch.Id = i.ChapterId
        WHERE ch.ParentChapterId IS NULL -- Root chapters only
          AND ch.hasChildSections = 1
    )
    BEGIN
        RAISERROR('Requirements cannot be assigned to chapters with subsections.', 16, 1);
        ROLLBACK TRANSACTION;
    END;
END;
GO

ALTER TABLE [SBSC].[RequirementChapters] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementChapters_Chapter] FOREIGN KEY ([ChapterId]) REFERENCES [SBSC].[Chapter] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[RequirementChapters] WITH NOCHECK
  ADD CONSTRAINT [FK_RequirementChapters_Requirement] FOREIGN KEY ([RequirementId]) REFERENCES [SBSC].[Requirement] ([Id]) ON DELETE CASCADE
GO