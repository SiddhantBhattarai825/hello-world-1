SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_CustomerAllDocuments]
    @Action NVARCHAR(20),
    @CustomerId INT = NULL,
    @AuditorId INT = NULL,
    @CertificationId INT = NULL,
    @BasicDocId INT = NULL,
    @RequirementId INT = NULL,
    @AddedDate DATETIME = NULL,
    @Status NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'AddedDate',
    @SortDirection NVARCHAR(4) = 'DESC',
    @LangId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Enable parallelism for better performance
    SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

    IF @Action = 'LIST'
    BEGIN
        -- Pre-calculate variables to avoid repeated lookups
        DECLARE @DefaultLangId INT;
        SELECT @DefaultLangId = Id FROM SBSC.Languages WHERE IsDefault = 1;
        SET @LangId = ISNULL(@LangId, @DefaultLangId);

        -- Validate parameters
        IF @SortColumn NOT IN ('Id', 'AddedDate') SET @SortColumn = 'AddedDate';
        IF @SortDirection NOT IN ('ASC', 'DESC') SET @SortDirection = 'DESC';
        IF @AuditorId IS NULL AND @CustomerId IS NULL
        BEGIN
            RAISERROR('Either AuditorId or CustomerId must be provided.', 16, 1);
            RETURN;
        END
        
        -- Check auditor type once
        DECLARE @IsSBSCAuditor BIT = 0;
        IF @AuditorId IS NOT NULL
        BEGIN
            SELECT @IsSBSCAuditor = ISNULL(IsSBSCAuditor, 0) 
            FROM SBSC.Auditor 
            WHERE Id = @AuditorId;
        END

        -- Pre-filter customer assignments for non-SBSC auditors
        DECLARE @CustomerIds TABLE (CustomerId INT PRIMARY KEY);
        DECLARE @UseCustomerFilter BIT = 0;
        
        IF @IsSBSCAuditor = 0 AND @AuditorId IS NOT NULL
        BEGIN
            INSERT INTO @CustomerIds (CustomerId)
            SELECT DISTINCT ao.CustomerId
            FROM SBSC.AssignmentOccasions ao
            INNER JOIN SBSC.AssignmentAuditor aa ON ao.Id = aa.AssignmentId
            WHERE aa.AuditorId = @AuditorId;
            SET @UseCustomerFilter = 1;
        END
        ELSE IF @CustomerId IS NOT NULL
        BEGIN
            INSERT INTO @CustomerIds (CustomerId) VALUES (@CustomerId);
            SET @UseCustomerFilter = 1;
        END

        -- Calculate pagination
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

        -- Single optimized query with better joins
        ;WITH DocumentData AS (
            -- Basic Documents
            SELECT 
                dct.Id,
                du.Id AS DocumentId,
                dct.Recertification,
                CASE 
                    WHEN dct.Recertification > 0 THEN
                        ISNULL((
                            SELECT TOP 1 YEAR(AuditDate)
                            FROM [SBSC].[CustomerRecertificationAudits]
                            WHERE CustomerCertificationId = cc.CustomerCertificationId
                              AND Recertification = dct.Recertification
                            ORDER BY AuditDate ASC
                        ), YEAR(dct.CreatedDate))
                    ELSE YEAR(cert.AddedDate)
                END AS BaseYear,
                NULL AS RequirementId,
                NULL AS RequirementTitle,
                'Basundarlag' AS ChapterTitle,
                dct.Id AS DocumentCommmentId,
                NULL AS RequirementResponseId,
                NULL AS CommentId,
                1 AS Status,
                dct.CustomerId,
                dct.AuditorId,
                c.CompanyName,
                cert.Id AS CertificationId,
                cert.CertificateCode AS CertificationCodes,
                du.ID AS DocumentDetailId,
                du.DocumentName,
                du.DocumentType,
				(SELECT	
						CASE WHEN AuditorId IS NOT NULL
							THEN AuditorId 
							ELSE CustomerId
							END AS Id,
						CASE WHEN AuditorId IS NOT NULL
							THEN 2
							ELSE 3
							END AS RoleId,
						CASE WHEN AuditorId IS NOT NULL
							THEN (SELECT Name FROM SBSC.Auditor WHERE Id = AuditorId)
							ELSE (SELECT CompanyName FROM SBSC.Customers WHERE Id = CustomerId)
							END AS Name
					FROM SBSC.DocumentCommentThread
					WHERE Id = dct.Id
					FOR JSON PATH) AS UploadedData,
                NULL AS Size,
                du.DownloadLink,
                du.AddedDate,
                'Basic' AS DocumentSource
            FROM [SBSC].[DocumentCommentThread] dct
            INNER JOIN [SBSC].[DocumentUploads] du ON du.CommentId = dct.Id
            INNER JOIN [SBSC].[Customers] c ON c.Id = dct.CustomerId
            INNER JOIN [SBSC].[DocumentsCertifications] dc ON dc.DocId = dct.DocumentId
            INNER JOIN [SBSC].[Certification] cert ON dc.CertificationId = cert.Id
            INNER JOIN [SBSC].[Customer_Certifications] cc ON cert.Id = cc.CertificateId AND cc.CustomerId = dct.CustomerId
            WHERE (@UseCustomerFilter = 0 OR dct.CustomerId IN (SELECT CustomerId FROM @CustomerIds))
              AND (@CertificationId IS NULL OR cert.Id = @CertificationId)
            
            UNION ALL
            
            -- Requirement Documents
            SELECT 
                cr.Id,
                cd.Id AS DocumentId,
                cr.Recertification,
                CASE 
                    WHEN cr.Recertification > 0 THEN
                        ISNULL((
                            SELECT TOP 1 YEAR(AuditDate)
                            FROM [SBSC].[CustomerRecertificationAudits]
                            WHERE CustomerCertificationId = cc.CustomerCertificationId
                              AND Recertification = cr.Recertification
                            ORDER BY AuditDate ASC
                        ), YEAR(cr.AddedDate))
                    ELSE YEAR(cc.CreatedDate)
                END AS BaseYear,
                cr.RequirementId,
                CONCAT(ch.DisplayOrder, '.', rc.DispalyOrder, ' ', rl.Headlines) AS RequirementTitle,
                CONCAT(ch.DisplayOrder, '. ', chl.ChapterTitle) AS ChapterTitle,
                NULL AS DocumentCommmentId,
                cr.Id AS RequirementResponseId,
                NULL AS CommentId,
                1 AS Status,
                cr.CustomerId,
                NULL AS AuditorId,
                c.CompanyName,
                cert.Id AS CertificationId,
                cert.CertificateCode AS CertificationCodes,
                cd.ID AS DocumentDetailId,
                cd.DocumentName,
                cd.DocumentType,
				(SELECT	
						CustomerId AS Id,
						3 AS RoleId,
						(SELECT CompanyName FROM SBSC.Customers WHERE Id = CustomerId) AS Name
					FROM SBSC.CustomerResponse
					WHERE Id = cr.Id
					FOR JSON PATH) AS UploadedData,
                cd.Size,
                cd.DownloadLink,
                cd.AddedDate,
                'Requirement' AS DocumentSource
            FROM [SBSC].[CustomerResponse] cr
            INNER JOIN [SBSC].[CustomerDocuments] cd ON cr.Id = cd.CustomerResponseId
            INNER JOIN [SBSC].[Customers] c ON c.Id = cr.CustomerId
            INNER JOIN [SBSC].[RequirementChapters] rc ON rc.RequirementId = cr.RequirementId
            INNER JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
            INNER JOIN [SBSC].[Certification] cert ON ch.CertificationId = cert.Id
            INNER JOIN [SBSC].[Customer_Certifications] cc ON cert.Id = cc.CertificateId AND cc.CustomerId = cr.CustomerId
            INNER JOIN SBSC.RequirementLanguage rl ON rl.RequirementId = rc.RequirementId AND rl.LangId = @LangId
            INNER JOIN SBSC.ChapterLanguage chl ON chl.ChapterId = ch.Id AND chl.LanguageId = @LangId
            WHERE (@UseCustomerFilter = 0 OR cr.CustomerId IN (SELECT CustomerId FROM @CustomerIds))
              AND (@CertificationId IS NULL OR cert.Id = @CertificationId)
            
            UNION ALL
            
            -- Comment Documents  
            SELECT 
                ct.Id,
                cd.Id AS DocumentId,
                ct.Recertification,
                CASE 
                    WHEN ct.Recertification > 0 THEN
                        ISNULL((
                            SELECT TOP 1 YEAR(AuditDate)
                            FROM [SBSC].[CustomerRecertificationAudits]
                            WHERE CustomerCertificationId = cc.CustomerCertificationId
                              AND Recertification = ct.Recertification
                            ORDER BY AuditDate ASC
                        ), YEAR(ct.CreatedDate))
                    ELSE YEAR(cert.AddedDate)
                END AS BaseYear,
                ct.RequirementId,
                CONCAT(ch.DisplayOrder, '.', rc.DispalyOrder, ' ', rl.Headlines) AS RequirementTitle,
                CONCAT(ch.DisplayOrder, '. ', chl.ChapterTitle) AS ChapterTitle,
                NULL AS DocumentCommmentId,
                NULL AS RequirementResponseId,
                ct.Id AS CommentId,
                1 AS Status,
                ct.CustomerId,
                ct.AuditorId,
                c.CompanyName,
                cert.Id AS CertificationId,
                cert.CertificateCode AS CertificationCodes,
                cd.Id AS DocumentDetailId,
                cd.DocumentName,
                cd.DocumentType,
				(SELECT	
						CASE WHEN AuditorId IS NOT NULL
							THEN AuditorId 
							ELSE CustomerId
							END AS Id,
						CASE WHEN AuditorId IS NOT NULL
							THEN 2
							ELSE 3
							END AS RoleId,
						CASE WHEN AuditorId IS NOT NULL
							THEN (SELECT Name FROM SBSC.Auditor WHERE Id = AuditorId)
							ELSE (SELECT CompanyName FROM SBSC.Customers WHERE Id = CustomerId)
							END AS Name
					FROM SBSC.CommentThread
					WHERE Id = ct.Id
					FOR JSON PATH) AS UploadedData,
                cd.Size,
                cd.DownloadLink,
                cd.AddedDate,
                'Comment' AS DocumentSource
            FROM [SBSC].[CommentThread] ct
            INNER JOIN [SBSC].[CommentDocument] cd ON ct.Id = cd.CommentId
            INNER JOIN [SBSC].[Customers] c ON c.Id = ct.CustomerId
            INNER JOIN [SBSC].[RequirementChapters] rc ON rc.RequirementId = ct.RequirementId
            INNER JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
            INNER JOIN [SBSC].[Certification] cert ON ch.CertificationId = cert.Id
            INNER JOIN [SBSC].[Customer_Certifications] cc ON cert.Id = cc.CertificateId AND cc.CustomerId = ct.CustomerId
            INNER JOIN SBSC.RequirementLanguage rl ON rl.RequirementId = ct.RequirementId AND rl.LangId = @LangId
            INNER JOIN SBSC.ChapterLanguage chl ON chl.ChapterId = ch.Id AND chl.LanguageId = @LangId
            WHERE (@UseCustomerFilter = 0 OR ct.CustomerId IN (SELECT CustomerId FROM @CustomerIds))
              AND (@CertificationId IS NULL OR cert.Id = @CertificationId)
        ),
        DistinctDocumentData AS (
            SELECT DISTINCT
                Id, DocumentId, Recertification, BaseYear, RequirementId, RequirementTitle,
                ChapterTitle, DocumentCommmentId, RequirementResponseId, CommentId, Status,
                CustomerId, AuditorId, CompanyName, CertificationId, CertificationCodes,
                DocumentDetailId, DocumentName, DocumentType, UploadedData, Size, DownloadLink, AddedDate, DocumentSource
            FROM DocumentData
        ),
        FilteredData AS (
            SELECT *,
                   COUNT(*) OVER() AS TotalRecords
            FROM DistinctDocumentData
            WHERE (@SearchValue IS NULL OR (
                DocumentName LIKE '%' + @SearchValue + '%' 
                OR RequirementTitle LIKE '%' + @SearchValue + '%'
                OR ChapterTitle LIKE '%' + @SearchValue + '%'
                OR CAST(DocumentId AS NVARCHAR(50)) LIKE '%' + @SearchValue + '%'
            ))
        ),
        PagedData AS (
            SELECT *,
                   ROW_NUMBER() OVER (
                       ORDER BY 
                           CASE WHEN @SortColumn = 'AddedDate' AND @SortDirection = 'ASC' THEN AddedDate END ASC,
                           CASE WHEN @SortColumn = 'AddedDate' AND @SortDirection = 'DESC' THEN AddedDate END DESC,
                           CASE WHEN @SortColumn = 'Id' AND @SortDirection = 'ASC' THEN Id END ASC,
                           CASE WHEN @SortColumn = 'Id' AND @SortDirection = 'DESC' THEN Id END DESC
                   ) AS FinalRowNum
            FROM FilteredData
        )
        SELECT 
            Id, DocumentId, Recertification, BaseYear, RequirementId, RequirementTitle,
            ChapterTitle, DocumentCommmentId, RequirementResponseId, CommentId, Status,
            CustomerId, AuditorId, CompanyName, CertificationId, CertificationCodes,
            DocumentDetailId, DocumentName, DocumentType, UploadedData, Size, DownloadLink, AddedDate, DocumentSource,
            TotalRecords,
            -- Pagination metadata in same result set
            CEILING(CAST(TotalRecords AS INT) / @PageSize) AS TotalPages,
            @PageNumber AS CurrentPage,
            @PageSize AS PageSize,
            CASE WHEN @PageNumber < CEILING(CAST(TotalRecords AS FLOAT) / @PageSize) THEN 1 ELSE 0 END AS HasNextPage,
            CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage
        FROM PagedData
        WHERE FinalRowNum BETWEEN @Offset + 1 AND @Offset + @PageSize
        ORDER BY FinalRowNum;

    END
    ELSE
    BEGIN
        SELECT 'Invalid Action' AS Message;
    END
END;
GO