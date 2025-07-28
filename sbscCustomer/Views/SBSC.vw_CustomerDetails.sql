SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SBSC].[vw_CustomerDetails]
AS
SELECT 
    C.Id, 
    C.CompanyName, 
    C.CustomerName, 
    C.CaseId, 
    C.OrgNo, 
    C.CreatedDate, 
    CC.Email, 
    CC.Password, 
    CC.IsPasswordChanged, 
    CC.PasswordChangedDate, 
    CC.MfaStatus, 
    CC.IsActive, 
    C.DefaultAuditor, 
    -- Concatenate the auditor names from the Auditor table
    STUFF(
        (SELECT DISTINCT ', ' + A.Name
         FROM SBSC.Customer_Auditor_Departments CAD
         INNER JOIN SBSC.Auditor A ON CAD.AuditorId = A.Id
         WHERE CAD.CustomerId = C.Id FOR XML PATH('')), 1, 2, '') AS AssignedAuditors,
    -- Concatenate the certificate codes
    STUFF(
        (SELECT DISTINCT ', ' + CAD.CertificateCode
         FROM SBSC.Customer_Auditor_Departments CAD
         WHERE CAD.CustomerId = C.Id FOR XML PATH('')), 1, 2, '') AS Certifications
FROM 
    SBSC.Customers C 
INNER JOIN 
    SBSC.CustomerCredentials CC ON C.Id = CC.CustomerId
GROUP BY 
    C.Id, C.CompanyName, C.CustomerName, C.CaseId, C.OrgNo, C.CreatedDate, 
    CC.Email, CC.Password, CC.IsPasswordChanged, CC.PasswordChangedDate, 
    CC.MfaStatus, CC.IsActive, C.DefaultAuditor;
GO