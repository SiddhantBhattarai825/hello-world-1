SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SBSC].[vw_EmailTemplateDetails]
AS
SELECT        et.Id AS EmailTemplateId, et.Title AS TemplateTitle, et.Description AS TemplateDescription, et.EmailCode, et.IsActive, et.Tags AS TemplateTags, et.AddedDate, et.AddedBy, etl.LangId AS LanguageId, 
                         l.LanguageName AS LanguageTitle, etl.EmailBody, etl.EmailSubject, l.LanguageCode, et.ExpiryTime
FROM            SBSC.EmailTemplate AS et INNER JOIN
                         SBSC.EmailTemplateLanguage AS etl ON et.Id = etl.EmailTemplateId INNER JOIN
                         SBSC.Languages AS l ON etl.LangId = l.Id
GO