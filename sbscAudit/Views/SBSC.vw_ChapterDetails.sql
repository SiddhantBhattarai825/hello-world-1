SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SBSC].[vw_ChapterDetails]
AS
SELECT        c.Id AS ChapterId, c.Title, c.IsWarning, c.IsVisible, c.AddedDate, c.AddedBy, cl.LanguageId, l.LanguageName AS LanguageTitle, cl.ChapterTitle, cl.ChapterDescription, l.LanguageCode, c.CertificationId, cert.CertificateCode, 
                         c.DisplayOrder
FROM            SBSC.Chapter AS c INNER JOIN
                         SBSC.ChapterLanguage AS cl ON c.Id = cl.ChapterId INNER JOIN
                         SBSC.Languages AS l ON cl.LanguageId = l.Id INNER JOIN
                         SBSC.Certification AS cert ON c.CertificationId = cert.Id
GO