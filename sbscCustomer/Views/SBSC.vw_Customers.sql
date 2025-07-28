SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE VIEW [SBSC].[vw_Customers]
AS
SELECT        c.Id, c.CompanyName, cred.Email, cred.DefaultLangId, c.CustomerName, c.CaseId, c.CaseNumber, ISNULL(c.OrgNo, '0') AS OrgNo, ISNULL(c.OrgNo, '0') AS VatNo, c.ContactNumber, c.ContactCellPhone, c.DefaultAuditor, 
                         c.CreatedDate, c.IsAnonymizes, cd.Certifications, cd.AssignedAuditors, cd.CertificateNumbers, cd.CustomerCertificationIds, cred.MfaStatus, cred.IsActive, cred.IsPasswordChanged, cred.PasswordChangedDate, 
                         cred.CustomerType, /* Add ChildUsers JSON array */ ISNULL
                             ((SELECT        cu.Id AS SecondaryUserId, cu.UserName, cu.Email, cu.MfaStatus, cu.DefaultLangId, cu.IsActive
                                 FROM            SBSC.CustomerCredentials cu
                                 WHERE        cu.CustomerId = c.Id AND (cu.CustomerType IS NOT NULL AND cu.CustomerType > 0) FOR JSON PATH), '[]') AS ChildUsers
