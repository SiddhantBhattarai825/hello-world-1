SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_DeviationFeedUpdates_CRUD]
    @Action NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
	-- Create new customer response
    IF @Action = 'COMMENT_COUNT_CHECK'
	BEGIN
		SELECT 
			CertificationId,
			CertificateCode,
			CertificationName,
			CustomerId,
			AuditorId,
			TotalCount,
			CustomerEmail,
			CustomerDefaultLangId,
			AuditorEmails,
			CompanyName
		FROM (
			SELECT DISTINCT
				c.CertificationId,
				cert.CertificateCode,
				certLang.CertificationName,
				ct.CustomerId,
				ct.AuditorId,
				CASE WHEN ct.AuditorId IS NULL
				THEN
				(SELECT COUNT(*) FROM SBSC.CommentThread WHERE AuditorId IS NULL AND CustomerId = ct.CustomerId AND RequirementId IN (SELECT RequirementId FROM SBSC.RequirementChapters
				 WHERE ChapterId IN (SELECT Id FROM SBSC.Chapter WHERE CertificationId = c.CertificationId)) AND CreatedDate BETWEEN DATEADD(HOUR, -24, GETUTCDATE()) AND GETUTCDATE())
				ELSE
				(SELECT COUNT(*) FROM SBSC.CommentThread WHERE AuditorId IS NOT NULL AND AuditorId = ct.AuditorId AND RequirementId IN (SELECT RequirementId FROM SBSC.RequirementChapters
				 WHERE ChapterId IN (SELECT Id FROM SBSC.Chapter WHERE CertificationId = c.CertificationId)) AND CreatedDate BETWEEN DATEADD(HOUR, -24, GETUTCDATE()) AND GETUTCDATE())
				END AS TotalCount,
				cc.Email AS CustomerEmail,
				cc.DefaultLangId AS CustomerDefaultLangId,
				CASE WHEN ct.AuditorId IS NULL 
				THEN 
					(SELECT DISTINCT
						ac_multi.Email as auditorEmail,
						a_multi.Name as auditorName,
						ac_multi.DefaultLangId as defaultLangId
					FROM SBSC.AssignmentAuditor aa
					INNER JOIN SBSC.AssignmentOccasions ao ON aa.AssignmentId = ao.Id
					INNER JOIN SBSC.AssignmentCustomerCertification acc ON ao.Id = acc.AssignmentId
					INNER JOIN SBSC.Customer_Certifications cc_cert ON acc.CustomerCertificationId = cc_cert.CustomerCertificationId
					INNER JOIN SBSC.AuditorCredentials ac_multi ON ac_multi.AuditorId = aa.AuditorId
					INNER JOIN SBSC.Auditor a_multi ON a_multi.Id = aa.AuditorId
					WHERE ao.CustomerId = ct.CustomerId AND cc_cert.CertificateId = c.CertificationId
					FOR JSON PATH)
				ELSE 
					(SELECT DISTINCT
						ac.Email as auditorEmail,
						a.Name as auditorName,
						ac.DefaultLangId as defaultLangId
					FOR JSON PATH)
				END AS AuditorEmails,
				customer.CompanyName
			FROM SBSC.CommentThread ct
			LEFT JOIN SBSC.RequirementChapters rc ON rc.RequirementId = ct.RequirementId
			LEFT JOIN SBSC.Chapter c ON c.Id = rc.ChapterId
			LEFT JOIN SBSC.Certification cert ON c.CertificationId = cert.Id
			LEFT JOIN SBSC.CertificationLanguage certLang ON cert.Id = certLang.CertificationId
			LEFT JOIN SBSC.AuditorCredentials ac ON ac.AuditorId = ct.AuditorId
			LEFT JOIN SBSC.Auditor a ON ac.AuditorId = a.Id
			LEFT JOIN SBSC.CustomerCredentials cc ON cc.CustomerId = ct.CustomerId
			LEFT JOIN SBSC.Customers customer ON ct.CustomerId = customer.Id
			WHERE ct.CreatedDate BETWEEN DATEADD(HOUR, -24, GETUTCDATE()) AND GETUTCDATE()
			AND certLang.LangId = 2

			UNION ALL

			SELECT DISTINCT
				dc.CertificationId,
				cert.CertificateCode,
				certLang.CertificationName,
				dct.CustomerId,
				dct.AuditorId,
				CASE WHEN dct.AuditorId IS NULL
				THEN
				(SELECT COUNT(*) FROM SBSC.DocumentCommentThread WHERE AuditorId IS NULL AND CustomerId = dct.CustomerId AND DocumentId IN (SELECT DocId FROM SBSC.DocumentsCertifications
				 WHERE CertificationId = dc.CertificationId) AND CreatedDate BETWEEN DATEADD(HOUR, -24, GETUTCDATE()) AND GETUTCDATE())
				ELSE
				(SELECT COUNT(*) FROM SBSC.DocumentCommentThread WHERE AuditorId IS NOT NULL AND AuditorId = dct.AuditorId AND DocumentId IN (SELECT DocId FROM SBSC.DocumentsCertifications
				 WHERE CertificationId = dc.CertificationId) AND CreatedDate BETWEEN DATEADD(HOUR, -24, GETUTCDATE()) AND GETUTCDATE())
				END AS TotalCount,
				cc.Email AS CustomerEmail,
				cc.DefaultLangId AS CustomerDefaultLangId,
				CASE WHEN dct.AuditorId IS NULL 
				THEN 
					(SELECT DISTINCT
						ac_multi.Email as auditorEmail,
						a_multi.Name as auditorName,
						ac_multi.DefaultLangId as defaultLangId
					FROM SBSC.AssignmentAuditor aa
					INNER JOIN SBSC.AssignmentOccasions ao ON aa.AssignmentId = ao.Id
					INNER JOIN SBSC.AssignmentCustomerCertification acc ON ao.Id = acc.AssignmentId
					INNER JOIN SBSC.Customer_Certifications cc_cert ON acc.CustomerCertificationId = cc_cert.CustomerCertificationId
					INNER JOIN SBSC.AuditorCredentials ac_multi ON ac_multi.AuditorId = aa.AuditorId
					INNER JOIN SBSC.Auditor a_multi ON a_multi.Id = aa.AuditorId
					WHERE ao.CustomerId = dct.CustomerId AND cc_cert.CertificateId = dc.CertificationId
					FOR JSON PATH)
				ELSE 
					(SELECT DISTINCT
						ac.Email as auditorEmail,
						a.Name as auditorName,
						ac.DefaultLangId as defaultLangId
					FOR JSON PATH)
				END AS AuditorEmails,
				customer.CompanyName
			FROM SBSC.DocumentCommentThread dct
			LEFT JOIN SBSC.DocumentsCertifications dc ON dc.DocId = dct.DocumentId
			LEFT JOIN SBSC.Certification cert ON dc.CertificationId = cert.Id
			LEFT JOIN SBSC.CertificationLanguage certLang ON cert.Id = certLang.CertificationId
			LEFT JOIN SBSC.AuditorCredentials ac ON ac.AuditorId = dct.AuditorId
			LEFT JOIN SBSC.Auditor a ON ac.AuditorId = a.Id
			LEFT JOIN SBSC.CustomerCredentials cc ON cc.CustomerId = dct.CustomerId
			LEFT JOIN SBSC.Customers customer ON dct.CustomerId = customer.Id
			WHERE dct.CreatedDate BETWEEN DATEADD(HOUR, -24, GETUTCDATE()) AND GETUTCDATE()
			AND certLang.LangId = 2

		) AS CombinedData

	END
END
GO