SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE   FUNCTION [SBSC].[GetChapterDisplayOrderHistory]
(
    @ChapterId INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @Result NVARCHAR(MAX)

    ;WITH ChapterHierarchy AS (
        -- Base case: start with the given chapter
        SELECT 
            Id,
            ParentChapterId,
            DisplayOrder,
            CAST(DisplayOrder AS NVARCHAR(MAX)) AS DisplayOrderPath,
            Level
        FROM [SBSC].[Chapter]
        WHERE Id = @ChapterId

        UNION ALL

        -- Recursive case: get parent chapters
        SELECT 
            c.Id,
            c.ParentChapterId,
            c.DisplayOrder,
            CAST(c.DisplayOrder AS NVARCHAR(MAX)) + '.' + ch.DisplayOrderPath,
            c.Level
        FROM [SBSC].[Chapter] c
        INNER JOIN ChapterHierarchy ch ON c.Id = ch.ParentChapterId
    )
    SELECT TOP 1 @Result = DisplayOrderPath
    FROM ChapterHierarchy
    WHERE Level = (SELECT MIN(Level) FROM ChapterHierarchy)

    RETURN @Result
END
GO