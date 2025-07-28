SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE VIEW [SBSC].[vw_CertificationDetails]
AS
SELECT C.Id AS CertificationId, 
       C.CertificateTypeId, 
       CC.Title AS CertificationType, 
       C.CertificateCode, 
       C.Validity, 
       C.IsActive, 
       C.IsVisible, 
       C.AddedDate, 
       C.AddedBy, 
       C.ModifiedDate, 
       C.ModifiedBy, 
       CL.LangId, 
       L.LanguageName, 
       CL.CertificationName, 
       C.AuditYears, 
       C.Version, 
       C.IsAuditorInitiated, 
       CL.Description, 
       CL.Published, 
       CL.PublishedDate, 
       (
           SELECT '[' + 
           STUFF(
               (
                   SELECT ',' + 
                   JSON_QUERY(
                       '{"langId":' + CAST(CL2.LangId AS VARCHAR(20)) + 
                       ',"language":"' + REPLACE(L2.LanguageName, '"', '\"') + 
                       '","Published":' + CAST(CL2.Published AS VARCHAR(1)) +
					   ',"isActive":' + CASE WHEN L2.IsActive = 1 THEN 'true' ELSE 'false' END +
                       '}'
                   )
                   FROM SBSC.CertificationLanguage AS CL2 
                   INNER JOIN SBSC.Languages AS L2 ON CL2.LangId = L2.Id 
                   WHERE CL2.CertificationId = C.Id 
                   FOR XML PATH('')
               ), 1, 1, ''
           ) + 
           ']'
       ) AS LanguagePublicationStatus
FROM SBSC.Certification AS C 
INNER JOIN SBSC.CertificationLanguage AS CL ON C.Id = CL.CertificationId 
INNER JOIN SBSC.CertificationCategory AS CC ON C.CertificateTypeId = CC.Id 
INNER JOIN SBSC.Languages AS L ON CL.LangId = L.Id
GO