FROM            SBSC.Customers c LEFT JOIN
                         SBSC.CustomerCredentials cred ON c.Id = cred.CustomerId AND (cred.CustomerType IS NULL OR
                         cred.CustomerType = 0) LEFT JOIN
                             (/* Subquery to aggregate certification data per customer*/ SELECT cc.CustomerId,
                                                             /* Build JSON array of certifications*/ (SELECT        CASE WHEN COUNT(*) = 0 THEN '[]' ELSE JSON_QUERY('[' + STRING_AGG(JSON_QUERY('{' + '"id":' + CAST(UniqueCerts.Id AS VARCHAR(20)) 
                                                                                                                                                                          + ',"customerCertificationId":' + CAST(UniqueCerts.CustomerCertificationId AS VARCHAR(20)) + ',"certificateCode":"' + REPLACE(UniqueCerts.CertificateCode, '"', 
                                                                                                                                                                          '\"') + '","certificateNumber":"' + ISNULL(UniqueCerts.CertificateNumber, '') + '","version":' + CAST(UniqueCerts.Version AS VARCHAR(20)) 
                                                                                                                                                                          + ',"published":' + CAST(UniqueCerts.Published AS VARCHAR(1)) + ',"submissionStatus":' + CAST(UniqueCerts.SubmissionStatus AS VARCHAR(10)) 
                                                                                                                                                                          + ',"certificateTypeId":' + CAST(UniqueCerts.CertificateTypeId AS VARCHAR(20)) 
                                                                                                                                                                          + ',"certificationStatus": "' + CAST(UniqueCerts.CertificationStatus AS NVARCHAR(MAX)) 
																																											+ '","certificateTypeTitle":"' + REPLACE(ISNULL(UniqueCerts.CertificationCategoryTitle, 'N/A'), '"', '\"') + '"}'), ',') + ']') END
                                                                                                                                                FROM            (/* Get distinct certifications with language-aware titles*/ SELECT DISTINCT 
                                                                                                                                                                                                    cert.Id, cc2.CustomerCertificationId, cert.CertificateCode, cc2.CertificateNumber, cert.Version, cert.Published, cc2.SubmissionStatus, 
                                                                                                                                                                                                    cert.CertificateTypeId, /* Prioritize default language, fallback to any language*/ COALESCE (ccl_default.CertificationCategoryTitle, 
                                                                                                                                                                                                    ccl_any.CertificationCategoryTitle, 'N/A') AS CertificationCategoryTitle,
																																																	CASE 
																																																		WHEN ccred.IsActive = 0 THEN 'Not Activated'
																																																		ELSE
																																																			--CASE 
																																																				--WHEN cc2.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
																																																				--THEN
																																																						CASE
																																																							WHEN cc2.SubmissionStatus = 1 THEN 'Pending'
																																																							WHEN cc2.SubmissionStatus = 2 THEN 'Deviation'
																																																							WHEN cc2.SubmissionStatus = 3 THEN 'Report'
																																																							WHEN cc2.SubmissionStatus = 4 THEN 'Passed'
																																																							WHEN cc2.SubmissionStatus = 5 THEN 'Rejected'
																																																							WHEN cc2.SubmissionStatus = 6 THEN 'Passed with conditions'
																																																							WHEN cc2.SubmissionStatus = 11 THEN 'Upcoming'
																																																							WHEN cc2.SubmissionStatus = 12 THEN 'Planned'
																																																							WHEN cc2.SubmissionStatus = 13 THEN 'Booked'
																																																							ELSE 'Not Submitted'
																																																						END
																																																				--ELSE ''Not Submitted''
																																																			--END
																																														END AS CertificationStatus
                                                                                                                                                                          FROM            SBSC.Customer_Certifications cc2 LEFT JOIN
																																																	SBSC.CustomerCredentials ccred ON ccred.CustomerId = cc2.CustomerId LEFT JOIN
                                                                                                                                                                                                    SBSC.Certification cert ON cc2.CertificateId = cert.Id LEFT JOIN
                                                                                                                                                                                                    SBSC.CertificationCategory ccg ON cert.CertificateTypeId = ccg.Id /* Get title for the default language*/ LEFT JOIN
                                                                                                                                                                                                    SBSC.CertificationCategoryLanguage ccl_default ON ccg.Id = ccl_default.CertificationCategoryId AND ccl_default.LanguageId =
                                                                                                                                                                                                        (SELECT        TOP 1 Id
                                                                                                                                                                                                          FROM            SBSC.Languages
                                                                                                                                                                                                          WHERE        IsDefault = 1) /* Fallback to any language if default is missing*/ OUTER APPLY
                                                                                                                                                                                                        (SELECT        TOP 1 CertificationCategoryTitle
                                                                                                                                                                                                          FROM            SBSC.CertificationCategoryLanguage ccl_any
                                                                                                                                                                                                          WHERE        ccl_any.CertificationCategoryId = ccg.Id
                                                                                                                                                                                                          ORDER BY CASE WHEN ccl_any.LanguageId =
                                                                                                                                                                                                                                        (SELECT        TOP 1 Id
                                                                                                                                                                                                                                          FROM            SBSC.Languages
                                                                                                                                                                                                                                          WHERE        IsDefault = 1) THEN 0 ELSE 1 END) AS ccl_any
                                                                                                                                                                          WHERE        cc2.CustomerId = cc.CustomerId) AS UniqueCerts) AS Certifications,
                                                             /* Aggregate certificate numbers*/ (SELECT        STRING_AGG(ISNULL(CertificateNumber, '0'), ',') WITHIN GROUP (ORDER BY CertificateNumber)
                               FROM            (SELECT DISTINCT cc2.CertificateNumber
                                                         FROM            SBSC.Customer_Certifications cc2
                                                         WHERE        cc2.CustomerId = cc.CustomerId) AS UniqueCertNumbers) AS CertificateNumbers,
                             /* Aggregate assigned auditors*/ (SELECT        STRING_AGG(AuditorName, ',') WITHIN GROUP (ORDER BY AuditorName)
FROM            (SELECT DISTINCT a.Name AS AuditorName
                          FROM            SBSC.AssignmentOccasions ao INNER JOIN
                                                    SBSC.AssignmentAUditor aa ON ao.Id = aa.AssignmentId INNER JOIN
                                                    SbSC.Auditor a ON a.Id = aa.AuditorId
                          WHERE        ao.CustomerId = cc.CustomerId) AS UniqueAuditors) AS AssignedAuditors,
    /* Aggregate customer certification IDs*/ (SELECT        STRING_AGG(CAST(CustomerCertificationId AS VARCHAR), ',') WITHIN GROUP (ORDER BY CustomerCertificationId)
FROM            (SELECT DISTINCT cc2.CustomerCertificationId
                          FROM            SBSC.Customer_Certifications cc2
                          WHERE        cc2.CustomerId = cc.CustomerId) AS UniqueCertificationIds) AS CustomerCertificationIds
FROM            SBSC.Customer_Certifications cc
GROUP BY cc.CustomerId) AS cd ON c.Id = cd.CustomerId;
GO