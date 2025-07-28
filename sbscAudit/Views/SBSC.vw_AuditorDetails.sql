SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE VIEW [SBSC].[vw_AuditorDetails]
AS
SELECT A.Id, A.IsSBSCAuditor, A.Name, AC.Email, AC.IsActive, AC.IsPasswordChanged, 
       AC.PasswordChangedDate, A.Status, A.CreatedDate, AC.MfaStatus, AC.DefaultLangId, 
       cert_1.Certifications,
       STUFF((
           SELECT DISTINCT ',' + cc.Title
           FROM SBSC.Auditor_Certifications AS ac 
           INNER JOIN SBSC.Certification AS c ON ac.CertificationId = c.Id 
           INNER JOIN SBSC.CertificationCategory AS cc ON c.CertificateTypeId = cc.Id
           WHERE ac.AuditorId = A.Id
           FOR XML PATH('')
       ), 1, 1, '') AS CertificationTypes,
       STUFF((
           SELECT ',' + CAST(c.Id AS VARCHAR(20))
           FROM SBSC.Customer_Auditors AS ca 
           INNER JOIN SBSC.Customers AS c ON ca.CustomerId = c.Id
           WHERE ca.AuditorId = A.Id
           FOR XML PATH('')
       ), 1, 1, '') AS AssignedCustomers
FROM SBSC.Auditor AS A 
INNER JOIN SBSC.AuditorCredentials AS AC ON A.Id = AC.AuditorId 
LEFT OUTER JOIN (
    SELECT 
        ac.AuditorId,
        CASE 
            WHEN NOT EXISTS (
                SELECT 1 
                FROM SBSC.Auditor_Certifications ac2 
                WHERE ac2.AuditorId = ac.AuditorId
            ) THEN '[]'
            ELSE (
                SELECT '[' + STUFF((
                    SELECT 
                        ',' + '{' +
                        '"id":' + CAST(cert.Id AS VARCHAR(20)) + 
                        ',"certificateCode":"' + REPLACE(cert.CertificateCode, '"', '\"') + '"' +
                        ',"version":' + CAST(cert.Version AS VARCHAR(20)) +
                        ',"published":' + CAST(cert.Published AS VARCHAR(1)) +
						',"certificationTypeId":' + CAST(cc.Id AS VARCHAR(5)) +
                        ',"certificationType":"' + cc.Title + '"' +
                        '}'
                    FROM SBSC.Auditor_Certifications ac2
                    INNER JOIN SBSC.Certification cert ON ac2.CertificationId = cert.Id
                    INNER JOIN SBSC.CertificationCategory cc ON cert.CertificateTypeId = cc.Id
                    WHERE ac2.AuditorId = ac.AuditorId
                    FOR XML PATH('')
                ), 1, 1, '') + ']'
            )
        END AS Certifications
    FROM SBSC.Auditor_Certifications ac
    GROUP BY ac.AuditorId
) cert_1 ON A.Id = cert_1.AuditorId
GO