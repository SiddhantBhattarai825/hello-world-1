SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE VIEW [SBSC].[vw_CertificationCategoryDetails]
AS
SELECT 
    c.Id AS CertificationCategoryId, 
    c.Title, 
    c.IsActive, 
    c.IsVisible, 
    c.AddedDate, 
    c.AddedBy, 
    cl.LanguageId, 
    l.LanguageName AS LanguageTitle, 
    cl.CertificationCategoryTitle, 
    l.LanguageCode
FROM 
    SBSC.CertificationCategory AS c 
INNER JOIN 
    SBSC.CertificationCategoryLanguage AS cl ON c.Id = cl.CertificationCategoryId 
INNER JOIN 
    SBSC.Languages AS l ON cl.LanguageId = l.Id;
GO