CREATE TABLE [SBSC].[Chapter] (
  [Id] [int] IDENTITY,
  [Title] [nvarchar](100) NOT NULL,
  [IsVisible] [bit] NULL,
  [IsWarning] [bit] NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  [CertificationId] [int] NOT NULL,
  [DisplayOrder] [int] NOT NULL DEFAULT (1),
  [ParentChapterId] [int] NULL,
  [HasChildSections] [bit] NOT NULL DEFAULT (0),
  [Level] [int] NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__Chapter__3214EC072E449A94] PRIMARY KEY CLUSTERED ([Id])
)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[TRG_Chapter_UpdateHasChildSections]
ON [SBSC].[Chapter]
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    -- Update parent's hasChildSections when a child is added/deleted
    UPDATE c
    SET hasChildSections = CASE 
        WHEN EXISTS (SELECT 1 FROM SBSC.Chapter child WHERE child.ParentChapterId = c.Id) THEN 1 
        ELSE 0 
    END
    FROM SBSC.Chapter c
    INNER JOIN inserted i ON c.Id = i.ParentChapterId;
END;
GO

ALTER TABLE [SBSC].[Chapter] WITH NOCHECK
  ADD CONSTRAINT [FK_Chapter_Certification] FOREIGN KEY ([CertificationId]) REFERENCES [SBSC].[Certification] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[Chapter] WITH NOCHECK
  ADD CONSTRAINT [FK_Chapter_ParentChapter] FOREIGN KEY ([ParentChapterId]) REFERENCES [SBSC].[Chapter] ([Id])
GO