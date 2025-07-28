SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SBSC].[fn_GetChapterTree]
(
    @ParentChapterId INT,
    @LangId INT
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @json NVARCHAR(MAX);

    SELECT @json =
    (
        SELECT
            c.Id AS ChapterId,
            cl.ChapterTitle,
            cl.ChapterDescription,
            c.DisplayOrder,
            [Level] AS [Level],
            c.IsWarning,
            c.IsVisible,
            c.ParentChapterId,
            c.CertificationId,
            --c.CertificateCode,
            JSON_QUERY(SBSC.fn_GetChapterTree(c.Id, @LangId)) AS Sections
        FROM SBSC.Chapter AS c
        LEFT JOIN SBSC.ChapterLanguage AS cl
            ON cl.ChapterId = c.Id AND cl.LanguageId = @LangId
        WHERE c.ParentChapterId = @ParentChapterId
        ORDER BY c.DisplayOrder
        FOR JSON PATH
    );

    RETURN ISNULL(@json, '[]');
END;
GO