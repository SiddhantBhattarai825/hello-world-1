SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE   VIEW [SBSC].[vw_ReportDetails]
AS
SELECT 
    rb.Id, 
    rb.DisplayOrder, 
    rbl.Headlines, 
    rbl.LangId, 
    rb.IsDefault,
    (
        SELECT 
            CASE 
                WHEN COUNT(*) = 0 THEN NULL
                ELSE (
                    SELECT 
                        c.Id as CertificationId,
                        c.CertificateCode as CertificationCode,
                        c.CertificateTypeId as CertificationTypeId,
                        ccl.CertificationCategoryTitle as CertificationType,
                        c.Validity as Validity
                    FROM SBSC.ReportBlocksCertifications rbc
                    INNER JOIN SBSC.Certification c ON rbc.CertificationId = c.Id
                    INNER JOIN SBSC.CertificationCategory cc ON c.CertificateTypeId = cc.Id
                    INNER JOIN SBSC.CertificationCategoryLanguage ccl ON cc.Id = ccl.CertificationCategoryId
                    WHERE rbc.ReportBlockId = rb.Id 
                    AND ccl.LanguageId = rbl.LangId
                    AND c.IsActive = 1
                    FOR JSON PATH
                )
            END
    ) AS CertificationsJson
FROM SBSC.ReportBlocks rb
INNER JOIN SBSC.ReportBlocksLanguage rbl ON rb.Id = rbl.ReportBlockId
GO