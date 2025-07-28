SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE VIEW [SBSC].[vw_CustomerCertificationDetails]
AS
SELECT DISTINCT 
    c.Id, c.CompanyName, c.CustomerName, c.CaseNumber, c.CaseId, c.OrgNo, c.CreatedDate, c.DefaultAuditor, c.UserType, c.RelatedCustomerId, 
    cc.CustomerCertificationId, cc.CustomerId, cc.CertificateId, ct.CertificateCode, 
    cc.CertificateNumber, cc.Validity, cc.AuditYears, cc.SubmissionStatus, cc.Recertification, cc.DeviationEndDate, 
    ao.FromDate, ao.ToDate, ao.AssignedTime, ao.Id AS AssignmentId, ccd.UpdatedByAuditor, ccd.UpdatedByCustomer, ao.LastUpdatedDate,
    
    -- Auditors
    (SELECT a.Id AS id, a.Name AS name, ac.Email AS email, ac.DefaultLangId AS defaultLangId
     FROM SBSC.Auditor a 
     JOIN SBSC.AuditorCredentials ac ON a.Id = ac.AuditorId
     WHERE a.Id IN (
         SELECT AuditorId
         FROM SBSC.AssignmentAuditor
         WHERE AssignmentId = ao.Id
     ) FOR JSON PATH) AS Auditors,
    
    -- Addresses
    (SELECT ca.Id AS id, ca.Placename AS name, ca.StreetAddress AS streestAddress, ca.PostalCode AS postalCode, ca.City AS city
     FROM SBSC.Customer_Address ca
     WHERE ca.Id IN (
         SELECT AddressId
         FROM SBSC.AssignmentAddress
         WHERE CustomerCertificationAssignmentId = acc.Id
     ) FOR JSON PATH) AS Addresses,
    
    -- Departments
    (SELECT cd.Id AS id, cd.DepartmentName AS name
     FROM SBSC.Customer_Department cd
     WHERE cd.Id IN (
         SELECT DepartmentId
         FROM SBSC.AssignmentDepartment
         WHERE CustomerCertificationAssignmentId = acc.Id
     ) FOR JSON PATH) AS Departments,
    
    -- Lead Auditor
    (SELECT a.Id AS id, a.Name AS name
     FROM SBSC.Auditor a
     WHERE a.Id IN (
         SELECT AuditorId
         FROM SBSC.AssignmentAuditor
         WHERE IsLeadAuditor = 1 AND AssignmentId = ao.Id
     ) FOR JSON PATH) AS LeadAuditor, 
    
    ct.IsAuditorInitiated, ct.Published,
    
    -- MetaData (unchanged as it doesn't depend on assignment structure)
    (SELECT COUNT(DISTINCT acr.Id) AS totalDeviations
     FROM SBSC.Customer_Certifications AS cc INNER JOIN
          SBSC.Chapter AS ch ON ch.CertificationId = cc.CertificateId INNER JOIN
          SBSC.RequirementChapters AS rc ON rc.ChapterId = ch.Id INNER JOIN
          SBSC.CustomerResponse AS cr ON cr.RequirementId = rc.RequirementId AND cr.CustomerId = cc.CustomerId INNER JOIN
          SBSC.AuditorCustomerResponses AS acr ON acr.CustomerResponseId = cr.Id
     WHERE (acr.IsApproved = 0) AND (cr.Id IN (
         SELECT TOP (1) Id
         FROM SBSC.CustomerResponse AS cr2
         WHERE (RequirementId = rc.RequirementId) AND (CustomerId = cc.CustomerId)
         ORDER BY ModifiedDate DESC
     )) FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) AS MetaData

FROM SBSC.Customer_Certifications cc 
LEFT OUTER JOIN SBSC.Customers c ON c.Id = cc.CustomerId 
LEFT OUTER JOIN SBSC.Certification ct ON ct.Id = cc.CertificateId 
LEFT OUTER JOIN SBSC.AssignmentCustomerCertification acc ON acc.CustomerCertificationId = cc.CustomerCertificationId 
LEFT OUTER JOIN SBSC.AssignmentOccasions ao ON ao.Id = acc.AssignmentId
LEFT OUTER JOIN SBSC.CustomerCertificationDetails ccd ON ccd.CustomerCertificationId = cc.CustomerCertificationId
GO