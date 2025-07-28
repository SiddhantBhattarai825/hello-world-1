SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_RequirementResponses] 
	@Action NVARCHAR(50),
    @CustomerId INT = NULL,
	@RequirementId INT = NULL,
	@CommentPageNumber INT = 1,
    @CommentPageSize INT = 5,
	@HistoryPageSize INT = 1000,
	@LangId INT = NULL,
	@AuditorId INT = NULL,
	--@Recertification INT = NULL,
	@CustomerCertificationDetailsId INT = NULL
AS

BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('ALLRESPONSES', 'LOAD_MORE', 'RESPONSE_HISTORY')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use ALLRESPONSES, RESPONSE_HISTORY or LOAD_MORE.', 16, 1);
        RETURN;
    END

	DECLARE @CustomerCertificationId INT;

	IF @Action = 'RESPONSE_HISTORY' 
	BEGIN
		IF @LangId IS NULL 
		BEGIN 
			DECLARE @DefaultLangIdRead INT; 
			SELECT TOP 1 @DefaultLangIdRead = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLangIdRead; 
		END 

		SET @CustomerCertificationId = (SELECT CustomerCertificationId FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId)
												
		-- FIRST RESULT SET: Customer Response
		;WITH LatestResponse AS
		(
			SELECT
				cr.Id,
				cr.RequirementId,
				cr.CustomerId,
				cr.DisplayOrder,
				cr.FreeTextAnswer,
				cr.Comment,
				cr.AddedDate,
				cr.ModifiedDate,
				cr.Recertification
			FROM 
				[SBSC].[CustomerResponse] cr
			WHERE 
				cr.RequirementId = @RequirementId 
				AND cr.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
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
			NULL AS PreviousAuditYear,
			--CASE 
			--	WHEN ((SELECT MAX(Recertification) FROM [SBSC].[CustomerResponse] WHERE CustomerId = @CustomerId AND RequirementId = @RequirementId) = 0) THEN NULL
			--	WHEN ((SELECT MAX(Recertification) FROM [SBSC].[CustomerResponse] WHERE CustomerId = @CustomerId AND RequirementId = @RequirementId) = 1) THEN 
			--		(SELECT IssueDate FROM [SBSC].[Customer_Certifications] WHERE CustomerCertificationId = @CustomerCertificationId)
			--	ELSE 
			--		(SELECT TOP 1 AuditDate 
			--		 FROM [SBSC].[CustomerRecertificationAudits] 
			--		 WHERE CustomerCertificationId = @CustomerCertificationId 
			--		   AND Recertification = 
			--				((SELECT MAX(Recertification) 
			--				 FROM [SBSC].[CustomerRecertificationAudits] 
			--				 WHERE CustomerCertificationId = @CustomerCertificationId) - 1)
			--		 ORDER BY Id DESC
			--		)
			--END AS PreviousAuditYear,

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
					cd.Size,
					cd.AddedDate
				FROM 
					[SBSC].[CustomerDocuments] cd
				WHERE 
					cd.CustomerResponseId = lr.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			LatestResponse lr
		ORDER BY 
			lr.AddedDate DESC;


		-- SECOND RESULT SET: Auditor Response
		IF EXISTS (SELECT cr.Id FROM [SBSC].[CustomerResponse] cr WHERE cr.RequirementId = @RequirementId AND cr.CustomerCertificationDetailsId = @CustomerCertificationDetailsId)
		BEGIN
			SELECT
				acr.*,
				(SELECT JSON_OBJECT('Id': an.Id, 'Note': an.Note)
				 FROM [SBSC].[AuditorNotes] an 
				 WHERE an.CustomerResponseId = acr.CustomerResponseId
				 ) AS AuditorNote
			FROM [SBSC].[AuditorCustomerResponses] acr
			JOIN SBSC.CustomerResponse cr ON cr.Id = acr.CustomerResponseId
			WHERE cr.RequirementId = @RequirementId 
				AND cr.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
			ORDER BY acr.ResponseDate DESC;
		END
		ELSE
		BEGIN
			-- Return empty result set with schema
			SELECT TOP 0 * FROM [SBSC].[AuditorCustomerResponses];
		END

		-- THIRD RESULT SET: Auditor Notes
		SELECT Id, Note
				 FROM [SBSC].[AuditorNotes]  
				 WHERE CustomerResponseId IN (SELECT cr.Id
								FROM [SBSC].[CustomerResponse] cr
								WHERE cr.RequirementId = @RequirementId 
								  AND cr.CustomerCertificationDetailsId = @CustomerCertificationDetailsId)
				 ORDER BY CreatedDate DESC
    
		-- FOURTH RESULT SET: Requirement Notes
		SELECT Notes FROM SBSC.RequirementLanguage WHERE RequirementId = @RequirementId AND LangId = @LangId;

		-- FIFTH RESULT SET: Comment Threads Metadata for Pagination
		DECLARE @TotalThreadsCount INT;
		DECLARE @TotalPage INT;

		-- Get the total thread count
		SELECT @TotalThreadsCount = COUNT(*)
		FROM (
			SELECT DISTINCT c.Id
			FROM [SBSC].[CommentThread] c
			WHERE c.RequirementId = @RequirementId
				AND c.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
				AND c.ParentCommentId IS NULL
		) AS UniqueThreads;

		-- Calculate total pages
		SET @TotalPage = CEILING(@TotalThreadsCount * 1.0 / @HistoryPageSize);

		-- Ensure page number doesn't exceed total pages
		DECLARE @ValidatedPageNumbers INT = 
			CASE 
				WHEN @HistoryPageSize <= 0 THEN 1
				WHEN @HistoryPageSize > @TotalPage AND @TotalPage > 0 THEN @TotalPage
				WHEN @TotalPage = 0 THEN 1
				ELSE @HistoryPageSize
			END;

		-- Return pagination metadata
		SELECT 
			CAST(@TotalThreadsCount AS INT) AS TotalCount,
			CAST(@TotalPage AS INT) AS TotalPages,
			CAST(@ValidatedPageNumbers AS INT) AS CurrentPage,
			CAST(@HistoryPageSize AS INT) AS PageSize,
			CASE WHEN @ValidatedPageNumbers < @TotalPage THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasNextPage,
			CASE WHEN @ValidatedPageNumbers > 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasPreviousPage;
    
		-- SIXTH RESULT SET: Paginated Comment Threads
		;WITH RootComments AS (
			-- Find root comments for this requirement with pagination
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
				CAST(c.Id AS VARCHAR(255)) AS ThreadGroup,
				ROW_NUMBER() OVER (ORDER BY c.CreatedDate DESC) AS RowNum
			FROM
				[SBSC].[CommentThread] c
			WHERE
				c.RequirementId = @RequirementId
				AND c.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
				AND c.ParentCommentId IS NULL
		),
		PaginatedRoots AS (
			-- Select only the root comments for the current page
			SELECT *
			FROM RootComments
			WHERE RowNum BETWEEN ((@ValidatedPageNumbers - 1) * @HistoryPageSize + 1) AND (@ValidatedPageNumbers * @HistoryPageSize)
		),
		CommentGroups AS (
			-- Include the paginated root comments
			SELECT
				rc.Id,
				rc.RequirementId,
				rc.CustomerId,
				rc.AuditorId,
				rc.ParentCommentId,
				rc.Comment,
				rc.CreatedDate,
				rc.CustomerCommentTurn,
				rc.ReadStatus,
				rc.ThreadGroup,
				CAST(0 AS INT) AS Level
			FROM
				PaginatedRoots rc
			
			UNION ALL
			
			-- Add all replies to the paginated root comments
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
				cg.ThreadGroup,
				cg.Level + 1 AS Level
			FROM
				[SBSC].[CommentThread] c
			INNER JOIN
				CommentGroups cg ON c.ParentCommentId = cg.Id
		)
		SELECT 
			cg.Id,
			cg.RequirementId,
			CASE WHEN cg.AuditorId IS NOT NULL THEN NULL ELSE cg.CustomerId END AS CustomerId,
			cg.AuditorId,
			cg.ParentCommentId,
			cg.Comment,
			cg.CreatedDate,
			cg.CustomerCommentTurn,
			cg.ReadStatus,
			cg.ThreadGroup,
			-- Get reply count for root comments
			(
				SELECT COUNT(*)
				FROM [SBSC].[CommentThread] replies
				WHERE replies.ParentCommentId = cg.Id
			) AS ReplyCount,
			-- Get Documents as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.Size,
					cd.AddedDate
				FROM 
					[SBSC].[CommentDocument] cd
				WHERE 
					cd.CommentId = cg.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			CommentGroups cg
		ORDER BY 
			--cg.ThreadGroup, --DESC,  -- Newest thread groups first
			--cg.Level,             -- Keep hierarchy within threads
			cg.CreatedDate DESC;  -- Newest comments first within each level
	END

    -- READ all responses operation 
	IF @Action = 'ALLRESPONSES' 
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId)
		BEGIN
			RAISERROR ('CustomerCertificationDetailsId doesnot exists.', 16, 1);
			RETURN;
		END


		IF @LangId IS NULL 
		BEGIN 
			DECLARE @DefaultLanguageIdRead INT; 
			SELECT TOP 1 @DefaultLanguageIdRead = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLanguageIdRead; 
		END 

		SELECT @CustomerCertificationId = CustomerCertificationId 
			FROM [SBSC].CustomerCertificationDetails
			WHERE Id = @CustomerCertificationDetailsId;

		---- Get the Recertification value from customer_certification table
		--SELECT @Recertification = Recertification 
		--FROM SBSC.Customer_Certifications
		--WHERE CustomerCertificationId = @CustomerCertificationId
		--AND CustomerId = @CustomerId;

		DECLARE @CustomerResponseId INT;
    
		-- Get the latest response ID and store it in the variable
		SELECT TOP 1 @CustomerResponseId = cr.Id
		FROM [SBSC].[CustomerResponse] cr
		WHERE cr.RequirementId = @RequirementId 
		  AND cr.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
		ORDER BY cr.AddedDate DESC;
    
		DECLARE @CustomerCertId INT = NULL,
			@AddressId INT = NULL,
			@DepartmentId INT = NULL

		SELECT @CustomerCertId = CustomerCertificationId,
			@AddressId = AddressId,
			@DepartmentId = DepartmentId
		FROM SBSC.CustomerCertificationDetails
		WHERE Id = @CustomerCertificationDetailsId


		IF EXISTS (SELECT 1 FROM SBSC.CustomerResponse WHERE Id = @CustomerResponseId)
		BEGIN
			SELECT 
				cr.Id,
				cr.RequirementId,
				cr.CustomerId,
				cr.DisplayOrder,
				cr.FreeTextAnswer,
				cr.Comment,
				cr.AddedDate,
				cr.ModifiedDate,
				cr.Recertification,
				CASE 
					WHEN (SELECT COUNT(*) 
						  FROM SBSC.CustomerCertificationDetails 
						  WHERE CustomerCertificationId = @CustomerCertId 
							AND AddressId = @AddressId 
							AND DepartmentId = @DepartmentId) > 1
					THEN
						(
							SELECT IssueDate 
							FROM (
								SELECT IssueDate, ROW_NUMBER() OVER (ORDER BY Id DESC) AS RowNum
								FROM SBSC.CustomerCertificationDetails
								WHERE CustomerCertificationId = @CustomerCertId 
								  AND AddressId = @AddressId 
								  AND DepartmentId = @DepartmentId
							) AS RankedDetails
							WHERE RowNum = 2
						)
					ELSE NULL
				END AS PreviousAuditYear,
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
						cd.UploadId,
						cd.Size,
						cd.AddedDate,
						cd.DownloadLink
					FROM 
						[SBSC].[CustomerDocuments] cd
					WHERE 
						cd.CustomerResponseId = cr.Id
					FOR JSON PATH
				) AS DocumentsJson
			FROM SBSC.CustomerResponse cr
			WHERE 
				cr.RequirementId = @RequirementId 
				AND cr.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
		END
		ELSE IF ((SELECT IsChanged FROM SBSC.Requirement WHERE Id = @RequirementId) = 1)
		BEGIN 
			SELECT 
					NULL AS Id,
					NULL AS RequirementId,
					NULL AS CustomerId,
					NULL AS DisplayOrder,
					NULL AS FreeTextAnswer,
					NULL AS Comment,
					NULL AS AddedDate,
					NULL AS ModifiedDate,
					NULL AS Recertification,
					NULL AS PreviousAuditYear,
					NULL AS SelectedAnswersJson,
					NULL AS DocumentsJson
		END
		ELSE
		BEGIN
			IF ((SELECT COUNT(*) FROM SBSC.CustomerCertificationDetails WHERE CustomerCertificationId = @CustomerCertId AND AddressId = @AddressId AND DepartmentId = @DepartmentId) > 1)
			BEGIN
				DECLARE @DetailsId INT = NULL;

				SELECT @DetailsId = Id FROM SBSC.CustomerCertificationDetails
				WHERE CustomerCertificationId = @CustomerCertId
				AND AddressId = @AddressId
				AND DepartmentId = @DepartmentId
				AND Recertification = (
						(SELECT MAX(Recertification) 
						FROM SBSC.CustomerCertificationDetails
						WHERE CustomerCertificationId = @CustomerCertId
						AND AddressId = @AddressId
						AND DepartmentId = @DepartmentId) - 1)


				SELECT 
					cr.Id,
					cr.RequirementId,
					cr.CustomerId,
					cr.DisplayOrder,
					cr.FreeTextAnswer,
					cr.Comment,
					cr.AddedDate,
					cr.ModifiedDate,
					cr.Recertification,
					CASE 
						WHEN (SELECT COUNT(*) 
							  FROM SBSC.CustomerCertificationDetails 
							  WHERE CustomerCertificationId = @CustomerCertId 
								AND AddressId = @AddressId 
								AND DepartmentId = @DepartmentId) > 1
						THEN
							(
								SELECT TOP 1 IssueDate 
								FROM (
									SELECT IssueDate, ROW_NUMBER() OVER (ORDER BY Id DESC) AS RowNum
									FROM SBSC.CustomerCertificationDetails
									WHERE CustomerCertificationId = @CustomerCertId 
									  AND AddressId = @AddressId 
									  AND DepartmentId = @DepartmentId
								) AS RankedDetails
								WHERE RowNum = 2
							)
						ELSE NULL
					END AS PreviousAuditYear,
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
							cd.UploadId,
							cd.Size,
							cd.AddedDate,
							cd.DownloadLink
						FROM 
							[SBSC].[CustomerDocuments] cd
						WHERE 
							cd.CustomerResponseId = cr.Id
						FOR JSON PATH
					) AS DocumentsJson
				FROM SBSC.CustomerResponse cr
				JOIN SBSC.Requirement r ON cr.RequirementId = r.Id
				WHERE 
					cr.RequirementId = @RequirementId 
					AND (r.IsChanged = 0 OR r.IsChanged IS NULL)
					AND cr.CustomerCertificationDetailsId = @DetailsId
			END

			ELSE
			BEGIN
				SELECT 
					NULL AS Id,
					NULL AS RequirementId,
					NULL AS CustomerId,
					NULL AS DisplayOrder,
					NULL AS FreeTextAnswer,
					NULL AS Comment,
					NULL AS AddedDate,
					NULL AS ModifiedDate,
					NULL AS Recertification,
					NULL AS PreviousAuditYear,
					NULL AS SelectedAnswersJson,
					NULL AS DocumentsJson
			END
		END

		DECLARE @CommentIdDocument INT = NULL;

		SELECT TOP 1 @CommentIdDocument = Id
		FROM [SBSC].[CommentThread]
		WHERE RequirementId = @RequirementId 
		  AND CustomerId = (SELECT CustomerId FROM SBSC.CustomerResponse WHERE Id = @CustomerResponseId)
		  AND AuditorId = (SELECT AuditorId FROM SBSC.AuditorCustomerResponses WHERE CustomerResponseId = @CustomerResponseId)
		  AND CustomerCertificationDetailsId = @CustomerCertificationDetailsId
		ORDER BY CreatedDate;

		-- SECOND RESULT SET: Auditor Response
		IF @CustomerResponseId IS NOT NULL
		BEGIN
			SELECT TOP 1
				acr.*,
				(SELECT TOP 1 JSON_OBJECT('Id': an.Id, 'Note': an.Note)
				 FROM [SBSC].[AuditorNotes] an 
				 WHERE an.CustomerResponseId = acr.CustomerResponseId
				 ORDER BY an.CreatedDate DESC) AS AuditorNote, 
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
				) AS DocumentsJson
			FROM [SBSC].[AuditorCustomerResponses] acr
			WHERE acr.CustomerResponseId = @CustomerResponseId
			ORDER BY acr.ResponseDate DESC;
		END
		ELSE
		BEGIN
			-- Return empty result set with schema
			SELECT TOP 0 * FROM [SBSC].[AuditorCustomerResponses];
		END

		-- THIRD RESULT SET: Auditor Notes
		SELECT TOP 1 Id, Note
				 FROM [SBSC].[AuditorNotes]  
				 WHERE CustomerResponseId = @CustomerResponseId
				 ORDER BY CreatedDate DESC
    
		-- FOURTH RESULT SET: Requirement Notes
		SELECT Notes FROM SBSC.RequirementLanguage WHERE RequirementId = @RequirementId AND LangId = @LangId;

		-- FIFTH RESULT SET: Comment Threads Metadata for Pagination
		DECLARE @TotalThreadCount INT;
		DECLARE @TotalPages INT;

		-- Get the total thread count for comments that match @Recertification
		SELECT @TotalThreadCount = COUNT(*)
		FROM (
			SELECT DISTINCT c.Id
			FROM [SBSC].[CommentThread] c
			WHERE c.RequirementId = @RequirementId
				AND c.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
				AND c.ParentCommentId IS NULL
		) AS UniqueThreads;

		-- Calculate total pages
		SET @TotalPages = CEILING(@TotalThreadCount * 1.0 / @CommentPageSize);

		-- Ensure page number doesn't exceed total pages
		DECLARE @ValidatedPageNumber INT = 
			CASE 
				WHEN @CommentPageNumber <= 0 THEN 1
				WHEN @CommentPageNumber > @TotalPages AND @TotalPages > 0 THEN @TotalPages
				WHEN @TotalPages = 0 THEN 1
				ELSE @CommentPageNumber
			END;

		-- Return pagination metadata
		SELECT 
			CAST(@TotalThreadCount AS INT) AS TotalCount,
			CAST(@TotalPages AS INT) AS TotalPages,
			CAST(@ValidatedPageNumber AS INT) AS CurrentPage,
			CAST(@CommentPageSize AS INT) AS PageSize,
			CASE WHEN @ValidatedPageNumber < @TotalPages THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasNextPage,
			CASE WHEN @ValidatedPageNumber > 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasPreviousPage;
    
		-- sixth RESULT SET: Paginated Comment Threads
		;WITH RootComments AS (
			-- Find root comments for this requirement with pagination that match @Recertification
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
				CAST(c.Id AS VARCHAR(255)) AS ThreadGroup,
				ROW_NUMBER() OVER (ORDER BY c.CreatedDate DESC) AS RowNum
			FROM
				[SBSC].[CommentThread] c
			WHERE
				c.RequirementId = @RequirementId
				AND c.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
				AND c.ParentCommentId IS NULL
		),
		PaginatedRoots AS (
			-- Select only the root comments for the current page
			SELECT *
			FROM RootComments
			WHERE RowNum BETWEEN ((@ValidatedPageNumber - 1) * @CommentPageSize + 1) AND (@ValidatedPageNumber * @CommentPageSize)
		),
		CommentGroups AS (
			-- Include the paginated root comments
			SELECT
				rc.Id,
				rc.RequirementId,
				rc.CustomerId,
				rc.AuditorId,
				rc.ParentCommentId,
				rc.Comment,
				rc.CreatedDate,
				rc.CustomerCommentTurn,
				rc.ReadStatus,
				rc.ThreadGroup,
				CAST(0 AS INT) AS Level
			FROM
				PaginatedRoots rc
        

			UNION ALL
        
			-- Add all replies to the paginated root comments
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
				cg.ThreadGroup,
				cg.Level + 1 AS Level
			FROM
				[SBSC].[CommentThread] c
			INNER JOIN
				CommentGroups cg ON c.ParentCommentId = cg.Id
		)
		SELECT 
			cg.Id,
			cg.RequirementId,
			CASE WHEN cg.AuditorId IS NOT NULL THEN NULL ELSE cg.CustomerId END AS CustomerId,
			cg.AuditorId,
			cg.ParentCommentId,
			cg.Comment,
			cg.CreatedDate,
			cg.CustomerCommentTurn,
			cg.ReadStatus,
			cg.ThreadGroup,
			-- Get reply count for root comments
			(
				SELECT COUNT(*)
				FROM [SBSC].[CommentThread] replies
				WHERE replies.ParentCommentId = cg.Id
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
					cd.CommentId = cg.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			CommentGroups cg
		ORDER BY 
			--cg.ThreadGroup,
			--cg.Level,
			cg.CreatedDate DESC;

	END
	
	-- LOAD_MORE operation - returns only comments pagination
	ELSE IF @Action = 'LOAD_MORE'
	BEGIN
		-- Comment Threads Metadata for Pagination
		DECLARE @TotalThreadCountPaginated INT;
		DECLARE @TotalPagesPaginated INT;
	
		-- Get the total thread count for comments that match @Recertification
		SELECT @TotalThreadCountPaginated = COUNT(*)
		FROM (
			SELECT DISTINCT c.Id
			FROM [SBSC].[CommentThread] c
			WHERE c.RequirementId = @RequirementId
				AND c.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
				AND c.ParentCommentId IS NULL
		) AS UniqueThreads;
	
		-- Calculate total pages
		SET @TotalPagesPaginated = CEILING(@TotalThreadCountPaginated * 1.0 / @CommentPageSize);
	
		-- Ensure page number doesn't exceed total pages
		DECLARE @ValidatedPageNumberPaginated INT = 
			CASE 
				WHEN @CommentPageNumber <= 0 THEN 1
				WHEN @CommentPageNumber > @TotalPagesPaginated AND @TotalPagesPaginated > 0 THEN @TotalPagesPaginated
				WHEN @TotalPagesPaginated = 0 THEN 1
				ELSE @CommentPageNumber
			END;
	
		-- FIRST RESULT SET: Pagination metadata
		SELECT 
			CAST(@TotalThreadCountPaginated AS INT) AS TotalCount,
			CAST(@TotalPagesPaginated AS INT) AS TotalPages,
			CAST(@ValidatedPageNumberPaginated AS INT) AS CurrentPage,
			CAST(@CommentPageSize AS INT) AS PageSize,
			CASE WHEN @ValidatedPageNumberPaginated < @TotalPagesPaginated THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasNextPage,
			CASE WHEN @ValidatedPageNumberPaginated > 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS HasPreviousPage;

		-- SECOND RESULT SET: Paginated Comment Threads
		;WITH RootComments AS (
			-- Find root comments for this requirement with pagination that match @Recertification
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
				CAST(c.Id AS VARCHAR(255)) AS ThreadGroup,
				ROW_NUMBER() OVER (ORDER BY c.CreatedDate DESC) AS RowNum
			FROM
				[SBSC].[CommentThread] c
			WHERE
				c.RequirementId = @RequirementId
				AND c.CustomerCertificationDetailsId = @CustomerCertificationDetailsId
				AND c.ParentCommentId IS NULL
		),
		PaginatedRoots AS (
			-- Select only the root comments for the current page
			SELECT *
			FROM RootComments
			WHERE RowNum BETWEEN ((@ValidatedPageNumberPaginated - 1) * @CommentPageSize + 1) AND (@ValidatedPageNumberPaginated * @CommentPageSize)
		),
		CommentGroups AS (
			-- Include the paginated root comments
			SELECT
				rc.Id,
				rc.RequirementId,
				rc.CustomerId,
				rc.AuditorId,
				rc.ParentCommentId,
				rc.Comment,
				rc.CreatedDate,
				rc.CustomerCommentTurn,
				rc.ReadStatus,
				rc.ThreadGroup,
				CAST(0 AS INT) AS Level
			FROM
				PaginatedRoots rc
		
			UNION ALL
		
			-- Add all replies to the paginated root comments
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
				cg.ThreadGroup,
				cg.Level + 1 AS Level
			FROM
				[SBSC].[CommentThread] c
			INNER JOIN
				CommentGroups cg ON c.ParentCommentId = cg.Id
		)
		SELECT 
			cg.Id,
			cg.RequirementId,
			CASE WHEN cg.AuditorId IS NOT NULL THEN NULL ELSE cg.CustomerId END AS CustomerId,
			cg.AuditorId,
			cg.ParentCommentId,
			cg.Comment,
			cg.CreatedDate,
			cg.CustomerCommentTurn,
			cg.ReadStatus,
			cg.ThreadGroup,
			-- Get reply count for root comments
			(
				SELECT COUNT(*)
				FROM [SBSC].[CommentThread] replies
				WHERE replies.ParentCommentId = cg.Id
			) AS ReplyCount,
			-- Get Documents as a JSON array
			(
				SELECT 
					cd.Id AS DocumentId,
					cd.DocumentName,
					cd.DocumentType,
					cd.UploadId,
					cd.Size,
					cd.AddedDate
				FROM 
					[SBSC].[CommentDocument] cd
				WHERE 
					cd.CommentId = cg.Id
				FOR JSON PATH
			) AS DocumentsJson
		FROM 
			CommentGroups cg
		ORDER BY 
			cg.ThreadGroup,
			cg.Level,
			cg.CreatedDate DESC;
	END
END
GO