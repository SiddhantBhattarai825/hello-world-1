SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_AuditorCustomerResponses]
    @Action NVARCHAR(100),
	@AssignmentId INT = NULL,
    @Id INT = NULL,  -- Optional, used for Update/Delete actions
    @CustomerResponseId INT = NULL,
    @CustomerBasicDocResponse INT = NULL, -- New field for optional reference
    @AuditorId INT = NULL,
    @ResponseStatusId INT = NULL,
    @LanguageId INT = NULL,
    @Response NVARCHAR(MAX) = NULL,
    @ResponseDate DATE = NULL,
    @IsApproved BIT = NULL,  -- New parameter for IsApproved
    @Comment NVARCHAR(MAX) = NULL, -- New parameter for Comment
	@CertificationId INT = NULL,
	@CustomerId INT = NULL,

	@CustomerCertificationDetailsId INT = NULL,

	@AuditorNotesId INT = NULL,
	@Notes NVARCHAR(MAX) = NULL,

	@ApprovalDate DATETIME = NULL,
	@ApprovalStatus BIT = 0,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'RESPONSE_STATUS_LIST', 'READ_BY_ID', 'CREATE_NOTES', 'UPDATE_NOTES', 'APPROVE_AUDITOR_RESPONSE', 'IS_AUDITOR_RESPONSE_COMPLETED')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, READ_BY_ID, RESPONSE_STATUS_LIST, CREATE_NOTES UPDATE_NOTES or APPROVE_AUDITOR_RESPONSE, IS_AUDITOR_RESPONSE_COMPLETED', 16, 1);
        RETURN;
    END

    IF @Action = 'CREATE'
    BEGIN
        -- Validate that at least one of the reference fields is provided
        IF @CustomerResponseId IS NULL AND @CustomerBasicDocResponse IS NULL
        BEGIN
            THROW 50000, 'Either CustomerResponseId or CustomerBasicDocResponse must be provided.', 1;
        END

        DECLARE @NewResponseId INT;
		DECLARE @RequirementId INT;
        DECLARE @TotalDeviationCount INT = 0;

        -- Insert a new record into AuditorCustomerResponses
        INSERT INTO [SBSC].[AuditorCustomerResponses] 
        (
            ResponseStatusId, 
            CustomerResponseId, 
            AuditorId, 
            Response, 
            ResponseDate, 
            IsApproved, 
            Comment,
            CustomerBasicDocResponse,
			CreatedDate,
			ModifiedDate
        )
        VALUES 
        (
            @ResponseStatusId, 
            @CustomerResponseId, 
            @AuditorId, 
            @Response, 
            ISNULL(@ResponseDate, GETUTCDATE()), 
            ISNULL(@IsApproved, 0),  -- Default value for IsApproved
            @Comment,
            @CustomerBasicDocResponse,
			GETUTCDATE(),
			GETUTCDATE()
        );

        -- Get the newly inserted ID
        SET @NewResponseId = SCOPE_IDENTITY();

		-- Get CustomerId if CustomerResponseId is provided
        IF @CustomerResponseId IS NOT NULL
        BEGIN
            SELECT @CustomerId = CustomerId, @RequirementId = RequirementId
            FROM [SBSC].[CustomerResponse]
            WHERE Id = @CustomerResponseId;

            -- Calculate TotalDeviationCount specific to the certification in context
			SELECT @TotalDeviationCount = COUNT(IsApproved)
			FROM [SBSC].[AuditorCustomerResponses] acr
			JOIN [SBSC].[CustomerResponse] cr ON acr.CustomerResponseId = cr.Id
			JOIN [SBSC].[Requirement] req ON cr.RequirementId = req.Id
			JOIN [SBSC].[RequirementChapters] rc ON req.Id = rc.RequirementId
			JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
			JOIN [SBSC].[Certification] cert ON ch.CertificationId = cert.Id
			WHERE cr.CustomerId = @CustomerId
				AND cr.Recertification = (SELECT Recertification from SBSC.Customer_Certifications where CustomerId = @CustomerId
										AND CertificateId IN (SELECT CertificationId FROM SBSC.Chapter WHERE Id IN (SELECT ChapterId FROM SBSC.RequirementChapters WHERE RequirementId = @RequirementId)))
			  AND acr.IsApproved = 0
			  --AND acr.ResponseStatusId != 4;
			  AND cert.Id IN (
				  -- Get the certification ID for the current context
				  SELECT ch_context.CertificationId
				  FROM [SBSC].[CustomerResponse] cr_context
				  JOIN [SBSC].[Requirement] req_context ON cr_context.RequirementId = req_context.Id
				  JOIN [SBSC].[RequirementChapters] rc_context ON req_context.Id = rc_context.RequirementId
				  JOIN [SBSC].[Chapter] ch_context ON rc_context.ChapterId = ch_context.Id
				  WHERE cr_context.Id = @CustomerResponseId
			  );
        END

		IF @CustomerResponseId IS NOT NULL
			SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId 
			FROM SBSC.CustomerResponse 
			WHERE Id = @CustomerResponseId

		IF @CustomerBasicDocResponse IS NOT NULL
			SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId 
			FROM SBSC.CustomerBasicDocResponse
			WHERE Id = @CustomerBasicDocResponse


		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;

        ---- Insert into AuditorNotes if notes are provided
        --IF @Notes IS NOT NULL AND LEN(TRIM(@Notes)) > 0
        --BEGIN
        --    INSERT INTO [SBSC].[AuditorNotes]
        --    (
        --        AuditorCustomerResponseId,
        --        AuditorId,
        --        Note,
        --        CreatedDate
        --    )
        --    VALUES
        --    (
        --        @NewResponseId,
        --        @AuditorId,
        --        @Notes,
        --        GETUTCDATE()
        --    );
        --END

        -- Return the inserted data
        SELECT 
            @NewResponseId AS Id, 
            @ResponseStatusId AS ResponseStatusId,
            @CustomerResponseId AS CustomerResponseId,
            @CustomerBasicDocResponse AS CustomerBasicDocResponse,
            @AuditorId AS AuditorId,
            @Response AS Response,
            @ResponseDate AS ResponseDate,
            @IsApproved AS IsApproved,
            @Comment AS Comment,
			@TotalDeviationCount AS TotalDeviationCount;
    END

    IF @Action = 'UPDATE'
    BEGIN
        DECLARE @CustomerIdUpdate INT;
		DECLARE @RequirementIdUpdate INT;
        DECLARE @TotalDeviationCountUpdate INT = 0;
        DECLARE @CurrentCustomerResponseId INT;
        
        -- Update existing record in AuditorCustomerResponses
        UPDATE [SBSC].[AuditorCustomerResponses]
        SET 
            ResponseStatusId = ISNULL(@ResponseStatusId, ResponseStatusId),
            CustomerResponseId = ISNULL(@CustomerResponseId, CustomerResponseId),
            Response = @Response,
            ResponseDate = (GETUTCDATE()),
			ModifiedDate = GETUTCDATE(),
            IsApproved = ISNULL(@IsApproved, IsApproved),
            Comment = @Comment,
            CustomerBasicDocResponse = ISNULL(@CustomerBasicDocResponse, CustomerBasicDocResponse)
        WHERE Id = @Id;

		-- Get the current CustomerResponseId if not provided in the parameters
        IF @CustomerResponseId IS NULL
        BEGIN
            SELECT @CurrentCustomerResponseId = CustomerResponseId
            FROM [SBSC].[AuditorCustomerResponses]
            WHERE Id = @Id;
        END
        ELSE
        BEGIN
            SET @CurrentCustomerResponseId = @CustomerResponseId;
        END
        
        -- Get CustomerId from CustomerResponse table
        IF @CurrentCustomerResponseId IS NOT NULL
        BEGIN
            SELECT @CustomerIdUpdate = CustomerId, @RequirementIdUpdate = RequirementId
            FROM [SBSC].[CustomerResponse]
            WHERE Id = @CurrentCustomerResponseId;
            
            -- Calculate TotalDeviationCount specific to the certification in context
			SELECT @TotalDeviationCountUpdate = COUNT(*)
			FROM [SBSC].[AuditorCustomerResponses] acr
			JOIN [SBSC].[CustomerResponse] cr ON acr.CustomerResponseId = cr.Id
			JOIN [SBSC].[Requirement] req ON cr.RequirementId = req.Id
			JOIN [SBSC].[RequirementChapters] rc ON req.Id = rc.RequirementId
			JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
			JOIN [SBSC].[Certification] cert ON ch.CertificationId = cert.Id
			WHERE cr.CustomerId = @CustomerIdUpdate
				AND cr.Recertification = (SELECT Recertification from SBSC.Customer_Certifications where CustomerId = @CustomerIdUpdate
										AND CertificateId IN (SELECT CertificationId FROM SBSC.Chapter WHERE Id IN (SELECT ChapterId FROM SBSC.RequirementChapters WHERE RequirementId = @RequirementIdUpdate)))
			  AND acr.IsApproved = 0
			  --AND acr.ResponseStatusId != 4;
			  AND cert.Id IN (
				  -- Get the certification ID for the current context
				  SELECT ch_context.CertificationId
				  FROM [SBSC].[CustomerResponse] cr_context
				  JOIN [SBSC].[Requirement] req_context ON cr_context.RequirementId = req_context.Id
				  JOIN [SBSC].[RequirementChapters] rc_context ON req_context.Id = rc_context.RequirementId
				  JOIN [SBSC].[Chapter] ch_context ON rc_context.ChapterId = ch_context.Id
				  WHERE cr_context.Id = @CurrentCustomerResponseId
			  );
        END

		IF @CustomerResponseId IS NOT NULL
			SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId 
			FROM SBSC.CustomerResponse 
			WHERE Id = @CustomerResponseId

		IF @CustomerBasicDocResponse IS NOT NULL
			SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId 
			FROM SBSC.CustomerBasicDocResponse
			WHERE Id = @CustomerBasicDocResponse


		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;
        
        -- Return the updated data with TotalDeviationCount
        SELECT 
            @Id AS Id,
            @ResponseStatusId AS ResponseStatusId,
            @CustomerResponseId AS CustomerResponseId,
            @CustomerBasicDocResponse AS CustomerBasicDocResponse,
            @AuditorId AS AuditorId,
            @Response AS Response,
            @ResponseDate AS ResponseDate,
            @IsApproved AS IsApproved,
            @Comment AS Comment,
            @TotalDeviationCountUpdate AS TotalDeviationCount;
    END

    ELSE IF @Action = 'DELETE'
    BEGIN
        -- Delete a record
        IF @Id IS NULL
        BEGIN
            THROW 50000, 'Id is required for Delete action.', 1;
        END

		SELECT @CustomerResponseId = CustomerResponseId,
			@CustomerBasicDocResponse = CustomerBasicDocResponse
		FROM SBSC.AuditorCustomerResponses

		IF @CustomerResponseId IS NOT NULL
			SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId 
			FROM SBSC.CustomerResponse 
			WHERE Id = @CustomerResponseId

		IF @CustomerBasicDocResponse IS NOT NULL
			SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId 
			FROM SBSC.CustomerBasicDocResponse
			WHERE Id = @CustomerBasicDocResponse


		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;
        

		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;

        DELETE FROM [SBSC].[AuditorCustomerResponses] WHERE Id = @Id;
		--DELETE FROM [SBSC].[AuditorNotes] WHERE AuditorCustomerResponseId = @Id;
        SELECT @Id AS Id; -- Return the Id of the deleted record
    END

    ELSE IF @Action = 'READ'
    BEGIN
        -- Select records
        IF @CustomerResponseId IS NOT NULL
        BEGIN
            SELECT 
                acr.*,
                (SELECT TOP 1 JSON_OBJECT('Id': an.Id, 'Note': an.Note)
                 FROM [SBSC].[AuditorNotes] an 
                 WHERE an.CustomerResponseId = acr.CustomerResponseId
                 ORDER BY an.CreatedDate DESC) AS AuditorNote
            FROM [SBSC].[AuditorCustomerResponses] acr
            WHERE acr.CustomerResponseId = @CustomerResponseId
            ORDER BY acr.Id DESC;
        END
        ELSE IF @CustomerBasicDocResponse IS NOT NULL
        BEGIN
            SELECT 
                acr.*,
                (SELECT TOP 1 JSON_OBJECT('Id': an.Id, 'Note': an.Note)
                 FROM [SBSC].[AuditorNotes] an 
                 WHERE an.CustomerResponseId = acr.CustomerResponseId
                 ORDER BY an.CreatedDate DESC) AS AuditorNote
            FROM [SBSC].[AuditorCustomerResponses] acr
            WHERE acr.CustomerBasicDocResponse = @CustomerBasicDocResponse
            ORDER BY acr.Id DESC;
        END
        ELSE
        BEGIN
            SELECT 
                acr.*,
                (SELECT TOP 1 JSON_OBJECT('Id': an.Id, 'Note': an.Note)
                 FROM [SBSC].[AuditorNotes] an 
                 WHERE an.CustomerResponseId = acr.CustomerResponseId
                 ORDER BY an.CreatedDate DESC) AS AuditorNote
            FROM [SBSC].[AuditorCustomerResponses] acr
            ORDER BY acr.Id DESC;
        END
    END

	ELSE IF @Action = 'READ_BY_ID'
    BEGIN
        -- Select records
        IF @Id IS NOT NULL
        BEGIN
            SELECT 
                acr.*,
                JSON_OBJECT('Id': an.Id, 'Note': an.Note) AS AuditorNote
            FROM [SBSC].[AuditorCustomerResponses] acr
            LEFT JOIN [SBSC].[AuditorNotes] an ON acr.CustomerResponseId = an.CustomerResponseId
            WHERE acr.Id = @Id;
        END
        ELSE
        BEGIN
            SELECT 
                acr.*,
                JSON_OBJECT('Id': an.Id, 'Note': an.Note) AS AuditorNote
            FROM [SBSC].[AuditorCustomerResponses] acr
            LEFT JOIN [SBSC].[AuditorNotes] an ON acr.Id = an.AuditorCustomerResponseId;
        END
    END

    ELSE IF @Action = 'RESPONSE_STATUS_LIST'
    BEGIN
        -- Select records from AuditorResponseStatuses based on LanguageId
        IF @Id IS NOT NULL
        BEGIN
            SELECT * 
            FROM [SBSC].[AuditorResponseStatuses] 
            WHERE Id = @Id AND (@LanguageId IS NULL OR LanguageId = @LanguageId);
        END
        ELSE
        BEGIN
            SELECT * 
            FROM [SBSC].[AuditorResponseStatuses] 
            WHERE (@LanguageId IS NULL OR LanguageId = @LanguageId);
        END
    END

	ELSE IF @Action = 'LIST'
    BEGIN
        -- Validate sort column and direction
        DECLARE @ValidSortColumns TABLE (ColumnName NVARCHAR(100));
        INSERT INTO @ValidSortColumns VALUES 
            ('CustomerResponseId'), 
            ('CustomerBasicDocResponse'), 
            ('ResponseDate'),
            ('Note');  -- Added Note as a valid sort column
        
        IF @SortColumn NOT IN (SELECT ColumnName FROM @ValidSortColumns)
            SET @SortColumn = 'ResponseDate';
        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'DESC';
        
        -- Initialize pagination variables
        DECLARE @SQL NVARCHAR(MAX),
                @WhereClause NVARCHAR(MAX) = N'',
                @ParamDefinition NVARCHAR(500),
                @Offset INT = (@PageNumber - 1) * @PageSize,
                @TotalRecords INT = 0,
                @TotalPages INT;
        
        -- Build WHERE clause
        SET @WhereClause = N'WHERE 1 = 1';
        IF @CustomerResponseId IS NOT NULL
            SET @WhereClause += N' AND (acr.CustomerResponseId = @CustomerResponseId OR an.CustomerResponseId = @CustomerResponseId)';
        IF @CustomerBasicDocResponse IS NOT NULL
            SET @WhereClause += N' AND (acr.CustomerBasicDocResponse = @CustomerBasicDocResponse OR an.CustomerResponseId IN (SELECT CustomerResponseId FROM [SBSC].[AuditorCustomerResponses] WHERE CustomerBasicDocResponse = @CustomerBasicDocResponse))';
        
        -- Calculate total records
        SET @SQL = N'
            SELECT @TotalRecordsOut = COUNT(*)
            FROM (
                SELECT COALESCE(acr.CustomerResponseId, an.CustomerResponseId) AS CombinedId
                FROM [SBSC].[AuditorCustomerResponses] acr
                FULL OUTER JOIN [SBSC].[AuditorNotes] an ON acr.CustomerResponseId = an.CustomerResponseId
                ' + @WhereClause + '
            ) AS CombinedRecords';
        
        SET @ParamDefinition = N'
            @CustomerResponseId INT,
            @CustomerBasicDocResponse INT,
            @TotalRecordsOut INT OUTPUT';
        
        EXEC sp_executesql 
            @SQL, 
            @ParamDefinition,
            @CustomerResponseId = @CustomerResponseId,
            @CustomerBasicDocResponse = @CustomerBasicDocResponse,
            @TotalRecordsOut = @TotalRecords OUTPUT;
        
        -- Calculate total pages
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);
        
        -- Build main paginated query 
        -- Handle sorting for both regular columns and Note column
        DECLARE @SortSQL NVARCHAR(MAX);
        IF @SortColumn = 'Note'
            SET @SortSQL = N'an.Note';
        ELSE
            SET @SortSQL = N'acr.' + QUOTENAME(@SortColumn);
        
        SET @SQL = N'
            WITH PaginatedData AS (
                SELECT 
                    acr.*,
                    JSON_OBJECT(''Id'': an.Id, ''Note'': an.Note) AS AuditorNote
                FROM [SBSC].[AuditorCustomerResponses] acr
                FULL OUTER JOIN [SBSC].[AuditorNotes] an ON acr.CustomerResponseId = an.CustomerResponseId
                ' + @WhereClause + '
                ORDER BY ' + @SortSQL + ' ' + @SortDirection + '
                OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS
                FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY
            )
            SELECT * FROM PaginatedData';
        
        -- Execute dynamic SQL to return paginated data
        EXEC sp_executesql 
            @SQL,
            N'@CustomerResponseId INT, @CustomerBasicDocResponse INT',
            @CustomerResponseId = @CustomerResponseId,
            @CustomerBasicDocResponse = @CustomerBasicDocResponse;
        
        -- Return pagination details in a separate result set
        SELECT 
            @TotalRecords AS TotalRecords,
            @TotalPages AS TotalPages,
            @PageNumber AS CurrentPage,
            @PageSize AS PageSize,
            CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
            CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
    END

	ELSE IF @Action = 'CREATE_NOTES'
    BEGIN
        -- Validate that at least one of the reference fields is provided
        IF @CustomerResponseId IS NULL
        BEGIN
            THROW 50000, 'CustomerResponseId must be provided.', 1;
        END

        DECLARE @NewAuditorNotesId INT;

        -- Insert a new record into AuditorCustomerResponses
        INSERT INTO [SBSC].[AuditorNotes] 
        (
            CustomerResponseId, 
            AuditorId, 
            Note,
            CreatedDate
        )
        VALUES 
        (
            @CustomerResponseId, 
            @AuditorId, 
            @Notes, 
            CAST(ISNULL(@ResponseDate, GETUTCDATE()) AS DATETIME)
        );

		SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId
		FROM SBSC.CustomerResponse
		WHERE Id = @CustomerResponseId

		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;

        -- Get the newly inserted ID
        SET @NewAuditorNotesId = SCOPE_IDENTITY();


        -- Return the inserted data
        SELECT 
            @NewAuditorNotesId AS AuditorNotesId, 
            @CustomerResponseId AS CustomerResponseId,
            @AuditorId AS AuditorId,
            @Notes AS Note;
    END

	ELSE IF @Action = 'UPDATE_NOTES'
    BEGIN
        -- Update existing record in AuditorCustomerResponses
        UPDATE [SBSC].[AuditorNotes]
        SET 
            Note = @Notes
        WHERE Id = @AuditorNotesId;

		SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId
		FROM SBSC.CustomerResponse
		WHERE Id = (SELECT CustomerResponseId FROM SBSC.AuditorNotes
					WHERE Id = @AuditorNotesId)

		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;

       
        -- Return the updated data
        SELECT 
            @AuditorNotesId AS AuditorNotesId,
            @Notes AS Note;
    END

	ELSE IF @Action = 'APPROVE_AUDITOR_RESPONSE'
	BEGIN
		UPDATE [SBSC].[AuditorCustomerResponses]
		SET
			IsApproved = @ApprovalStatus,
			ApprovalDate = @ApprovalDate
		WHERE ID = @Id

		SELECT @CustomerCertificationDetailsId = CustomerCertificationDetailsId
		FROM SBSC.CustomerResponse
		WHERE Id = (SELECT CustomerResponseId 
					FROM SBSC.AuditorCustomerResponses
					WHERE Id = @Id)

		EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;


		SELECT @Id AS Id;
	END

	ELSE IF @Action = 'IS_AUDITOR_RESPONSE_COMPLETED'
	BEGIN
		-- Get CustomerCertificationDetailsId from assignment
		DECLARE @CustomerCertificationDetailsGetIds TABLE ( 
			CustomerCertificationDetailsId INT, 
			CustomerCertificationId INT, 
			CertificateId INT 
		); 
    
		INSERT INTO @CustomerCertificationDetailsGetIds (CustomerCertificationDetailsId, CustomerCertificationId, CertificateId) 
		SELECT DISTINCT  
			acc.CustomerCertificationDetailsId, 
			ccd.CustomerCertificationId, 
			cc.CertificateId 
		FROM SBSC.AssignmentCustomerCertification acc 
		INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id 
		INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId 
		WHERE acc.AssignmentId = @AssignmentId;
    
		SELECT 
			CASE 
				WHEN COUNT(*) = SUM(CASE WHEN acr.CustomerResponseId IS NOT NULL THEN 1 ELSE 0 END) THEN 1
				ELSE 0 
			END AS IsAllAuditorResponseStatus
		FROM SBSC.CustomerResponse cr
		LEFT JOIN SBSC.AuditorCustomerResponses acr ON cr.Id = acr.CustomerResponseId 
		INNER JOIN SBSC.RequirementChapters rc ON cr.RequirementId = rc.RequirementId
		INNER JOIN SBSC.Chapter c ON rc.ChapterId = c.Id
		INNER JOIN @CustomerCertificationDetailsGetIds ccd ON c.CertificationId = ccd.CertificateId
		WHERE cr.CustomerCertificationDetailsId IN (
			SELECT CustomerCertificationDetailsId 
			FROM @CustomerCertificationDetailsGetIds
		);
	END
END
GO