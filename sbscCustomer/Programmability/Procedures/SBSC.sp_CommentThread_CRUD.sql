SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_CommentThread_CRUD]
    @Action NVARCHAR(50),               
    @Id INT = NULL,                     
    @RequirementId INT = NULL,         
    @CustomerId INT = NULL,             
    @AuditorId INT = NULL,
    @ParentCommentId INT = NULL,
    @Comment NVARCHAR(MAX) = NULL,
    @CommentDocuments [SBSC].[CustomerDocumentsType] READONLY,
    @DocumentId INT = NULL,
	@CreatedDate DATETIME = NULL,
	@CustomerCertificationDetailsId INT = NULL,

	@CustomerCommentTurn BIT = NULL,
	@Recertification INT = NULL,

	@CustomerResponseId INT = NULL,
	@AuditorResponseId INT = NULL,

    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'CreatedDate',
    @SortDirection NVARCHAR(4) = 'DESC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Create new comment
    IF @Action = 'CREATE'
    BEGIN
        -- Validate RequirementId (basic validation since it's external)
        IF @RequirementId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.Requirement WHERE Id = @RequirementId)
        BEGIN
            RAISERROR('RequirementId is required', 16, 1);
            RETURN;
        END

        -- Validate that either CustomerId or AuditorId is provided (but not both)
        --IF (@CustomerId IS NULL AND @AuditorId IS NULL) OR (@CustomerId IS NOT NULL AND @AuditorId IS NOT NULL)
        --BEGIN
        --    RAISERROR('Either CustomerId or AuditorId must be provided, but not both', 16, 1);
        --    RETURN;
        --END

        -- Validate CustomerId if provided
        IF @CustomerId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [SBSC].[Customers] WHERE Id = @CustomerId)
        BEGIN
            RAISERROR('Invalid CustomerId', 16, 1);
            RETURN;
        END

		-- Validate CustomerId if provided
        IF @AuditorId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM [SBSC].[Auditor] WHERE Id = @AuditorId)
        BEGIN
            RAISERROR('Invalid AuditorId', 16, 1);
            RETURN;
        END


        -- Validate ParentCommentId if provided
        IF @ParentCommentId IS NOT NULL 
            AND NOT EXISTS (SELECT 1 FROM [SBSC].[CommentThread] WHERE Id = @ParentCommentId)
        BEGIN
            RAISERROR('Invalid ParentCommentId', 16, 1);
            RETURN;
        END

        ---- Comment is required
        --IF @Comment IS NULL OR LEN(TRIM(@Comment)) = 0
        --BEGIN
        --    RAISERROR('Comment is required', 16, 1);
        --    RETURN;
        --END

		SELECT @Recertification = ISNULL(Recertification, 0) 
				FROM SBSC.Customer_certifications
				WHERE CertificateId IN
					(SELECT CertificationId FROM SBSC.Chapter 
					 WHERE Id IN (SELECT ChapterId FROM SBSC.RequirementChapters 
								  WHERE RequirementId = @RequirementId)
					) AND CustomerId = @CustomerId;


        -- Insert into CommentThread
        INSERT INTO [SBSC].[CommentThread] (RequirementId, CustomerId, AuditorId, ParentCommentId, Comment, CustomerCommentTurn, ReadStatus, CreatedDate, Recertification, [CustomerCertificationDetailsId])
        VALUES (@RequirementId, @CustomerId, @AuditorId, @ParentCommentId, @Comment, @CustomerCommentTurn, 0, ISNULL(@CreatedDate, GETUTCDATE()), @Recertification, @CustomerCertificationDetailsId);


		UPDATE SBSC.AssignmentOccasions
		SET LastUpdatedDate = GETUTCDATE()
		WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
		WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)

        -- Retrieve the newly inserted ID
        DECLARE @NewCommentId INT = SCOPE_IDENTITY();

        -- Insert documents if provided
        IF EXISTS (SELECT 1 FROM @CommentDocuments)
        BEGIN
            INSERT INTO [SBSC].[CommentDocument] (CommentId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
            SELECT @NewCommentId, DocumentName, DocumentType, UploadId, Size, ISNULL(@CreatedDate, GETUTCDATE()), DownloadLink
            FROM @CommentDocuments;
        END

        -- Return the newly created comment
        SELECT 
            c.Id,
            c.RequirementId,
            c.CustomerId,
            c.AuditorId,
            c.ParentCommentId,
            c.Comment,
            c.CreatedDate,
			c.CustomerCommentTurn,
			c.ReadStatus,
			c.CustomerCertificationDetailsId,
            -- Get Documents as a JSON array
            (
                SELECT 
                    cd.Id AS DocumentId,
                    cd.DocumentName,
                    cd.DocumentType,
                    cd.UploadId,
					cd.Size,
                    cd.AddedDate,
					cd.DownloadLink
                FROM 
                    [SBSC].[CommentDocument] cd
                WHERE 
                    cd.CommentId = c.Id
                FOR JSON PATH
            ) AS DocumentsJson
        FROM 
            [SBSC].[CommentThread] c
        WHERE 
            c.Id = @NewCommentId;
    END

    -- Read comment by ID
    ELSE IF @Action = 'READ'
    BEGIN
        SELECT 
            c.Id,
            c.RequirementId,
            c.CustomerId,
            c.AuditorId,
            c.ParentCommentId,
            c.Comment,
            c.CreatedDate,
			c.CustomerCommentTurn,
			c.ReadStatus,
			c.CustomerCertificationDetailsId,
            -- Get Documents as a JSON array
            (
                SELECT 
                    cd.Id AS DocumentId,
                    cd.DocumentName,
                    cd.DocumentType,
                    cd.UploadId,
					cd.Size,
                    cd.AddedDate, 
					cd.DownloadLink
                FROM 
                    [SBSC].[CommentDocument] cd
                WHERE 
                    cd.CommentId = c.Id
                FOR JSON PATH
            ) AS DocumentsJson
        FROM 
            [SBSC].[CommentThread] c
        WHERE 
            c.Id = @Id;
    END

    -- Get thread of comments (parent and all its replies)
	ELSE IF @Action = 'READ_THREAD'
	BEGIN
		-- First find all comment threads related to this requirement
		;WITH CommentGroups AS (
			-- Find root comments for this requirement (those with no parent)
			SELECT
				c.Id,
				c.RequirementId,
				c.CustomerId,
				c.AuditorId,
				c.ParentCommentId,
				c.Comment,
				c.CreatedDate,
				c.CustomerCommentTurn,
				c.ReadStatus,
				CAST(c.Id AS VARCHAR(255)) AS ThreadGroup,  -- Use root comment ID as thread identifier
				c.CustomerCertificationDetailsId
			FROM
				[SBSC].[CommentThread] c
			WHERE
				c.RequirementId = @RequirementId
				AND c.CustomerId = @CustomerId
				AND c.ParentCommentId IS NULL
            
			UNION ALL
        
			-- Find all replies and associate them with the same thread group as their ancestors
			SELECT
				c.Id,
				c.RequirementId,
				c.CustomerId,
				c.AuditorId,
				c.ParentCommentId,
				c.Comment,
				c.CreatedDate,
				c.CustomerCommentTurn,
				c.ReadStatus,
				cg.ThreadGroup,  -- Maintain the same thread group ID
				c.CustomerCertificationDetailsId
			FROM
				[SBSC].[CommentThread] c
			INNER JOIN
				CommentGroups cg ON c.ParentCommentId = cg.Id
		)
		SELECT 
			cg.Id,
			cg.RequirementId,
			cg.CustomerId,
			cg.AuditorId,
			cg.ParentCommentId,
			cg.Comment,
			cg.CreatedDate,
			cg.CustomerCommentTurn,
			cg.ReadStatus,
			cg.ThreadGroup,
			cg.CustomerCertificationDetailsId,
			-- Get Documents as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.Size,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CommentDocument] cd
				WHERE 
					cd.CommentId = cg.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			CommentGroups cg
		ORDER BY 
			cg.ThreadGroup,  -- Group by conversation thread
			cg.CreatedDate;  -- Chronological order within each thread
	END

    -- Update comment
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Validate comment exists
        IF NOT EXISTS (SELECT 1 FROM [SBSC].[CommentThread] WHERE Id = @Id)
        BEGIN
            RAISERROR('Comment not found', 16, 1);
            RETURN;
        END

        ---- Comment is required if updating
        --IF @Comment IS NULL OR LEN(TRIM(@Comment)) = 0
        --BEGIN
        --    RAISERROR('Comment is required', 16, 1);
        --    RETURN;
        --END

        -- Update CommentThread
        UPDATE [SBSC].[CommentThread]
        SET 
            Comment = @Comment,
			AuditorId = @AuditorId,
			CustomerCommentTurn = @CustomerCommentTurn,
			ModifiedDate = GETUTCDATE()
        WHERE 
            Id = @Id;

		UPDATE SBSC.AssignmentOccasions
		SET LastUpdatedDate = GETUTCDATE()
		WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
		WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)

        -- Insert new documents if provided
        IF EXISTS (SELECT 1 FROM @CommentDocuments)
        BEGIN
            INSERT INTO [SBSC].[CommentDocument] (CommentId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
            SELECT @Id, DocumentName, DocumentType, UploadId, Size, GETUTCDATE(), DownloadLink
            FROM @CommentDocuments;
        END

        -- Return the updated comment
        SELECT 
            c.Id,
            c.RequirementId,
            c.CustomerId,
            c.AuditorId,
            c.ParentCommentId,
            c.Comment,
            c.CreatedDate,
			c.CustomerCommentTurn,
			c.ReadStatus,
			c.CustomerCertificationDetailsId,
            -- Get Documents as a JSON array
            (
                SELECT 
                    cd.Id AS DocumentId,
                    cd.DocumentName,
                    cd.DocumentType,
                    cd.UploadId,
					cd.Size,
                    cd.AddedDate,
					cd.DownloadLink
                FROM 
                    [SBSC].[CommentDocument] cd
                WHERE 
                    cd.CommentId = c.Id
                FOR JSON PATH
            ) AS DocumentsJson
        FROM 
            [SBSC].[CommentThread] c
        WHERE 
            c.Id = @Id;
    END

	-- Update comment
    ELSE IF @Action = 'UPDATE_READ_STATUS'
    BEGIN
        -- Validate comment exists
        IF NOT EXISTS (SELECT 1 FROM [SBSC].[CommentThread] WHERE Id = @Id)
        BEGIN
            RAISERROR('Comment not found', 16, 1);
            RETURN;
        END

		SELECT 
			@RequirementId = RequirementId,
			@CustomerId = CustomerId,
			@CustomerCertificationDetailsId = CustomerCertificationDetailsId
		FROM 
			SBSC.CommentThread
		WHERE 
			Id = @Id;
        
		-- Update CommentThread
        UPDATE [SBSC].[CommentThread]
        SET 
            ReadStatus = 1
        WHERE 
            RequirementId = @RequirementId AND CustomerId = @CustomerId AND CustomerCertificationDetailsId = @CustomerCertificationDetailsId;
    END

    -- Delete comment
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Check if comment has child comments
            IF EXISTS (SELECT 1 FROM [SBSC].[CommentThread] WHERE ParentCommentId = @Id)
            BEGIN
                RAISERROR('Cannot delete comment with replies. Delete the replies first.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId 
							FROM SBSC.CommentThread
							WHERE Id = @Id))

            -- Delete associated documents
            DELETE FROM [SBSC].[CommentDocument] WHERE CommentId = @Id;

            -- Delete the comment
            DELETE FROM [SBSC].[CommentThread] WHERE Id = @Id;

            COMMIT TRANSACTION;
            SELECT @Id AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            
            DECLARE @DeleteErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @DeleteErrorSeverity INT = ERROR_SEVERITY();
            DECLARE @DeleteErrorState INT = ERROR_STATE();

            RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState);
        END CATCH
    END

    -- List comments with filtering
    ELSE IF @Action = 'LIST'
    BEGIN
        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('Id', 'RequirementId', 'CustomerId', 'AuditorId', 'CreatedDate')
            SET @SortColumn = 'CreatedDate';

        -- Validate the sort direction
        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'DESC';

        -- Declare variables for dynamic SQL and pagination
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @WhereClause NVARCHAR(MAX);
        DECLARE @ParamDefinition NVARCHAR(MAX);
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        DECLARE @TotalRecords INT = 0;
        DECLARE @TotalPages INT;

        -- Build WHERE clause based on provided parameters
        SET @WhereClause = N'WHERE 1=1'; -- Start with a condition that's always true

        -- Add filters if provided
        IF @RequirementId IS NOT NULL
            SET @WhereClause = @WhereClause + N' AND RequirementId = @RequirementId';
            
        IF @CustomerId IS NOT NULL
            SET @WhereClause = @WhereClause + N' AND CustomerId = @CustomerId';
            
        IF @AuditorId IS NOT NULL
            SET @WhereClause = @WhereClause + N' AND AuditorId = @AuditorId';
            
        -- Filter for root comments only (no parent)
        IF @ParentCommentId IS NULL
            SET @WhereClause = @WhereClause + N' AND ParentCommentId IS NULL';
        ELSE
            SET @WhereClause = @WhereClause + N' AND ParentCommentId = @ParentCommentId';

        -- Add search filtering if provided
        IF @SearchValue IS NOT NULL
            SET @WhereClause = @WhereClause + N' 
                AND (
                    Comment LIKE ''%'' + @SearchValue + ''%''
                )';

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(*)
            FROM [SBSC].[CommentThread]
            ' + @WhereClause;

        -- Define parameter types for sp_executesql
        SET @ParamDefinition = N'
            @RequirementId INT,
            @CustomerId INT,
            @AuditorId INT,
            @ParentCommentId INT,
            @SearchValue NVARCHAR(100),
            @TotalRecords INT OUTPUT';

        -- Execute the total count query
        EXEC sp_executesql @SQL, 
            @ParamDefinition, 
            @RequirementId,
            @CustomerId,
            @AuditorId,
            @ParentCommentId,
            @SearchValue,
            @TotalRecords OUTPUT;

        -- Calculate total pages
        SET @TotalPages = CASE 
            WHEN @TotalRecords > 0 
            THEN CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize) 
            ELSE 0 
        END;

        -- Retrieve paginated data with DocumentsJson
        SET @SQL = N'
            SELECT 
                c.Id,
                c.RequirementId,
                c.CustomerId,
                c.AuditorId,
                c.ParentCommentId,
                c.Comment,
                c.CreatedDate,
				c.CustomerCommentTurn,
				c.ReadStatus,
				c.CustomerCertificationDetailsId,
                -- Get reply count
                (
                    SELECT COUNT(*)
                    FROM [SBSC].[CommentThread] replies
                    WHERE replies.ParentCommentId = c.Id
                ) AS ReplyCount,
                -- Get Documents as a JSON array
                (
                    SELECT 
                        cd.Id AS DocumentId,
                        cd.DocumentName,
                        cd.DocumentType,
                        cd.UploadId,
						cd.Size,
                        cd.AddedDate, 
						cd.DownloadLink
                    FROM 
                        [SBSC].[CommentDocument] cd
                    WHERE 
                        cd.CommentId = c.Id
                    FOR JSON PATH
                ) AS DocumentsJson
            FROM 
                [SBSC].[CommentThread] c
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

        -- Execute the paginated query
        EXEC sp_executesql @SQL, 
            @ParamDefinition, 
            @RequirementId,
            @CustomerId,
            @AuditorId,
            @ParentCommentId,
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

    -- Get document info
    ELSE IF @Action = 'GETDOCUMENT'
    BEGIN
        SELECT DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink 
        FROM [SBSC].[CommentDocument] 
        WHERE Id = @DocumentId;
    END

    -- Delete document
    ELSE IF @Action = 'DELETEDOCUMENT'
    BEGIN
        BEGIN TRY
			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId 
							FROM SBSC.CommentThread
							WHERE Id = (SELECT CommentId
									FROM SBSC.CommentDocument
									WHERE Id = @DocumentId)))

            DELETE FROM [SBSC].[CommentDocument] WHERE Id = @DocumentId;
            SELECT @DocumentId AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            
            DECLARE @DeleteDocumentErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @DeleteDocumentErrorSeverity INT = ERROR_SEVERITY();
            DECLARE @DeleteDocumentErrorState INT = ERROR_STATE();

            RAISERROR(@DeleteDocumentErrorMessage, @DeleteDocumentErrorSeverity, @DeleteDocumentErrorState);
        END CATCH
    END
	
	ELSE IF @Action = 'CREATE_FROM_RESPONSE'
	BEGIN
		-- Validate CustomerResponseId
		IF @CustomerResponseId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.CustomerResponse WHERE Id = @CustomerResponseId)
		BEGIN
			RAISERROR('CustomerResponseId is required and must be valid', 16, 1);
			RETURN;
		END
    
		-- Validate AuditorId
		IF @AuditorId IS NULL OR NOT EXISTS (SELECT 1 FROM [SBSC].[Auditor] WHERE Id = @AuditorId)
		BEGIN
			RAISERROR('Invalid AuditorId', 16, 1);
			RETURN;
		END
    
		---- Comment is required
		--IF @Comment IS NULL OR LEN(TRIM(@Comment)) = 0
		--BEGIN
		--	RAISERROR('Comment is required', 16, 1);
		--	RETURN;
		--END
    
		-- Get RequirementId and CustomerId from CustomerResponse
		
		SELECT 
			@RequirementId = RequirementId,
			@CustomerId = CustomerId
		FROM 
			SBSC.CustomerResponse
		WHERE 
			Id = @CustomerResponseId;

		SET @CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId FROM SBSC.CustomerResponse WHERE Id = @CustomerResponseId);

		-- Get the current customer_certification recertification year
		SELECT @Recertification = Recertification FROM SBSC.Customer_certifications
						WHERE CustomerCertificationId = (SELECT CustomerCertificationId 
									FROM SBSC.AssignmentCustomerCertification
									WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId);


		-- Insert into CommentThread
		INSERT INTO [SBSC].[CommentThread] (
			RequirementId, 
			CustomerId, 
			AuditorId, 
			ParentCommentId, 
			Comment, 
			CustomerCommentTurn,
			CreatedDate,
			Recertification,
			CustomerCertificationDetailsId
		)
		VALUES (
			@RequirementId, 
			@CustomerId, 
			@AuditorId, 
			NULL, -- No parent comment for response-based comments
			@Comment, 
			@CustomerCommentTurn,
			GETUTCDATE(),
			@Recertification,
			@CustomerCertificationDetailsId
		);

		UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)
    
		-- Retrieve the newly inserted ID
		DECLARE @NewCommentIdFromResponse INT = SCOPE_IDENTITY();
    
		-- Insert documents if provided
		IF EXISTS (SELECT 1 FROM @CommentDocuments)
		BEGIN
			INSERT INTO [SBSC].[CommentDocument] (CommentId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
			SELECT @NewCommentIdFromResponse, DocumentName, DocumentType, UploadId, Size, GETUTCDATE(), DownloadLink
			FROM @CommentDocuments;
		END
    
		-- Return the newly created comment
		SELECT 
			c.Id,
			c.RequirementId,
			c.CustomerId,
			c.AuditorId,
			c.ParentCommentId,
			c.Comment,
			c.CreatedDate,
			c.CustomerCommentTurn,
			c.ReadStatus,
			c.CustomerCertificationDetailsId,
			-- Get Documents as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.Size,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CommentDocument] cd
				WHERE 
					cd.CommentId = c.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			[SBSC].[CommentThread] c
		WHERE 
			c.Id = @NewCommentId;
	END


	-- Update comment from response
	ELSE IF @Action = 'UPDATE_FROM_RESPONSE'
	BEGIN
		-- Validate CustomerResponseId
		IF @CustomerResponseId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.CustomerResponse WHERE Id = @CustomerResponseId)
		BEGIN
			RAISERROR('CustomerResponseId is required and must be valid', 16, 1);
			RETURN;
		END
    
		-- Validate AuditorId
		IF @AuditorId IS NULL OR NOT EXISTS (SELECT 1 FROM [SBSC].[Auditor] WHERE Id = @AuditorId)
		BEGIN
			RAISERROR('Invalid AuditorId', 16, 1);
			RETURN;
		END
    
		---- Comment is required
		--IF @Comment IS NULL OR LEN(TRIM(@Comment)) = 0
		--BEGIN
		--	RAISERROR('Comment is required', 16, 1);
		--	RETURN;
		--END
    
		
		SELECT 
			@RequirementId = RequirementId,
			@CustomerId = CustomerId
		FROM 
			SBSC.CustomerResponse
		WHERE 
			Id = @CustomerResponseId;
    
		-- Find the first existing comment for this requirement and customer
		DECLARE @ExistingCommentId INT;
    
		SELECT TOP 1 @ExistingCommentId = Id
		FROM [SBSC].[CommentThread]
		WHERE RequirementId = @RequirementId 
		  AND CustomerId = @CustomerId
		ORDER BY CreatedDate;
    
		DECLARE @CommentId INT;
    
		-- If no existing comment found, create a new one
		IF @ExistingCommentId IS NULL
		BEGIN
			-- Insert new comment
			INSERT INTO [SBSC].[CommentThread] (
				RequirementId, 
				CustomerId, 
				AuditorId, 
				ParentCommentId, 
				Comment, 
				CustomerCommentTurn,
				CreatedDate,
				CustomerCertificationDetailsId
			)
			VALUES (
				@RequirementId, 
				@CustomerId, 
				@AuditorId, 
				NULL, -- No parent comment for response-based comments
				@Comment, 
				@CustomerCommentTurn,
				GETUTCDATE(),
				@CustomerCertificationDetailsId
			);
        
			SET @CommentId = SCOPE_IDENTITY();
		END
		ELSE
		BEGIN
			-- Update the existing comment
			UPDATE [SBSC].[CommentThread]
			SET 
				Comment = @Comment,
				AuditorId = @AuditorId,
				ModifiedDate = GETUTCDATE()
			WHERE 
				Id = @ExistingCommentId;
            
			SET @CommentId = @ExistingCommentId;
		END

		UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)
    
		-- Handle documents if provided
		IF EXISTS (SELECT 1 FROM @CommentDocuments)
		BEGIN
			-- Insert new documents
			INSERT INTO [SBSC].[CommentDocument] (CommentId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
			SELECT @ExistingCommentId, DocumentName, DocumentType, UploadId, Size, GETUTCDATE(), DownloadLink
			FROM @CommentDocuments;
		END
    
		-- Return the updated comment
		SELECT 
			c.Id,
			c.RequirementId,
			c.CustomerId,
			c.AuditorId,
			c.ParentCommentId,
			c.Comment,
			c.CreatedDate,
			c.ModifiedDate,
			c.CustomerCommentTurn,
			c.ReadStatus,
			c.CustomerCertificationDetailsId,
			-- Get Documents as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.Size,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CommentDocument] cd
				WHERE 
					cd.CommentId = c.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			[SBSC].[CommentThread] c
		WHERE 
			c.Id = @CommentId;
	END


	-- Read documents from response-based comment
	ELSE IF @Action = 'READ_DOCUMENTS_FROM_RESPONSE'
	BEGIN
		-- Validate CustomerResponseId
		IF @CustomerResponseId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.CustomerResponse WHERE Id = @CustomerResponseId)
		BEGIN
			RAISERROR('CustomerResponseId is required and must be valid', 16, 1);
			RETURN;
		END
    
		-- Validate AuditorId
		IF @AuditorId IS NULL OR NOT EXISTS (SELECT 1 FROM [SBSC].[Auditor] WHERE Id = @AuditorId)
		BEGIN
			RAISERROR('Invalid AuditorId', 16, 1);
			RETURN;
		END
    
		SELECT 
			@RequirementId = RequirementId,
			@CustomerId = CustomerId
		FROM 
			SBSC.CustomerResponse
		WHERE 
			Id = @CustomerResponseId;
    
		-- Find the first comment for this requirement, customer and auditor
		DECLARE @CommentIdDocument INT;
    
		SELECT TOP 1 @CommentIdDocument = Id
		FROM [SBSC].[CommentThread]
		WHERE RequirementId = @RequirementId 
		  AND CustomerId = @CustomerId
		  AND AuditorId = @AuditorId
		ORDER BY CreatedDate;
    
		-- If comment found, return its documents
		IF @CommentIdDocument IS NOT NULL
		BEGIN
			-- Return only the documents as JSON
			SELECT 
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.Size,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CommentDocument] cd
				WHERE 
					cd.CommentId = @CommentIdDocument
				FOR JSON PATH
			) AS DocumentsJson;
		END
		ELSE
		BEGIN
			-- Return empty JSON array if no comment found
			SELECT '[]' AS DocumentsJson;
		END
	END

	-- Update customer comment turn flag based on auditor response
	ELSE IF @Action = 'UPDATE_CUSTOMER_COMMENT_TURN_FROM_AUDITOR_RESPONSE'
	BEGIN
		-- Validate AuditorResponseId
		IF @AuditorResponseId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.AuditorCustomerResponses WHERE Id = @AuditorResponseId)
		BEGIN
			RAISERROR('AuditorResponseId is required and must be valid', 16, 1);
			RETURN;
		END
    
		SELECT 
			@CustomerResponseId = CustomerResponseId
		FROM 
			SBSC.AuditorCustomerResponses
		WHERE 
			Id = @AuditorResponseId;
      
		SELECT 
			@RequirementId = RequirementId,
			@CustomerId = CustomerId
		FROM 
			SBSC.CustomerResponse
		WHERE 
			Id = @CustomerResponseId;
    
		-- Find the most recent comment for this requirement and customer
		DECLARE @CommentIdCommentTurn INT;
    
		SELECT TOP 1 @CommentIdCommentTurn = Id
		FROM [SBSC].[CommentThread]
		WHERE RequirementId = @RequirementId 
		  AND CustomerId = @CustomerId
		ORDER BY CreatedDate DESC;
    
		-- If comment found, update CustomerCommentTurn flag
		IF @CommentIdCommentTurn IS NOT NULL
		BEGIN
			UPDATE [SBSC].[CommentThread]
			SET CustomerCommentTurn = 1,
				ModifiedDate = GETUTCDATE()
			WHERE Id = @CommentIdCommentTurn;
        
			------ Return the updated comment
			----SELECT 
			----	c.Id,
			----	c.RequirementId,
			----	c.CustomerId,
			----	c.AuditorId,
			----	c.ParentCommentId,
			----	c.Comment,
			----	c.CreatedDate,
			----	c.ModifiedDate,
			----	c.CustomerCommentTurn
			----FROM 
			----	[SBSC].[CommentThread] c
			----WHERE 
			----	c.Id = @CommentId;
		END
		ELSE
		BEGIN
			-- Return empty result if no comment found
			RAISERROR('No comment found for this requirement and customer', 16, 1);
			RETURN;
		END
	END

    -- Invalid action
    ELSE
    BEGIN
        SELECT 'Invalid Action' AS Message;
    END
END;
GO