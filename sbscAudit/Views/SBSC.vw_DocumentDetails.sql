SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE VIEW [SBSC].[vw_DocumentDetails]
AS
SELECT        d.Id AS DocumentId, dc.CertificationId, c.CertificateCode, dc.DisplayOrder, q.Name AS QuestionType, d.IsVisible, dc.IsWarning, d.AddedBy, d.AddedDate, d.ModifiedBy, d.ModifiedDate,
			dl.Headlines, dl.Description, l.Id AS LangId, l.LanguageName, d.UserRole, d.Version, d.IsFileUploadable, d.IsFileUploadRequired, d.IsCommentable
FROM            SBSC.Documents AS d 
						LEFT OUTER JOIN
                         SBSC.DocumentLanguage AS dl ON d.Id = dl.DocId 
						INNER JOIN  SBSC.DocumentsCertifications dc ON dc.DocId = dl.DocId
						INNER JOIN [SBSC].[Certification] c ON dc.CertificationId = c.Id
						LEFT OUTER JOIN
                         SBSC.Languages AS l ON dl.LangId = l.Id LEFT OUTER JOIN
                         SBSC.RequirementType AS q ON d.RequirementTypeId = q.Id
GO