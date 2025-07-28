SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_CustomerResponse_CRUD]
    @Action NVARCHAR(50),               
    @Id INT = NULL,                     
    @RequirementId INT = NULL,         
    @CustomerId INT = NULL,             
    @DisplayOrder INT = NULL,           
    @FreeTextAnswer NVARCHAR(MAX) = NULL, 
	@Comment NVARCHAR(MAX) = NULL,
    @AnswerOptions [SBSC].[AnswerOptionsTableType] READONLY,
	@CustomerDocuments [SBSC].[CustomerDocumentsType] READONLY,
	@LangID INT = 1,
	@CreatedDate DATETIME = NULL,
	@AssignmentId INT = NULL,
	@CustomerCertificationDetailsId INT = NULL,

	@NewResponseId INT = NULL,
	@PreviousDocumentIds [SBSC].[IntArrayTable] READONLY,
	

	@DocumentId INT = NULL,

	@CertificationId INT = NULL,
	@CustomerCertificationId INT = NULL,
	@DeviationEndDate DATETIME = NULL,
	@DecisionId INT = 4,

	@UserId INT = NULL,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;
	DECLARE @UserType NVARCHAR(10);

	-- Create new customer response
    IF @Action = 'CREATE'
	BEGIN
		-- Validate RequirementId
		IF NOT EXISTS (SELECT 1 FROM [SBSC].[Requirement] WHERE Id = @RequirementId)
		BEGIN
			RAISERROR('Invalid RequirementId', 16, 1);
			RETURN;
		END

		-- Validate CustomerId
		IF NOT EXISTS (SELECT 1 FROM [SBSC].[Customers] WHERE Id = @CustomerId)
		BEGIN
			RAISERROR('Invalid CustomerId', 16, 1);
			RETURN;
		END

		-- Validate AnswerOptions if provided
		IF EXISTS (SELECT 1 FROM @AnswerOptions)
		BEGIN
			IF EXISTS (
				SELECT ao.AnswerOptionsId
				FROM @AnswerOptions ao
				LEFT JOIN [SBSC].[RequirementAnswerOptions] aoRef ON ao.AnswerOptionsId = aoRef.Id
				WHERE aoRef.Id IS NULL
			)
			BEGIN
				RAISERROR('One or more invalid AnswerOptionsId provided', 16, 1);
				RETURN;
			END
		END

		-- Determine DisplayOrder if NULL
		IF @DisplayOrder IS NULL
		BEGIN
			SELECT @DisplayOrder = ISNULL(MAX(DisplayOrder), 0) + 1
			FROM [SBSC].[CustomerResponse]
			WHERE CustomerId = @CustomerId AND RequirementId = @RequirementId AND CustomerCertificationDetailsId = @CustomerCertificationDetailsId;
		END

		---- Check if a CustomerResponse already exists for this RequirementId and CustomerId
		--DECLARE @PreviousRecertification INT = -1;
		--SELECT @PreviousRecertification = ISNULL(MAX(Recertification), -1) + 1
		--FROM [SBSC].[CustomerResponse]
		--WHERE RequirementId = @RequirementId AND CustomerId = @CustomerId;

		-- Insert into CustomerResponse
		INSERT INTO [SBSC].[CustomerResponse] (
			RequirementId, 
			CustomerId, 
			DisplayOrder, 
			FreeTextAnswer, 
			Comment, 
			AddedDate, 
			ModifiedDate,
			Recertification,
			CustomerCertificationDetailsId
		)
		VALUES (
			@RequirementId, 
			@CustomerId, 
			@DisplayOrder, 
			@FreeTextAnswer, 
			@Comment, 
			ISNULL(@CreatedDate, GETUTCDATE()), 
			GETUTCDATE(),
			(SELECT Recertification FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId),
			@CustomerCertificationDetailsId
		);

		UPDATE SBSC.AssignmentOccasions
		SET LastUpdatedDate = GETUTCDATE()
		WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
		WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)

		-- Retrieve the newly inserted ID
		DECLARE @NewCustomerResponseId INT = SCOPE_IDENTITY();

		-- Insert into CustomerSelectedAnswers for multiple AnswerOptions
		IF EXISTS (SELECT 1 FROM @AnswerOptions)
		BEGIN
			INSERT INTO [SBSC].[CustomerSelectedAnswers] (CustomerResponseId, AnswerOptionsId, AddedDate)
			SELECT @NewCustomerResponseId, AnswerOptionsId, GETUTCDATE()
			FROM @AnswerOptions;
		END

		IF EXISTS (SELECT 1 FROM @CustomerDocuments)
		BEGIN
			INSERT INTO [SBSC].[CustomerDocuments] (CustomerResponseId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
			SELECT @NewCustomerResponseId, DocumentName, DocumentType, UploadId, Size, ISNULL(@CreatedDate, GETUTCDATE()), DownloadLink
			FROM @CustomerDocuments;
		END

		DECLARE @RecertificationYear INT = NULL;

		select @RecertificationYear = Recertification 
		from sbsc.Customer_Certifications cc
		JOIN SBSC.Chapter ch ON ch.CertificationId = cc.CertificateId
		JOIN SBSC.RequirementChapters rc ON rc.ChapterId = ch.Id
		WHERE rc.RequirementId = @RequirementId
			AND cc.CustomerId = @CustomerId

		-- Declare variable for previous audit CustomerCertificationDetailsId
		DECLARE @PreviousAuditCustomerCertificationDetailsId INT;
		DECLARE @CurrentRecertification INT;

		-- Get current recertification level
		SELECT @CurrentRecertification = Recertification 
		FROM SBSC.CustomerCertificationDetails 
		WHERE Id = @CustomerCertificationDetailsId;

		-- Get previous audit CustomerCertificationDetailsId if current recertification > 0
		IF @CurrentRecertification > 0
		BEGIN
			SELECT @PreviousAuditCustomerCertificationDetailsId = ccd.Id
			FROM SBSC.CustomerCertificationDetails ccd
			INNER JOIN SBSC.CustomerCertificationDetails current_ccd ON current_ccd.Id = @CustomerCertificationDetailsId
			WHERE ccd.CustomerCertificationId = current_ccd.CustomerCertificationId
				AND ccd.AddressId = current_ccd.AddressId
				AND ccd.DepartmentId = current_ccd.DepartmentId
				AND ccd.Recertification = (@CurrentRecertification - 1);
		END
		ELSE
		BEGIN
			SET @PreviousAuditCustomerCertificationDetailsId = @CustomerCertificationDetailsId;
		END

		SELECT 
			@NewCustomerResponseId AS Id,
			@RequirementId AS RequirementId,
			@FreeTextAnswer AS FreeTextAnswer,
			ISNULL(@PreviousAuditCustomerCertificationDetailsId, @CustomerCertificationDetailsId) AS CustomerCertificationDetailsId,
			@Comment AS Comment,
			CAST(
				CASE 
					WHEN (SELECT IsFileUploadRequired 
					  FROM [SBSC].[Requirement] 
					  WHERE Id = @RequirementId) = 1 THEN
					-- If file upload is required, check if files exist
					CASE WHEN EXISTS (SELECT 1 FROM @CustomerDocuments) THEN 1 ELSE 0 END
				ELSE
						-- If file upload is not required, check for comment or answer
						CASE 
							 WHEN ((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 1 AND @FreeTextAnswer IS NOT NULL)
								THEN 1
							WHEN (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 2 AND EXISTS (
								SELECT 1 
								FROM [SBSC].[CustomerSelectedAnswers] csa
								WHERE (SELECT RequirementTypeOptionId FROM SBSC.RequirementAnswerOptions WHERE ID = (SELECT TOP 1 AnswerOptionsId FROM @AnswerOptions)) = 1
								AND 
									(@RecertificationYear <= 0 OR EXISTS (
									SELECT 1
									FROM [SBSC].[CustomerResponse] cr_inner
									WHERE cr_inner.Id = csa.CustomerResponseId
									AND cr_inner.Recertification = @RecertificationYear
								))
								) THEN 0
							WHEN (((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 2
								OR (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 3
								OR (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 4 )
								AND EXISTS (
									select 1
									from sbsc.[CustomerSelectedAnswers]    
									INNER JOIN SBSC.CustomerResponse cres ON cres.Id = CustomerResponseId
									WHERE CustomerResponseId = @NewCustomerResponseId
									AND AnswerOptionsId IS NOT NULL
									AND (@RecertificationYear <= 0 OR cres.Recertification = @RecertificationYear)
								)) THEN 1
							WHEN((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 5 )
								THEN
									CASE
										WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @RequirementId) = 0
											AND (SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @RequirementId) = 0)
												THEN 1
										WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
											AND (SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
											AND (@Comment IS NOT NULL OR EXISTS (SELECT 1 FROM @CustomerDocuments)))
												THEN 1
										WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
											AND EXISTS (SELECT 1 FROM @CustomerDocuments))
												THEN 1
										WHEN ((SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
											AND (@Comment IS NOT NULL))
												THEN 1
										ELSE 0
									END
							ELSE 0
						END
					END AS INT) AS IsAnswered
	END

	-- returns customer response by requirementId and customerId
    ELSE IF @Action = 'READ'
	BEGIN
		-- Get the most recent entry by AddedDate
		WITH LatestResponse AS
		(
			SELECT TOP 1
				cr.Id,
				cr.RequirementId,
				cr.CustomerId,
				cr.DisplayOrder,
				cr.FreeTextAnswer,
				cr.Comment,
				cr.AddedDate,
				cr.ModifiedDate,
				cr.Recertification,
				cr.CustomerCertificationDetailsId
			FROM 
				[SBSC].[CustomerResponse] cr
			WHERE 
				cr.RequirementId = @RequirementId 
				AND cr.CustomerId = @CustomerId
			ORDER BY 
				cr.AddedDate DESC
		)
		SELECT 
			lr.Id,
			lr.RequirementId,
			lr.CustomerId,
			lr.DisplayOrder,
			lr.FreeTextAnswer,
			lr.Comment,
			lr.AddedDate,
			lr.ModifiedDate,
			lr.Recertification,
			lr.CustomerCertificationDetailsId,
			-- Get Selected Answers as a JSON array
			(
				SELECT 
					csa.AnswerOptionsId AS Id
				FROM 
					[SBSC].[CustomerSelectedAnswers] csa
				INNER JOIN 
					[SBSC].[RequirementAnswerOptions] ao ON csa.AnswerOptionsId = ao.Id
				WHERE 
					csa.CustomerResponseId = lr.Id
				ORDER BY 
					ao.DisplayOrder
				FOR JSON PATH
			) AS SelectedAnswersJson,
			-- Get Documents Metadata as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CustomerDocuments] cd
				WHERE 
					cd.CustomerResponseId = lr.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			LatestResponse lr;
	END

	-- returns customer response by requirementId and customerId
    ELSE IF @Action = 'READ_BY_ID'
	BEGIN
		-- Get the most recent entry by AddedDate
		WITH LatestResponse AS
		(
			SELECT TOP 1
				cr.Id,
				cr.RequirementId,
				cr.CustomerId,
				cr.DisplayOrder,
				cr.FreeTextAnswer,
				cr.Comment,
				cr.AddedDate,
				cr.ModifiedDate,
				cr.CustomerCertificationDetailsId
			FROM 
				[SBSC].[CustomerResponse] cr
			WHERE 
				cr.Id = @Id
			ORDER BY 
				cr.AddedDate DESC
		)
		SELECT 
			lr.Id,
			lr.RequirementId,
			lr.CustomerId,
			lr.DisplayOrder,
			lr.FreeTextAnswer,
			lr.Comment,
			lr.AddedDate,
			lr.ModifiedDate,
			lr.CustomerCertificationDetailsId,
			-- Get Selected Answers as a JSON array
			(
				SELECT 
					csa.AnswerOptionsId AS Id
				FROM 
					[SBSC].[CustomerSelectedAnswers] csa
				INNER JOIN 
					[SBSC].[RequirementAnswerOptions] ao ON csa.AnswerOptionsId = ao.Id
				WHERE 
					csa.CustomerResponseId = lr.Id
				ORDER BY 
					ao.DisplayOrder
				FOR JSON PATH
			) AS SelectedAnswersJson,
			-- Get Documents Metadata as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.Size,
					cd.AddedDate,
					cd.DownloadLink
				FROM 
					[SBSC].[CustomerDocuments] cd
				WHERE 
					cd.CustomerResponseId = lr.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			LatestResponse lr;
	END

	-- updates customer response data
    ELSE IF @Action = 'UPDATE'
	BEGIN
		IF (
			(@CustomerCertificationDetailsId IS NULL) OR (@CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId FROM SBSC.CustomerResponse WHERE Id = @Id))
			)
		BEGIN
			-- Update CustomerResponse
			UPDATE [SBSC].[CustomerResponse]
			SET 
				DisplayOrder = ISNULL(@DisplayOrder, DisplayOrder),
				FreeTextAnswer = @FreeTextAnswer,
				Comment = @Comment,
				ModifiedDate = GETUTCDATE()
			WHERE 
				Id = @Id;

			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.[CustomerResponse] WHERE Id = @Id))

			-- Delete existing answers for the CustomerResponse
			DELETE FROM [SBSC].[CustomerSelectedAnswers] WHERE CustomerResponseId = @Id;
    
			-- Insert updated answers
			IF EXISTS (SELECT 1 FROM @AnswerOptions)
			BEGIN
				INSERT INTO [SBSC].[CustomerSelectedAnswers] (CustomerResponseId, AnswerOptionsId, AddedDate)
				SELECT @Id, AnswerOptionsId, GETUTCDATE()
				FROM @AnswerOptions;
			END

			-- Insert new documents
			IF EXISTS (SELECT 1 FROM @CustomerDocuments)
			BEGIN
				INSERT INTO [SBSC].[CustomerDocuments] (CustomerResponseId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
				SELECT @Id, DocumentName, DocumentType, UploadId, Size, GETUTCDATE(), DownloadLink
				FROM @CustomerDocuments;
			END

			-- Get the current FreeTextAnswer and Comment for the response
			DECLARE @CurrentFreeTextAnswer NVARCHAR(MAX)
			DECLARE @CurrentComment NVARCHAR(MAX)
    
			SELECT 
				@CurrentFreeTextAnswer = FreeTextAnswer,
				@CurrentComment = Comment
			FROM [SBSC].[CustomerResponse]
			WHERE Id = @Id;

			DECLARE @CurrentRecertificationYear INT = NULL;

			select @CurrentRecertificationYear = Recertification 
			from sbsc.Customer_Certifications cc
			JOIN SBSC.Chapter ch ON ch.CertificationId = cc.CertificateId
			JOIN SBSC.RequirementChapters rc ON rc.ChapterId = ch.Id
			WHERE rc.RequirementId = (SELECT RequirementId FROM SBSC.CustomerResponse WHERE Id = @Id)
				AND cc.CustomerId = (SELECT CustomerId FROM SBSC.CustomerResponse WHERE Id = @Id)

			SELECT @RequirementId = RequirementId FROM SBSC.CustomerResponse WHERE Id = @Id

			-- Final SELECT with IsAnswered logic
			SELECT 
				@Id AS Id,
				@RequirementId AS RequirementId,
				@CurrentFreeTextAnswer AS FreeTextAnswer,
				@CustomerCertificationDetailsId AS CustomerCertificationDetailsId,
				@CurrentComment AS Comment,
				CAST(
					CASE 
						WHEN (SELECT IsFileUploadRequired 
							  FROM [SBSC].[Requirement] r
							  JOIN [SBSC].[CustomerResponse] cr ON r.Id = cr.RequirementId
							  WHERE cr.Id = @Id) = 1 THEN
							-- If file upload is required, check both new and existing files
							CASE WHEN EXISTS (SELECT 1 FROM @CustomerDocuments)
									  OR EXISTS (SELECT 1 FROM [SBSC].[CustomerDocuments] 
											   WHERE CustomerResponseId = @Id) 
								 THEN 1 
								 ELSE 0 
							END
						ELSE
							-- If file upload is not required, check for comment or answer
							CASE WHEN ((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 1 AND @CurrentFreeTextAnswer IS NOT NULL)
									THEN 1
								WHEN (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 2 AND EXISTS (
									SELECT 1 
									FROM [SBSC].[CustomerSelectedAnswers] csa
									WHERE (SELECT RequirementTypeOptionId FROM SBSC.RequirementAnswerOptions WHERE ID = (SELECT TOP 1 AnswerOptionsId FROM @AnswerOptions)) = 1
									AND 
									(@CurrentRecertificationYear <= 0 OR EXISTS (
										SELECT 1
										FROM [SBSC].[CustomerResponse] cr_inner
										WHERE cr_inner.Id = csa.CustomerResponseId
										AND cr_inner.Recertification = @CurrentRecertificationYear
									))
									) THEN 0
								WHEN (
									(SELECT RequirementTypeId 
									 FROM SBSC.Requirement 
									 WHERE Id = @RequirementId) IN (2, 3, 4)
									AND EXISTS (
										SELECT 1
										FROM sbsc.CustomerSelectedAnswers csa
										INNER JOIN SBSC.CustomerResponse cres ON cres.Id = csa.CustomerResponseId
										WHERE csa.CustomerResponseId = @Id
										AND csa.AnswerOptionsId IS NOT NULL
										AND (@CurrentRecertificationYear <= 0 OR cres.Recertification = @CurrentRecertificationYear)
									)
								) THEN 1

								WHEN((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @RequirementId) = 5 )
									THEN
										CASE
											WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @RequirementId) = 0
												AND (SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @RequirementId) = 0)
													THEN 1
											WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
												AND (SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
												AND (@CurrentComment IS NOT NULL OR  (EXISTS (SELECT 1 FROM @CustomerDocuments)
														  OR EXISTS (SELECT 1 FROM [SBSC].[CustomerDocuments] 
																   WHERE CustomerResponseId = @Id))))
													THEN 1
											WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
												AND (EXISTS (SELECT 1 FROM @CustomerDocuments)
														  OR EXISTS (SELECT 1 FROM [SBSC].[CustomerDocuments] 
																   WHERE CustomerResponseId = @Id)))
													THEN 1
											WHEN ((SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @RequirementId) = 1
												AND (@CurrentComment IS NOT NULL))
													THEN 1
											ELSE 0
										END
								ELSE 0
							END
						END AS INT) AS IsAnswered
		END
		ELSE
		BEGIN
			-- Get RequirementId and CustomerId from existing response
			DECLARE @ExistingRequirementId INT;
			DECLARE @ExistingCustomerId INT;
    
			SELECT 
				@ExistingRequirementId = RequirementId,
				@ExistingCustomerId = CustomerId
			FROM [SBSC].[CustomerResponse] 
			WHERE Id = @Id;

			-- Get Recertification from CustomerCertificationDetails
			DECLARE @NewRecertification INT;
			SELECT @NewRecertification = Recertification 
			FROM SBSC.CustomerCertificationDetails 
			WHERE ID = @CustomerCertificationDetailsId;

			-- Determine DisplayOrder if NULL
			IF @DisplayOrder IS NULL
			BEGIN
				SELECT @DisplayOrder = ISNULL(MAX(DisplayOrder), 0) + 1
				FROM [SBSC].[CustomerResponse]
				WHERE CustomerId = @ExistingCustomerId 
				  AND RequirementId = @ExistingRequirementId 
				  AND CustomerCertificationDetailsId = @CustomerCertificationDetailsId;
			END

			-- Insert new CustomerResponse
			INSERT INTO [SBSC].[CustomerResponse] (
				RequirementId, 
				CustomerId, 
				DisplayOrder, 
				FreeTextAnswer, 
				Comment, 
				AddedDate, 
				ModifiedDate,
				Recertification,
				CustomerCertificationDetailsId
			)
			VALUES (
				@ExistingRequirementId, 
				@ExistingCustomerId, 
				@DisplayOrder, 
				@FreeTextAnswer, 
				@Comment, 
				GETUTCDATE(), 
				GETUTCDATE(),
				@NewRecertification,
				@CustomerCertificationDetailsId
			);

			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)

			-- Get the newly created response ID
			DECLARE @NewResponseIdRecertification INT = SCOPE_IDENTITY();

			-- Insert into CustomerSelectedAnswers for multiple AnswerOptions
			IF EXISTS (SELECT 1 FROM @AnswerOptions)
			BEGIN
				INSERT INTO [SBSC].[CustomerSelectedAnswers] (CustomerResponseId, AnswerOptionsId, AddedDate)
				SELECT @NewResponseIdRecertification, AnswerOptionsId, GETUTCDATE()
				FROM @AnswerOptions;
			END

			-- Insert new documents
			IF EXISTS (SELECT 1 FROM @CustomerDocuments)
			BEGIN
				INSERT INTO [SBSC].[CustomerDocuments] (CustomerResponseId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
				SELECT @NewResponseIdRecertification, DocumentName, DocumentType, UploadId, Size, GETUTCDATE(), DownloadLink
				FROM @CustomerDocuments;
			END

			-- Calculate IsAnswered for the new response (same logic as CREATE)
			SELECT 
				@NewResponseIdRecertification AS Id,
				@ExistingRequirementId AS RequirementId,
				@FreeTextAnswer AS FreeTextAnswer, 
				(SELECT CustomerCertificationDetailsId FROM SBSC.CustomerResponse WHERE Id = @Id) AS CustomerCertificationDetailsId, --Return the customerCertificationDetails of previous audit year
				@Comment AS Comment,
				CAST(
					CASE 
						WHEN (SELECT IsFileUploadRequired 
							  FROM [SBSC].[Requirement] 
							  WHERE Id = @ExistingRequirementId) = 1 THEN
							-- If file upload is required, check if files exist
							CASE WHEN EXISTS (SELECT 1 FROM @CustomerDocuments) THEN 1 ELSE 0 END
						ELSE
							-- If file upload is not required, check for comment or answer
							CASE 
								WHEN ((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 1 AND @FreeTextAnswer IS NOT NULL)
									THEN 1
								WHEN (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 2 AND EXISTS (
									SELECT 1 
									FROM [SBSC].[CustomerSelectedAnswers] csa
									WHERE (SELECT RequirementTypeOptionId FROM SBSC.RequirementAnswerOptions WHERE ID = (SELECT TOP 1 AnswerOptionsId FROM @AnswerOptions)) = 1
									AND 
										(@NewRecertification <= 0 OR EXISTS (
										SELECT 1
										FROM [SBSC].[CustomerResponse] cr_inner
										WHERE cr_inner.Id = csa.CustomerResponseId
										AND cr_inner.Recertification = @NewRecertification
									))
									) THEN 0
								WHEN (((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 2
									OR (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 3
									OR (SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 4 )
									AND EXISTS (
										SELECT 1
										FROM sbsc.[CustomerSelectedAnswers]    
										INNER JOIN SBSC.CustomerResponse cres ON cres.Id = CustomerResponseId
										WHERE CustomerResponseId = @NewResponseIdRecertification
										AND AnswerOptionsId IS NOT NULL
										AND (@NewRecertification <= 0 OR cres.Recertification = @NewRecertification)
									)) THEN 1
								WHEN((SELECT RequirementTypeId FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 5 )
									THEN
										CASE
											WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 0
												AND (SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 0)
													THEN 1
											WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 1
												AND (SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 1
												AND (@Comment IS NOT NULL OR EXISTS (SELECT 1 FROM @CustomerDocuments)))
													THEN 1
											WHEN ((SELECT IsFileUploadAble FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 1
												AND EXISTS (SELECT 1 FROM @CustomerDocuments))
													THEN 1
											WHEN ((SELECT IsCommentable FROM SBSC.Requirement WHERE Id = @ExistingRequirementId) = 1
												AND (@Comment IS NOT NULL))
													THEN 1
											ELSE 0
										END
								ELSE 0
							END
						END AS INT) AS IsAnswered
		END
	END

	-- deletes customer response
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.[CustomerResponse] WHERE Id = @Id))

            DELETE FROM [SBSC].[CustomerResponse] WHERE Id = @Id;

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

	-- lists all customer response of customer
    ELSE IF @Action = 'LIST'
	BEGIN
		-- Validate and sanitize the sort column
		IF @SortColumn NOT IN ('Id', 'RequirementId', 'AddedDate')
			SET @SortColumn = 'AddedDate';

		-- Validate the sort direction
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC';

		-- Declare variables for dynamic SQL and pagination
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(MAX);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;  -- Initialize the total records variable
		DECLARE @TotalPages INT;

		-- Define the WHERE clause for filtering by CustomerId
		SET @WhereClause = N'WHERE CustomerId = @CustomerId';

		-- Add optional search filtering if needed
		IF @SearchValue IS NOT NULL
			SET @WhereClause = @WhereClause + N' 
				AND (
					CAST(RequirementId AS NVARCHAR(50)) LIKE ''%'' + @SearchValue + ''%'' 
					OR FreeTextAnswer LIKE ''%'' + @SearchValue + ''%''
				)';

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(*)
			FROM [SBSC].[CustomerResponse] cr
			' + @WhereClause;

		-- Define parameter types for sp_executesql
		SET @ParamDefinition = N'
			@CustomerId INT, 
			@SearchValue NVARCHAR(100), 
			@TotalRecords INT OUTPUT';

		-- Execute the total count query and assign the result to @TotalRecords
		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@CustomerId, 
			@SearchValue, 
			@TotalRecords OUTPUT;

		-- Calculate total pages based on @TotalRecords
		SET @TotalPages = CASE 
			WHEN @TotalRecords > 0 
			THEN CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize) 
			ELSE 0 
		END;

		-- Retrieve paginated data with SelectedAnswersJson
		SET @SQL = N'
			SELECT 
				cr.Id,
				cr.RequirementId,
				cr.CustomerId,
				cr.DisplayOrder,
				cr.FreeTextAnswer,
				cr.Comment,
				cr.AddedDate,
				cr.ModifiedDate,
				cr.[CustomerCertificationDetailsId],
				-- Get Selected Answers as a JSON array
				(
					SELECT 
						csa.AnswerOptionsId AS Id
					FROM 
						[SBSC].[CustomerSelectedAnswers] csa
					INNER JOIN 
						[SBSC].[RequirementAnswerOptions] ao ON csa.AnswerOptionsId = ao.Id
					WHERE 
						csa.CustomerResponseId = cr.Id
					ORDER BY 
						ao.DisplayOrder
					FOR JSON PATH
				) AS SelectedAnswersJson,
				-- Get Documents Metadata as a JSON array
				(
					SELECT 
						cd.Id AS DocumentId,
						cd.DocumentName,
						cd.DocumentType,
						cd.Size,
						cd.AddedDate,
						cd.DownloadLink
					FROM 
						[SBSC].[CustomerDocuments] cd
					WHERE 
						cd.CustomerResponseId = cr.Id
					FOR JSON PATH
				) AS DocumentsJson
			FROM 
				[SBSC].[CustomerResponse] cr
			' + @WhereClause + '
			ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
			OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
			FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

		-- Execute the paginated query
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
    
	-- get specific document
	ELSE IF @Action = 'GETDOCUMENT'
    BEGIN
		SELECT DocumentName, AddedDate, DownloadLink 
		FROM [SBSC].[CustomerDocuments] 
		WHERE Id = @DocumentId;
    END

	-- delete document
	ELSE IF @Action = 'DELETEDOCUMENT'
    BEGIN
        BEGIN TRY
			UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = (SELECT CustomerCertificationDetailsId
						FROM SBSC.[CustomerResponse] WHERE Id = (
								SELECt CustomerResponseId 
								FROM SBSC.CustomerDocuments
								WHERE Id = @DocumentId)))

            DELETE FROM [SBSC].[CustomerDocuments] WHERE Id = @DocumentId;

            SELECT @DocumentId AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @DeleteDocumentErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @DeleteDocumentErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @DeleteDocumentErrorState INT = ERROR_STATE()

            RAISERROR(@DeleteDocumentErrorMessage, @DeleteDocumentErrorSeverity, @DeleteDocumentErrorState)
        END CATCH
    END

	-- Recreate document
	ELSE IF @Action = 'RECREATE_DOCUMENT'
        BEGIN
            BEGIN TRY
                -- Create a temporary table to store original document information
                DECLARE @OriginalDocs TABLE (
                    DocumentName NVARCHAR(500),
                    DocumentType NVARCHAR(100),
                    UploadId NVARCHAR(128),
                    Size NVARCHAR(50),
                    NewDocumentName NVARCHAR(500),
                    OriginalAddedDate DATETIME,
                    NewAddedDate DATETIME,
                    DownloadLink NVARCHAR(MAX)
                );
                
                DECLARE @CurrentDate DATETIME = GETUTCDATE();

                -- Get documents based on whether specific IDs are provided
                IF NOT EXISTS (SELECT 1 FROM @PreviousDocumentIds)
				BEGIN
                    -- Original functionality - get all documents from the second most recent response
                    INSERT INTO @OriginalDocs (DocumentName, DocumentType, UploadId, Size, NewDocumentName, OriginalAddedDate, NewAddedDate, DownloadLink)
                    SELECT 
                        CD.DocumentName, 
                        CD.DocumentType, 
                        CD.UploadId, 
                        CD.Size,
                        CONCAT(LEFT(NEWID(), 8), SUBSTRING(CD.DocumentName, 9, LEN(CD.DocumentName))) AS NewDocumentName,
                        CD.AddedDate AS OriginalAddedDate,
                        @CurrentDate AS NewAddedDate,
                        DownloadLink
                    FROM SBSC.CustomerDocuments CD
                    WHERE CD.CustomerResponseId IN (
                        SELECT ID FROM SBSC.CustomerResponse 
                            WHERE RequirementId = @RequirementId AND CustomerId = @CustomerId AND CustomerCertificationDetailsId = @CustomerCertificationDetailsId
                    );
                END
                ELSE
                BEGIN
                    -- Get only specific documents by their IDs
                    INSERT INTO @OriginalDocs (DocumentName, DocumentType, UploadId, Size, NewDocumentName, OriginalAddedDate, NewAddedDate, DownloadLink)
                    SELECT 
                        CD.DocumentName, 
                        CD.DocumentType, 
                        CD.UploadId, 
                        CD.Size,
                        CONCAT(LEFT(NEWID(), 8), SUBSTRING(CD.DocumentName, 9, LEN(CD.DocumentName))) AS NewDocumentName,
                        CD.AddedDate AS OriginalAddedDate,
                        @CurrentDate AS NewAddedDate,
                        DownloadLink
                    FROM SBSC.CustomerDocuments CD
                    INNER JOIN @PreviousDocumentIds ids ON CD.Id = ids.Id;
                END
                
                -- Insert documents with new filenames for the new response
                INSERT INTO [SBSC].[CustomerDocuments] (CustomerResponseId, DocumentName, DocumentType, UploadId, Size, AddedDate, DownloadLink)
                SELECT 
                    @NewResponseId, 
                    NewDocumentName, 
                    DocumentType, 
                    UploadId, 
                    Size, 
                    @CurrentDate, 
                    DownloadLink
                FROM @OriginalDocs;
                
                -- Return original and new document names for blob copying along with dates
                SELECT 
                    DocumentName AS OriginalDocumentName,
                    NewDocumentName AS NewDocumentName,
                    OriginalAddedDate AS OriginalAddedDate,
                    NewAddedDate AS NewAddedDate
                FROM @OriginalDocs;
            END TRY
            BEGIN CATCH
                IF @@TRANCOUNT > 0
                    ROLLBACK TRANSACTION
                
                DECLARE @RecreateDocumentErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
                DECLARE @RecreateDocumentErrorSeverity INT = ERROR_SEVERITY()
                DECLARE @RecreateDocumentErrorState INT = ERROR_STATE()
                RAISERROR(@RecreateDocumentErrorMessage, @RecreateDocumentErrorSeverity, @RecreateDocumentErrorState)
            END CATCH
        END

	ELSE IF @Action = 'SUBMIT_CERTIFICATE'
	BEGIN
		-- Determine submission status based on DeviationEndDate
		DECLARE @SubmissionStatus INT;
		IF @DeviationEndDate IS NULL
		BEGIN
			-- If no deviation end date, set status to 1 (submitted to auditor)
			SET @SubmissionStatus = 1;
			SET @UserType = 'Customer';
		END
		ELSE
		BEGIN
			-- If deviation end date is provided, set status to 2 (deviation needed for further audit)
			SET @SubmissionStatus = 2;
			SET @UserType = 'Auditor';
		END

		IF @AssignmentId IS NOT NULL
		BEGIN
			UPDATE SBSC.AssignmentOccasions
			SET 
				Status = @SubmissionStatus,
				LastUpdatedDate = GETUTCDATE()
			WHERE Id = @AssignmentId;

			INSERT INTO SBSC.AssignmentOccasionStatusHistory(AssignmentOccasionId, [Status], StatusDate, SubmittedByUserType, SubmittedBy)
			VALUES(@AssignmentId, @SubmissionStatus, GETUTCDATE(), @UserType, @UserId)
	
			-- Step 1: Update CustomerCertificationDetails.Status for all customerCertificationDetailsId present in the AssignmentId
			UPDATE SBSC.CustomerCertificationDetails
			SET 
				Status = @SubmissionStatus,
				DeviationEndDate = @DeviationEndDate
			WHERE Id IN (
				SELECT DISTINCT CustomerCertificationDetailsId
				FROM SBSC.AssignmentCustomerCertification 
				WHERE AssignmentId = @AssignmentId
			);
	
			-- Step 2: Get distinct CustomerCertificationId from CustomerCertificationDetails
			DECLARE @CustomerCertificationIds TABLE (CustomerCertificationId INT);
			DECLARE @CertificationCount INT;
	
			INSERT INTO @CustomerCertificationIds (CustomerCertificationId)
			SELECT DISTINCT ccd.CustomerCertificationId
			FROM SBSC.CustomerCertificationDetails ccd
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON ccd.Id = acc.CustomerCertificationDetailsId
			WHERE acc.AssignmentId = @AssignmentId;
		
			SELECT @CertificationCount = COUNT(*) FROM @CustomerCertificationIds;
	
			-- Step 3: Apply logic for each CustomerCertificationId
			DECLARE @CurrentCertificationId INT;
			DECLARE cert_cursor CURSOR FOR 
				SELECT CustomerCertificationId FROM @CustomerCertificationIds;
	
			OPEN cert_cursor;
			FETCH NEXT FROM cert_cursor INTO @CurrentCertificationId;
	
			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Count how many CustomerCertificationDetails exist for this CustomerCertificationId
				DECLARE @DetailsCount INT;
				SELECT @DetailsCount = COUNT(*) 
				FROM SBSC.CustomerCertificationDetails 
				WHERE CustomerCertificationId = @CurrentCertificationId;
		
				-- If only one CustomerCertificationDetails exists, directly update Customer_Certifications
				IF @DetailsCount = 1
				BEGIN
					UPDATE SBSC.Customer_Certifications
					SET 
						SubmissionStatus = @SubmissionStatus,
						DeviationEndDate = @DeviationEndDate
					WHERE CustomerCertificationId = @CurrentCertificationId;
				END
				ELSE
				BEGIN
					-- Check if all CustomerCertificationDetails for this CustomerCertificationId have the same status
					DECLARE @ShouldUpdateStatus BIT = 1;
				
					-- Check if there are any CustomerCertificationDetails with different status
					IF EXISTS (
						SELECT 1 
						FROM SBSC.CustomerCertificationDetails ccd
						WHERE ccd.CustomerCertificationId = @CurrentCertificationId
						AND ccd.Status != @SubmissionStatus
					)
					BEGIN
						SET @ShouldUpdateStatus = 0;
					END
			
					-- Update Customer_Certifications if all details have same status
					IF @ShouldUpdateStatus = 1
					BEGIN
						UPDATE SBSC.Customer_Certifications
						SET 
							SubmissionStatus = @SubmissionStatus,
							DeviationEndDate = @DeviationEndDate
						WHERE CustomerCertificationId = @CurrentCertificationId;
					END
					-- If @ShouldUpdateStatus = 0, we don't update (keep submissionStatus as it is)
				END
		
				FETCH NEXT FROM cert_cursor INTO @CurrentCertificationId;
			END
	
			CLOSE cert_cursor;
			DEALLOCATE cert_cursor;
		END
		ELSE
		BEGIN
			-- Update the certification record when no AssignmentId
			UPDATE SBSC.Customer_Certifications
			SET 
				SubmissionStatus = @SubmissionStatus,
				DeviationEndDate = @DeviationEndDate
			WHERE 
				CustomerId = @CustomerId AND CertificateId = @CertificationId;
		END

		-- Return success
		SELECT 1 AS Result;
	END
	-- -1) if count of customerCertificationids == 1, then directly update the submissionStatus to be @SubmissionStatus
	-- -2) if all other assignments with that customerCertificationId has same status of @SubmissionStatus, then set the submissionStatus to be the same as other SubmissionStatus
	-- -3) if none of the condition are met then set the submissionStatus to be same as it is previously.


	ELSE IF @Action = 'SUBMIT_CERTIFICATE_REPORT'
	BEGIN
		IF NOT EXISTS (
			SELECT 1 
			FROM SBSC.AssignmentOccasions
			WHERE Id = @AssignmentId
		)
		BEGIN
			RAISERROR('Invalid AssignmentId for report', 16, 1);
			RETURN;
		END

		SET @SubmissionStatus = 3;

		IF @AssignmentId IS NOT NULL
		BEGIN
			UPDATE SBSC.AssignmentOccasions
			SET 
				Status = @SubmissionStatus,
				LastUpdatedDate = GETUTCDATE()
			WHERE Id = @AssignmentId;

			INSERT INTO SBSC.AssignmentOccasionStatusHistory(AssignmentOccasionId, [Status], StatusDate, SubmittedByUserType, SubmittedBy)
			VALUES(@AssignmentId, @SubmissionStatus, GETUTCDATE(), 'Auditor', @UserId)


			-- Step 1: Update CustomerCertificationDetails.Status for all customerCertificationDetailsId present in the AssignmentId
			UPDATE SBSC.CustomerCertificationDetails
			SET 
				Status = @SubmissionStatus
			WHERE Id IN (
				SELECT DISTINCT CustomerCertificationDetailsId
				FROM SBSC.AssignmentCustomerCertification 
				WHERE AssignmentId = @AssignmentId
			);

			-- Step 2: Get distinct CustomerCertificationId from CustomerCertificationDetails
			DECLARE @ReportCustomerCertificationIds TABLE (CustomerCertificationId INT);
			DECLARE @ReportCertificationCount INT;

			INSERT INTO @ReportCustomerCertificationIds (CustomerCertificationId)
			SELECT DISTINCT ccd.CustomerCertificationId
			FROM SBSC.CustomerCertificationDetails ccd
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON ccd.Id = acc.CustomerCertificationDetailsId
			WHERE acc.AssignmentId = @AssignmentId;
		
			SELECT @ReportCertificationCount = COUNT(*) FROM @ReportCustomerCertificationIds;

			-- Step 3: Apply logic for each CustomerCertificationId
			DECLARE @ReportCurrentCertificationId INT;
			DECLARE report_cert_cursor CURSOR FOR 
				SELECT CustomerCertificationId FROM @ReportCustomerCertificationIds;

			OPEN report_cert_cursor;
			FETCH NEXT FROM report_cert_cursor INTO @ReportCurrentCertificationId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Count how many CustomerCertificationDetails exist for this CustomerCertificationId
				DECLARE @ReportDetailsCount INT;
				SELECT @ReportDetailsCount = COUNT(*) 
				FROM SBSC.CustomerCertificationDetails 
				WHERE CustomerCertificationId = @ReportCurrentCertificationId;
		
				-- If only one CustomerCertificationDetails exists, directly update Customer_Certifications
				IF @ReportDetailsCount = 1
				BEGIN
					UPDATE SBSC.Customer_Certifications
					SET 
						SubmissionStatus = @SubmissionStatus
					WHERE CustomerCertificationId = @ReportCurrentCertificationId;
				END
				ELSE
				BEGIN
					-- Check if all CustomerCertificationDetails for this CustomerCertificationId have the same status
					DECLARE @ReportShouldUpdateStatus BIT = 1;
				
					-- Check if there are any CustomerCertificationDetails with different status
					IF EXISTS (
						SELECT 1 
						FROM SBSC.CustomerCertificationDetails ccd
						WHERE ccd.CustomerCertificationId = @ReportCurrentCertificationId
						AND ccd.Status != @SubmissionStatus
					)
					BEGIN
						SET @ReportShouldUpdateStatus = 0;
					END
			
					-- Update Customer_Certifications if all details have same status
					IF @ReportShouldUpdateStatus = 1
					BEGIN
						UPDATE SBSC.Customer_Certifications
						SET 
							SubmissionStatus = @SubmissionStatus
						WHERE CustomerCertificationId = @ReportCurrentCertificationId;
					END
					-- If @ReportShouldUpdateStatus = 0, we don't update (keep submissionStatus as it is)
				END
		
				FETCH NEXT FROM report_cert_cursor INTO @ReportCurrentCertificationId;
			END

			CLOSE report_cert_cursor;
			DEALLOCATE report_cert_cursor;
		END
		ELSE
		BEGIN
			-- Original logic when no AssignmentId
			UPDATE SBSC.Customer_Certifications
			SET 
				SubmissionStatus = @SubmissionStatus
			WHERE 
				CustomerId = @CustomerId AND CertificateId = @CertificationId;
		END

		-- Return success
		SELECT 1 AS Result;
	END

	ELSE
    BEGIN
        -- Invalid action
        SELECT 'Invalid Action' AS Message;
    END
END;
GO