SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_DocumentCommentThread_CRUD]
    @Action NVARCHAR(50),               
    @Id INT = NULL,                     
    @DocumentId INT = NULL,         
    @CustomerId INT = NULL,             
    @AuditorId INT = NULL,
    @ParentCommentId INT = NULL,
    @Comment NVARCHAR(MAX) = NULL,
    @DocumentUploads [SBSC].[CustomerDocumentsType] READONLY,
    @DocumentDetailId INT = NULL,
	@CreatedDate DATETIME = NULL,
	@ApprovalStatus BIT = NULL,
	@CustomerCertificationDetailId INT = NULL,
	@AssignmentId INT = NULL,

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
	-- NOTE: ALWAYS CREATED BASIC DOCUMENT RESPONSE FOR A SINGLE CUSTOMER CERTIFICATION DETAIL ID
	-- WHILE FETCHING THE DATA, THE READ COMMENT THREAD FETCHES THE DATA FROM ALL OF THE CUSTOMER CERTIFICATION DETAIL ID IF ASSIGNMENTID IS PROVIDED
	-- THIS RETURNS ACCURATE ONLY IF CONDITION 1 IS SATISFIED
	
    IF @Action = 'CREATE'
    BEGIN
        -- Validate RequirementId (basic validation since it's external)
        IF @DocumentId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.Documents WHERE Id = @DocumentId)
        BEGIN
            RAISERROR('DocumentId is required', 16, 1);
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
            AND NOT EXISTS (SELECT 1 FROM [SBSC].[DocumentCommentThread] WHERE Id = @ParentCommentId)
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

		--SELECT @Recertification = ISNULL(Recertification, 0) 
		--		FROM SBSC.Customer_certifications
		--		WHERE CertificateId IN
		--			(SELECT CertificationId FROM SBSC.Chapter 
		--			 WHERE Id IN (SELECT ChapterId FROM SBSC.RequirementChapters 
		--						  WHERE RequirementId = @RequirementId)
		--			) AND CustomerId = @CustomerId;

		
		IF EXISTS (SELECT 1 FROM SBSC.DocumentCommentThread WHERE CustomerId = @CustomerId AND DocumentId = @DocumentId AND AuditorId IS NOT NULL)
		BEGIN
			SET @ApprovalStatus = 0
		END

		IF (@CustomerCertificationDetailId IS NULL AND @AssignmentId IS NOT NULL)
		BEGIN
			SET @CustomerCertificationDetailId = (SELECT TOP 1 acc.CustomerCertificationDetailsId 
				FROM SBSC.AssignmentCustomerCertification acc 
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				INNER JOIN SBSC.DocumentsCertifications dc ON dc.CertificationId = cc.CertificateId
				WHERE acc.AssignmentId = @AssignmentId
					AND dc.DocId = @DocumentId);
		END

		-- Validate RequirementId (basic validation since it's external)
        IF @CustomerCertificationDetailId IS NULL
        BEGIN
            RAISERROR('Invalid CustomerCertificationDetailId', 16, 1);
            RETURN;
        END


        -- Insert into CommentThread
        INSERT INTO [SBSC].[DocumentCommentThread] (DocumentId, CustomerId, AuditorId, ParentCommentId, Comment, CustomerCommentTurn, ReadStatus, CreatedDate, Recertification, IsApproved, CustomerCertificationDetailsId	)
        VALUES (@DocumentId, @CustomerId, @AuditorId, @ParentCommentId, @Comment, @CustomerCommentTurn, 0, ISNULL(@CreatedDate, GETUTCDATE()), ISNULL(@Recertification, 0), @ApprovalStatus, @CustomerCertificationDetailId);

		UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailId)

        -- Retrieve the newly inserted ID
        DECLARE @NewCommentId INT = SCOPE_IDENTITY();

        -- Insert documents if provided
        IF EXISTS (SELECT 1 FROM @DocumentUploads)
        BEGIN
            INSERT INTO [SBSC].DocumentUploads (CommentId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
            SELECT @NewCommentId, DocumentName, DocumentType, UploadId, Size, ISNULL(@CreatedDate, GETUTCDATE()), DownloadLink
            FROM @DocumentUploads;
        END

        -- Return the newly created comment
        SELECT 
            c.Id,
            c.DocumentId,
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
                    du.Id AS DocumentDetailId,
                    du.DocumentName,
                    du.DocumentType,
                    du.UploadId,
					du.Size,
                    du.AddedDate,
					du.DownloadLink
                FROM 
                    [SBSC].DocumentUploads du
                WHERE 
                    du.CommentId = c.Id
                FOR JSON PATH
            ) AS DocumentsJson
        FROM 
            [SBSC].DocumentCommentThread c
        WHERE 
            c.Id = @NewCommentId;
    END

    -- Read comment by ID
    ELSE IF @Action = 'READ'
    BEGIN
        SELECT 
            c.Id,
            c.DocumentId,
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
                    du.Id AS DocumentDetailId,
                    du.DocumentName,
                    du.DocumentType,
                    du.UploadId,
					du.Size,
                    du.AddedDate,
					du.DownloadLink
                FROM 
                    [SBSC].DocumentUploads du
                WHERE 
                    du.CommentId = c.Id
                FOR JSON PATH
            ) AS DocumentsJson
        FROM 
            [SBSC].DocumentCommentThread c
        WHERE 
            c.Id = @Id;
    END

    -- Get thread of comments (parent and all its replies)
	ELSE IF @Action = 'READ_THREAD'
	BEGIN
		-- First find all comment threads related to this document
		;WITH CommentGroups AS (
			-- Find root comments for this document (those with no parent)
			SELECT
				c.Id,
				c.DocumentId,
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
				[SBSC].DocumentCommentThread c
			WHERE
				c.DocumentId = @DocumentId
				AND c.CustomerId = @CustomerId
				AND (@CustomerCertificationDetailId IS NULL OR c.CustomerCertificationDetailsId = @CustomerCertificationDetailId)
				AND (@AssignmentId IS NULL OR c.CustomerCertificationDetailsId IN (SELECT acc.CustomerCertificationDetailsId FROM SBSC.AssignmentCustomerCertification acc WHERE acc.AssignmentId = @AssignmentId))
				AND c.ParentCommentId IS NULL
            
			UNION ALL
        
			-- Find all replies and associate them with the same thread group as their ancestors
			SELECT
				c.Id,
				c.DocumentId,
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
				[SBSC].DocumentCommentThread c
			INNER JOIN
				CommentGroups cg ON c.ParentCommentId = cg.Id
		)
		SELECT 
			cg.Id,
			cg.DocumentId,
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
					du.Id AS DocumentDetailId,
					du.DocumentName,
					du.DocumentType,
					du.UploadId,
					du.Size,
					du.AddedDate,
					du.DownloadLink
				FROM 
					[SBSC].DocumentUploads du
				WHERE 
					du.CommentId = cg.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			CommentGroups cg
		ORDER BY 
			cg.ThreadGroup,  -- Group by conversation thread
			cg.CreatedDate DESC;  -- Chronological order within each thread
	END

    -- Update comment
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Validate comment exists
        IF NOT EXISTS (SELECT 1 FROM [SBSC].DocumentCommentThread WHERE Id = @Id)
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
        UPDATE [SBSC].DocumentCommentThread
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
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.DocumentCommentThread WHERE Id = @Id))

        -- Insert new documents if provided
        IF EXISTS (SELECT 1 FROM @DocumentUploads)
        BEGIN
            INSERT INTO [SBSC].DocumentUploads (CommentId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
            SELECT @Id, DocumentName, DocumentType, UploadId, Size, GETUTCDATE(), DownloadLink
            FROM @DocumentUploads;
        END

        -- Return the updated comment
        SELECT 
            c.Id,
            c.DocumentId,
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
                    du.Id AS DocumentDetailId,
                    du.DocumentName,
                    du.DocumentType,
                    du.UploadId,
					du.Size,
                    du.AddedDate,
					du.DownloadLink
                FROM 
                    [SBSC].DocumentUploads du
                WHERE 
                    du.CommentId = c.Id
                FOR JSON PATH
            ) AS DocumentsJson
        FROM 
            [SBSC].DocumentCommentThread c
        WHERE 
            c.Id = @Id;
    END

	-- Update comment
    ELSE IF @Action = 'UPDATE_READ_STATUS'
    BEGIN
        -- Validate comment exists
        IF NOT EXISTS (SELECT 1 FROM [SBSC].DocumentCommentThread WHERE Id = @Id)
        BEGIN
            RAISERROR('Comment not found', 16, 1);
            RETURN;
        END

		--SELECT 
		--	@DocumentId = DocumentId,
		--	@CustomerId = CustomerId
		--FROM 
		--	SBSC.DocumentCommentThread
		--WHERE 
		--	Id = @Id;
        
		-- Update CommentThread
        UPDATE [SBSC].DocumentCommentThread
        SET 
            ReadStatus = 1
        WHERE 
            Id = @Id;

    END

    -- Delete comment
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Check if comment has child comments
            IF EXISTS (SELECT 1 FROM [SBSC].DocumentCommentThread WHERE ParentCommentId = @Id)
            BEGIN
                RAISERROR('Cannot delete comment with replies. Delete the replies first.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
            END

			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.DocumentCommentThread WHERE Id = @Id))

            -- Delete associated documents
            DELETE FROM [SBSC].DocumentUploads WHERE CommentId = @Id;

            -- Delete the comment
            DELETE FROM [SBSC].DocumentCommentThread WHERE Id = @Id;

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
        IF @SortColumn NOT IN ('Id', 'DocumentId', 'CustomerId', 'AuditorId', 'CreatedDate')
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
        IF @DocumentId IS NOT NULL
            SET @WhereClause = @WhereClause + N' AND DocumentId = @DocumentId';
            
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
            FROM [SBSC].[DocumentCommentThread]
            ' + @WhereClause;

        -- Define parameter types for sp_executesql
        SET @ParamDefinition = N'
            @DocumentId INT,
            @CustomerId INT,
            @AuditorId INT,
            @ParentCommentId INT,
            @SearchValue NVARCHAR(100),
            @TotalRecords INT OUTPUT';

        -- Execute the total count query
        EXEC sp_executesql @SQL, 
            @ParamDefinition, 
            @DocumentId,
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
                c.DocumentId,
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
                    FROM [SBSC].[DocumentCommentThread] replies
                    WHERE replies.ParentCommentId = c.Id
                ) AS ReplyCount,
                -- Get Documents as a JSON array
                (
                    SELECT 
                        du.Id AS DocumentDetailId,
                        du.DocumentName,
                        du.DocumentType,
                        du.UploadId,
						du.Size,
                        du.AddedDate,
						du.DownloadLink
                    FROM 
                        [SBSC].[DocumentUploads] du
                    WHERE 
                        du.CommentId = c.Id
                    FOR JSON PATH
                ) AS DocumentsJson
            FROM 
                [SBSC].[DocumentCommentThread] c
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

        -- Execute the paginated query
        EXEC sp_executesql @SQL, 
            @ParamDefinition, 
            @DocumentId,
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
        SELECT DocumentName, DocumentType, UploadId, Size, AddedDate , DownloadLink
        FROM [SBSC].DocumentUploads 
        WHERE Id = @DocumentDetailId;
    END

    -- Delete document
    ELSE IF @Action = 'DELETEDOCUMENT'
    BEGIN
        BEGIN TRY
			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.DocumentCommentThread WHERE Id = (SELECT CommentId
									FROM SBSC.DocumentUploads
									WHERE Id = @DocumentDetailId)))

            DELETE FROM [SBSC].DocumentUploads WHERE Id = @DocumentDetailId;
            SELECT @DocumentDetailId AS Id;
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
	

	ELSE IF @Action = 'APPROVE_BY_AUDITOR'
	BEGIN
		UPDATE [SBSC].[DocumentCommentThread]
		SET
			IsApproved = @ApprovalStatus
		WHERE DocumentId = @DocumentId 
		AND CustomerId = @CustomerId

		UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT DISTINCT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId IN (SELECT CustomerCertificationDetailsId
						FROM SBSC.DocumentCommentThread WHERE CustomerId = @CustomerId
										AND DocumentId = @DocumentId))


	END

	ELSE IF @Action = 'UPDATE_CUSTOMER_COMMENT_TURN_FROM_AUDITOR_RESPONSE'
	BEGIN
		-- Validate AuditorResponseId
		IF @DocumentId IS NULL OR @CustomerId IS NULL
		BEGIN
			RAISERROR('DocumentId and CustomerId is required.', 16, 1);
			RETURN;
		END
    
		IF NOT EXISTS (SELECT 1 FROM SBSC.DocumentCommentThread WHERE DocumentId = @DocumentId AND CustomerId = @CustomerId AND IsApproved = 1)
		BEGIN
			DECLARE @TopId INT = NULL;
			SELECT TOP 1 @TopId = ID FROM SBSC.DocumentCommentThread WHERE
			DocumentId = @DocumentId AND CustomerId = @CustomerId ORDER BY CreatedDate DESC;

			UPDATE [SBSC].[DocumentCommentThread]
			SET CustomerCommentTurn = 1,
				ModifiedDate = GETUTCDATE()
			WHERE Id = @TopId
		END
	END

    -- Invalid action
    ELSE
    BEGIN
        SELECT 'Invalid Action' AS Message;
    END
END;
GO