SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_CustomerBasicDocResponse_CRUD]
    @Action NVARCHAR(20),               
    @Id INT = NULL,                     
    @BasicDocId INT = NULL,         
    @CustomerId INT = NULL,             
    @DisplayOrder INT = NULL,           
    @FreeTextAnswer NVARCHAR(MAX) = NULL, 
    @Comment NVARCHAR(MAX) = NULL,
    @CustomerDocuments [SBSC].[CustomerDocumentsType] READONLY,
    @LangID INT = 1,
    @DocumentId INT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC',
	@CustomerCertificationDetailsId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Create new document response
    IF @Action = 'CREATE'
    BEGIN
        -- Validate BasicDocId
        IF NOT EXISTS (SELECT 1 FROM [SBSC].[Documents] WHERE Id = @BasicDocId)
        BEGIN
            RAISERROR('Invalid BasicDocId', 16, 1);
            RETURN;
        END

        -- Validate CustomerId
        IF NOT EXISTS (SELECT 1 FROM [SBSC].[Customers] WHERE Id = @CustomerId)
        BEGIN
            RAISERROR('Invalid CustomerId', 16, 1);
            RETURN;
        END

        -- Determine DisplayOrder if NULL
        IF @DisplayOrder IS NULL
        BEGIN
            SELECT @DisplayOrder = ISNULL(MAX(DisplayOrder), 0) + 1
            FROM [SBSC].[CustomerBasicDocResponse]
            WHERE CustomerId = @CustomerId AND BasicDocId = @BasicDocId;
        END

        -- Insert into CustomerBasicDocResponse
        INSERT INTO [SBSC].[CustomerBasicDocResponse] (BasicDocId, CustomerId, DisplayOrder, FreeTextAnswer, Comment, AddedDate, ModifiedDate, CustomerCertificationDetailsId)
        VALUES (@BasicDocId, @CustomerId, @DisplayOrder, @FreeTextAnswer, @Comment, GETUTCDATE(), GETUTCDATE(), @CustomerCertificationDetailsId);

		UPDATE SBSC.AssignmentOccasions
		SET LastUpdatedDate = GETUTCDATE()
		WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
		WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)

        -- Retrieve the newly inserted ID
        DECLARE @NewDocResponseId INT = SCOPE_IDENTITY();

        -- Insert documents if provided
        IF EXISTS (SELECT 1 FROM @CustomerDocuments)
        BEGIN
            INSERT INTO [SBSC].[CustomerBasicDocuments] (CustomerBasicDocResponseId, DocumentName, DocumentType, AddedDate, DownloadLink)
            SELECT @NewDocResponseId, DocumentName, DocumentType, GETUTCDATE(), DownloadLink
            FROM @CustomerDocuments;
        END

        SELECT 'Success' AS Message, @NewDocResponseId AS NewId;
    END

    -- Read document response
	ELSE IF @Action = 'READ'
	BEGIN
		-- Get the most recent entry by AddedDate
		WITH LatestResponse AS
		(
			SELECT TOP 1
				dr.Id,
				dr.BasicDocId,
				dr.CustomerId,
				dr.DisplayOrder,
				dr.FreeTextAnswer,
				dr.Comment,
				dr.AddedDate,
				dr.ModifiedDate,
				dr.CustomerCertificationDetailsId
			FROM 
				[SBSC].[CustomerBasicDocResponse] dr
			WHERE 
				dr.BasicDocId = @BasicDocId 
				AND dr.CustomerId = @CustomerId
			ORDER BY 
				dr.AddedDate DESC
		)
		SELECT 
			lr.Id,
			lr.BasicDocId,
			lr.CustomerId,
			lr.DisplayOrder,
			lr.FreeTextAnswer,
			lr.Comment,
			lr.AddedDate,
			lr.ModifiedDate,
			lr.CustomerCertificationDetailsId,
			-- Get certification codes as comma-separated string
			(
				SELECT STRING_AGG(c.CertificateCode, ',')
				FROM [SBSC].[DocumentsCertifications] dc
				JOIN [SBSC].[Certification] c ON dc.CertificationId = c.Id
				WHERE dc.DocId = lr.BasicDocId
			) AS CertificationCodes,
			-- Get Documents Metadata as JSON array
			(
				SELECT 
					cd.ID AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CustomerBasicDocuments] cd
				WHERE 
					cd.CustomerBasicDocResponseId = lr.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			LatestResponse lr;
	END

    -- Update document response
    ELSE IF @Action = 'UPDATE'
    BEGIN
        UPDATE [SBSC].[CustomerBasicDocResponse]
        SET 
            DisplayOrder = ISNULL(@DisplayOrder, DisplayOrder),
            FreeTextAnswer = ISNULL(@FreeTextAnswer, FreeTextAnswer),
            Comment = ISNULL(@Comment, Comment),
            ModifiedDate = GETUTCDATE()
        WHERE 
            Id = @Id;

		UPDATE SBSC.AssignmentOccasions
		SET LastUpdatedDate = GETUTCDATE()
		WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
		WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
					FROM SBSC.CustomerBasicDocResponse WHERE Id = @Id))

        -- Insert new documents if provided
        IF EXISTS (SELECT 1 FROM @CustomerDocuments)
        BEGIN
            INSERT INTO [SBSC].[CustomerBasicDocuments] (CustomerBasicDocResponseId, DocumentName, DocumentType, AddedDate, DownloadLink)
            SELECT @Id, DocumentName, DocumentType, GETUTCDATE(), DownloadLink
            FROM @CustomerDocuments;
        END

        SELECT 'Success' AS Message, @Id AS UpdatedId;
    END

    -- Delete document response
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.CustomerBasicDocResponse WHERE Id = @Id))

            DELETE FROM [SBSC].[CustomerBasicDocResponse] WHERE Id = @Id;
            SELECT @Id AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @DeleteErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @DeleteErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @DeleteErrorState INT = ERROR_STATE()

            RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState)
        END CATCH
    END

    -- List document responses
	ELSE IF @Action = 'LIST'
	BEGIN
		-- Validate sort column
		IF @SortColumn NOT IN ('Id', 'BasicDocId', 'AddedDate')
			SET @SortColumn = 'AddedDate';
		-- Validate sort direction
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC';
    
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(MAX);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;
    
		SET @WhereClause = N'WHERE CustomerId = @CustomerId';
		IF @SearchValue IS NOT NULL
			SET @WhereClause = @WhereClause + N' 
				AND (
					CAST(BasicDocId AS NVARCHAR(50)) LIKE ''%'' + @SearchValue + ''%'' 
					OR FreeTextAnswer LIKE ''%'' + @SearchValue + ''%'' 
				)';

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(*)
			FROM [SBSC].[CustomerBasicDocResponse] dr
			' + @WhereClause;

		SET @ParamDefinition = N'
			@CustomerId INT, 
			@SearchValue NVARCHAR(100), 
			@TotalRecords INT OUTPUT';

		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@CustomerId, 
			@SearchValue, 
			@TotalRecords OUTPUT;

		SET @TotalPages = CASE 
			WHEN @TotalRecords > 0 
			THEN CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize) 
			ELSE 0 
		END;

		-- Retrieve paginated data
		SET @SQL = N'
			SELECT 
				dr.Id,
				dr.BasicDocId,
				dr.CustomerId,
				dr.DisplayOrder,
				dr.FreeTextAnswer,
				dr.Comment,
				dr.AddedDate,
				dr.ModifiedDate,
				dr.CustomerCertificationDetailsId,
				(
					SELECT STRING_AGG(c.CertificateCode, '','')
					FROM [SBSC].[DocumentsCertifications] dc
					JOIN [SBSC].[Certification] c ON dc.CertificationId = c.Id
					WHERE dc.DocId = dr.BasicDocId
				) AS CertificationCodes,
				(
					SELECT 
						cd.ID AS DocumentId,
						cd.DocumentName,
						cd.DocumentType,
						cd.AddedDate,
						cd.DownloadLink
					FROM 
						[SBSC].[CustomerBasicDocuments] cd
					WHERE 
						cd.CustomerBasicDocResponseId = dr.Id
					FOR JSON PATH
				) AS DocumentsJson
			FROM 
				[SBSC].[CustomerBasicDocResponse] dr
			' + @WhereClause + '
			ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
			OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
			FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@CustomerId, 
			@SearchValue, 
			@TotalRecords OUTPUT;

		-- Return pagination details
		SELECT 
			@TotalRecords AS TotalRecords, 
			@TotalPages AS TotalPages, 
			@PageNumber AS CurrentPage, 
			@PageSize AS PageSize,
			CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END


    -- Get specific document
    ELSE IF @Action = 'GETDOCUMENT'
    BEGIN
        SELECT DocumentName, AddedDate , DownloadLink
        FROM [SBSC].[CustomerBasicDocuments] 
        WHERE ID = @DocumentId;
    END

    -- Delete document
    ELSE IF @Action = 'DELETEDOCUMENT'
    BEGIN
        BEGIN TRY
			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.CustomerBasicDocResponse WHERE Id = (SELECT CustomerBasicDocResponseId
												FROM SBSC.CustomerBasicDocuments
												WHERE Id = @DocumentId)))

            DELETE FROM [SBSC].[CustomerBasicDocuments] WHERE ID = @DocumentId;
            SELECT @DocumentId AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @DeleteDocErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @DeleteDocErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @DeleteDocErrorState INT = ERROR_STATE()

            RAISERROR(@DeleteDocErrorMessage, @DeleteDocErrorSeverity, @DeleteDocErrorState)
        END CATCH
    END

    ELSE
    BEGIN
        -- Invalid action
        SELECT 'Invalid Action' AS Message;
    END
END;
GO