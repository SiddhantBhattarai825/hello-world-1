SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_Certification_Crud] 
	-- Add the parameters for the stored procedure here
	@Action NVARCHAR(100),
    @Id INT = NULL,
    @CertificateTypeId INT = NULL,
    @CertificateCode NVARCHAR(500) = NULL,
    @Validity INT = NULL,
    @IsActive INT = NULL,
    @IsVisible BIT = NULL,
	@AddedDate DATETIME = NULL,
	@AddedBy INT = null,
	@ModifiedBy INT = NULL,
	@ModifiedDate DATETIME = NULL,
	@AuditYears NVARCHAR(255) = NULL,
	@Published INT = NULL,
	@Version DECIMAL(5,2) = NULL,
	@IsAuditorInitiated SMALLINT = NULL,
	@UserRole INT = NULL,
	@UserId INT = NULL,
	@DefaultAuditorId INT = NULL,

	@AuditorIdList NVARCHAR(MAX) = NULL,
	@CertificationId INT = NULL,

	@Assignmentid INT = NULL,
	
	@LangId INT = NULL,
	@CertificationName NVARCHAR(255) = NULL,
	@Description NVARCHAR(MAX) = NULL,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC',

	@ColumnName NVARCHAR(500) = NULL,
	@NewValue NVARCHAR(500) = NULL,
	@CurrentUser INT = NULL
AS
BEGIN
    SET NOCOUNT ON;


    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATELANG', 'CHAPTERLIST', 'ASSIGN_CERTIFICATIONS',  'READ_PUBLICATION_STATUS', 'READ_PUBLICATION_STATUS_V2',  'PUBLISH', 'CLONE')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, ASSIGN_CERTIFICATIONS, UPDATELANG or CHAPTERLIST', 16, 1);
        RETURN;
    END

	-- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		DECLARE @NewCertificateId INT;

		-- Start the transaction
		BEGIN TRY
			
			DECLARE @DefaultLanguageCreateId INT;
			IF @LangId IS NULL
			BEGIN
				SELECT TOP 1 @DefaultLanguageCreateId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
				SET @LangId = @DefaultLanguageCreateId;
			END

			BEGIN TRANSACTION;

			-- Check if a record with the same Code already exists
			IF EXISTS (SELECT 1 FROM [SBSC].[Certification] WHERE CertificateCode = @CertificateCode)
			BEGIN
				RAISERROR('A record with the provided Certificate Code already exists.', 16, 1);
				RETURN;
			END

			IF @AuditYears IS NULL
			BEGIN
				SET @AuditYears = '0';
			END

			-- Insert into Certification table
			INSERT INTO [SBSC].[Certification] (
				[CertificateTypeId], [CertificateCode], [Validity], [AuditYears], [Published], [IsActive], [IsVisible], [AddedDate], [AddedBy], [ModifiedBy], [ModifiedDate], [Version], [IsAuditorInitiated]
			)
			VALUES (
				@CertificateTypeId, @CertificateCode, @Validity, @AuditYears, ISNULL(@Published, 0), 1, ISNULL(@IsVisible, 0), GETUTCDATE(), @AddedBy, @ModifiedBy, @ModifiedDate, @Version, ISNULL(@IsAuditorInitiated, 0)
			);

			-- Get the newly inserted Certification Id
			SET @NewCertificateId = SCOPE_IDENTITY();

			-- Loop through all languages and insert into CertificationLanguage table
			DECLARE @CurrentLangId INT;

			-- Cursor to loop through all languages
			DECLARE LanguageCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Languages];

			OPEN LanguageCursor;

			FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Check if the current LangId matches the provided @LangId
				IF @CurrentLangId = @LangId
				BEGIN
					-- Insert with the provided CertificationName for the specified LangId
					INSERT INTO [SBSC].[CertificationLanguage] (
						[CertificationId], [LangId], [CertificationName], [Description]
					)
					VALUES (
						@NewCertificateId, 
						@CurrentLangId, 
						@CertificationName,  -- Provided CertificationName
						@Description
					);
				END
				ELSE
				BEGIN
					-- Insert with NULL CertificationName for other languages
					INSERT INTO [SBSC].[CertificationLanguage] (
						[CertificationId], [LangId], [CertificationName], [Description]
					)
					VALUES (
						@NewCertificateId, 
						@CurrentLangId, 
						NULL,  -- NULL CertificationName
						NULL
					);
				END

				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			END

			-- Close and deallocate the cursor
			CLOSE LanguageCursor;
			DEALLOCATE LanguageCursor;

			-- Link the new Certification to ALL DEFAULT ReportBlocks (if any exist)
			INSERT INTO [SBSC].[ReportBlocksCertifications] (ReportBlockId, CertificationId)
			SELECT 
				rb.Id AS ReportBlockId, 
				@NewCertificateId AS CertificationId
			FROM [SBSC].[ReportBlocks] rb
			WHERE rb.IsDefault = 1;  -- Only link to DEFAULT ReportBlocks

			-- Commit the transaction
			COMMIT TRANSACTION;

			-- Return the newly inserted CertificationId and other details
			SELECT 
				@NewCertificateId AS [Id],
				@CertificateTypeId AS [CertificateTypeId],
				@CertificateCode AS [CertificateCode],
				@CertificationName AS [CertificationName],
				@Description AS [Description],
				@Validity AS [Validity],
				@AuditYears AS [AuditYears],
				@Version as [Version];

		END TRY
		BEGIN CATCH
			-- Rollback the transaction if any error occurs
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END;

			IF CURSOR_STATUS('global','LanguageCursor') >= 0
			BEGIN
				CLOSE LanguageCursor;
				DEALLOCATE LanguageCursor;
			END

			-- Return error information
			DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
			SELECT 
				@ErrorMessage = ERROR_MESSAGE(),
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE();

			-- Rethrow the error
			RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
		END CATCH;
	END

	-- READ operation
	ELSE IF @Action = 'READ' 
	BEGIN 
		-- Declare a variable to hold the first LangId 
		DECLARE @DefaultLangId INT; 
    
		-- If LangId is not provided, get the default Id from Languages table 
		IF @LangId IS NULL 
		BEGIN 
			SELECT TOP 1 @DefaultLangId = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLangId; 
		END 
    
		IF @Id IS NULL 
		BEGIN 
			SELECT 
				cd.*,
				(
					SELECT 
						ch.[Id] AS ChapterId,
						chl.[ChapterTitle] AS ChapterTitle
						-- chl.[ChapterDescription]
					FROM [SBSC].[Chapter] ch
					INNER JOIN [SBSC].[ChapterLanguage] chl ON ch.[Id] = chl.[ChapterId]
					WHERE ch.[CertificationId] = cd.CertificationId
					AND chl.[LanguageId] = @LangId
					FOR JSON PATH
				) AS Chapters,
				(
					SELECT 
						rl.RequirementId,
						rl.Headlines
					FROM [SBSC].[RequirementLanguage] rl
					INNER JOIN [SBSC].[RequirementChapters] rc ON rc.RequirementId = rl.RequirementId
					INNER JOIN [SBSC].[Chapter] ch ON ch.Id = rc.ChapterId
					WHERE ch.[CertificationId] = cd.CertificationId
					AND rl.[LangId] = @LangId
					FOR JSON PATH
				) AS Requirements
			FROM [SBSC].[vw_CertificationDetails] cd
			WHERE cd.[LangId] = @LangId; 
		END 
		ELSE 
		BEGIN 
			SELECT 
				cd.*,
				(
					SELECT 
						ch.[Id] AS ChapterId,
						chl.[ChapterTitle] AS ChapterTitle,
						chl.[ChapterDescription]
					FROM [SBSC].[Chapter] ch
					INNER JOIN [SBSC].[ChapterLanguage] chl ON ch.[Id] = chl.[ChapterId]
					WHERE ch.[CertificationId] = cd.CertificationId
					AND chl.[LanguageId] = @LangId
					FOR JSON PATH
				) AS Chapters,
				(
					SELECT 
						rl.RequirementId,
						rl.Headlines
					FROM [SBSC].[RequirementLanguage] rl
					INNER JOIN [SBSC].[RequirementChapters] rc ON rc.RequirementId = rl.RequirementId
					INNER JOIN [SBSC].[Chapter] ch ON ch.Id = rc.ChapterId
					WHERE ch.[CertificationId] = cd.CertificationId
					AND rl.[LangId] = @LangId
					FOR JSON PATH
				) AS Requirements
			FROM [SBSC].[vw_CertificationDetails] cd
			WHERE cd.[CertificationId] = @Id 
			AND cd.[LangId] = @LangId; 
		END 
	END

    -- UPDATE operation
	ELSE IF @Action = 'UPDATE'
	BEGIN
		DECLARE @OldIsAuditorInitiated SMALLINT;
		DECLARE @IsPublished INT;
    
		-- Capture the old value of IsAuditorInitiated and Published status
		SELECT @OldIsAuditorInitiated = IsAuditorInitiated,
			   @IsPublished = Published 
		FROM SBSC.Certification 
		WHERE ID = @Id;

		-- If Published = 1, don't allow IsAuditorInitiated to be updated
		IF @IsPublished > 0 AND (@IsAuditorInitiated IS NOT NULL AND @IsAuditorInitiated != @OldIsAuditorInitiated)
		BEGIN
			RAISERROR('Cannot update audit type for published certificates', 16, 1);
			RETURN;
		END

		-- Update the Certification record
		UPDATE SBSC.Certification
		SET CertificateTypeId = ISNULL(@CertificateTypeId, CertificateTypeId),
			CertificateCode = ISNULL(@CertificateCode, CertificateCode),
			Validity = ISNULL(@Validity, Validity),
			AuditYears = ISNULL(@AuditYears, AuditYears),
			Published = ISNULL(@Published, Published),
			IsActive = ISNULL(@IsActive, IsActive),
			IsVisible = ISNULL(@IsVisible, IsVisible),
			ModifiedBy = ISNULL(@ModifiedBy, ModifiedBy),
			[Version] = ISNULL(@Version, [Version]),
			IsAuditorInitiated = CASE 
									WHEN @IsPublished > 0 THEN IsAuditorInitiated -- Keep old value if published
									ELSE ISNULL(@IsAuditorInitiated, IsAuditorInitiated)
								END
		WHERE Id = @Id;

		-- Check if transitioning from 0 to 1
		IF @OldIsAuditorInitiated = 0 AND @IsAuditorInitiated = 1
		BEGIN
			-- Update all related requirements to RequirementTypeId = 5
			UPDATE R
			SET RequirementTypeId = 5
			FROM SBSC.Requirement R
			INNER JOIN SBSC.RequirementChapters RC ON R.Id = RC.RequirementId
			INNER JOIN SBSC.Chapter C ON RC.ChapterId = C.Id
			WHERE C.CertificationId = @Id;
		END
	
		UPDATE r
		SET r.AuditYears = (
			SELECT STRING_AGG(v.Value, ', ') 
			FROM 
				STRING_SPLIT(r.AuditYears, ',') AS s 
				LEFT JOIN (
					SELECT TRIM(Value) AS Value
					FROM STRING_SPLIT(@AuditYears, ',') 
				) AS v
				ON TRIM(s.Value) = v.Value 
		)
		FROM 
			SBSC.Requirement r
			JOIN SBSC.RequirementChapters rc ON r.Id = rc.RequirementId
			JOIN SBSC.Chapter c ON c.Id = rc.ChapterId
		WHERE 
			c.CertificationId = @Id; 

		SELECT Id, CertificateTypeId, CertificateCode, Validity 
		FROM SBSC.Certification
		WHERE Id = @Id;
	END

	-- DELETE operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRY
			DELETE FROM SBSC.Certification WHERE Id = @Id;

			SELECT @Id AS Id;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			-- Check if the error is a foreign key violation
			IF ERROR_NUMBER() = 547
			BEGIN
				-- Custom error message for foreign key violation
				RAISERROR('This certification is related to another object, deleting it will remove other data.', 16, 1);
			END
			ELSE
			BEGIN
				-- Other errors
				DECLARE @DeleteErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
				DECLARE @DeleteErrorSeverity INT = ERROR_SEVERITY();
				DECLARE @DeleteErrorState INT = ERROR_STATE();

				RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState);
			END
		END CATCH
	END

    ELSE IF @Action = 'LIST'
	BEGIN
		DECLARE @DefaultLanguageId INT;
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLanguageId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageId;
		END

		-- Previous validation code remains the same
		IF @SortColumn NOT IN ('CertificateTypeId', 'CertificateCode', 'Validity', 'CertificationName', 'CertificationType', 'AddedDate')
			SET @SortColumn = 'CertificateCode';
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- Updated WHERE clause to include @CertificateTypeId and check if IsActive = 1
		SET @WhereClause = N'
			WHERE LangId = @LangId
			AND (@IsActive IS NULL OR IsACtive = @IsActive)
			AND (@CertificateTypeId IS NULL OR CertificateTypeId = @CertificateTypeId)
			AND (@SearchValue IS NULL
				OR CertificateCode LIKE ''%'' + @SearchValue + ''%''
				OR Validity LIKE ''%'' + @SearchValue + ''%''
				OR CertificationType LIKE ''%'' + @SearchValue + ''%''
				OR CertificationName LIKE ''%'' + @SearchValue + ''%'')';


		IF (@UserRole = 2 AND EXISTS (SELECT 1 FROM SBSC.Auditor WHERE IsSBSCAuditor = 0 AND Id = @UserId))
		BEGIN
		SET @WhereClause += N'
			AND CertificationId IN (SELECT CertificationId FROM SBSC.Auditor_Certifications WHERE AuditorId = @UserId )';
		END

		-- Count total records (unchanged)
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(CertificationId)
			FROM [SBSC].[vw_CertificationDetails]
		' + @WhereClause;

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @LangId INT, @CertificateTypeId INT, @UserId INT, @IsActive INT, @TotalRecords INT OUTPUT';

		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @CertificateTypeId, @UserId, @IsActive, @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Modified SELECT statement to include certification details, chapters, and check if Published = 1
		SET @SQL = N'
			WITH PaginatedCertifications AS (
				SELECT *
				FROM [SBSC].[vw_CertificationDetails]
				' + @WhereClause + '
				ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
				OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
				FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY
			)
			SELECT 
				c.*,
				(
					SELECT 
						ch.[Id] AS ChapterId,
						chl.[ChapterTitle] AS ChapterTitle
					FROM [SBSC].[Chapter] ch
					INNER JOIN [SBSC].[ChapterLanguage] chl ON ch.[Id] = chl.[ChapterId]
					WHERE ch.[CertificationId] = c.CertificationId
					AND chl.[LanguageId] = @LangId
					FOR JSON PATH
				) AS Chapters,
				(
					SELECT 
						rl.RequirementId,
						rl.Headlines
					FROM [SBSC].[RequirementLanguage] rl
					INNER JOIN [SBSC].[RequirementChapters] rc ON rc.RequirementId = rl.RequirementId
					INNER JOIN [SBSC].[Chapter] ch ON ch.Id = rc.ChapterId
					WHERE ch.[CertificationId] = c.CertificationId
					AND rl.[LangId] = @LangId
					FOR JSON PATH
				) AS Requirements
			FROM PaginatedCertifications c';

		-- Execute the paginated query with chapters
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @CertificateTypeId, @UserId, @IsActive, @TotalRecords OUTPUT;

		-- Return pagination details (unchanged)
		SELECT @TotalRecords AS TotalRecords, 
			   @TotalPages AS TotalPages, 
			   @PageNumber AS CurrentPage, 
			   @PageSize AS PageSize,
			   CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			   CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END

	
    
	ELSE IF @Action = 'UPDATELANG'
    BEGIN
	    DECLARE @DefaultUpdateLangId INT;
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultUpdateLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
            SET @LangId = @DefaultUpdateLangId;
        END

        IF @Id IS NULL
            BEGIN
                RAISERROR('Certification Id must be provided for updating language.', 16, 1);
            END
        ELSE
            BEGIN TRY
                UPDATE [SBSC].[CertificationLanguage]
                SET CertificationName = ISNULL(@CertificationName, CertificationName),
					[Description] = ISNULL(@Description, [Description])
                WHERE CertificationId = @Id and [LangId] = @LangId
                SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
            END TRY
        BEGIN CATCH
            THROW; -- Re-throw the error
        END CATCH
    END

	ELSE IF @Action = 'CHAPTERLIST'
	BEGIN
		-- Declare a variable to hold the default language Id
		DECLARE @DefaultChapterLangId INT;

		-- If LangId is not provided, get the first default language Id from the Languages table
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultChapterLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultChapterLangId; -- Set LangId to the default language Id
		END

		-- Check if Certification Id (@Id) is provided
		IF @Id IS NOT NULL
		BEGIN
			-- Select chapters and their language details based on CertificationId and LangId
			SELECT 
				c.[Id] AS ChapterId,
				c.[Title] AS ChapterTitle,
				cl.[ChapterDescription],
				cl.[LanguageId],
				c.[IsVisible],
				c.[IsWarning],
				c.[AddedDate],
				c.[AddedBy],
				c.[ModifiedDate],
				c.[ModifiedBy]
			FROM 
				[SBSC].[Chapter] c
			INNER JOIN 
				[SBSC].[ChapterLanguage] cl
				ON c.[Id] = cl.[ChapterId]
			WHERE 
				c.[CertificationId] = @Id  -- Filter by CertificationId
				AND cl.[LanguageId] = @LangId  -- Filter by LangId
		END
	END

	ELSE IF @Action = 'ASSIGN_CERTIFICATIONS'
	BEGIN
		DECLARE @AuditorIds NVARCHAR(MAX);
    
		-- Map input parameters
		SET @CertificationId = @Id;
		SET @AuditorIds = NULLIF(LTRIM(RTRIM(@AuditorIdList)), '');
    
		-- Enhanced validation
		IF @CertificationId IS NULL OR @CertificationId <= 0
		BEGIN
			THROW 50001, 'CertificationId must be a valid positive number.', 1;
			RETURN;
		END
    
		BEGIN TRY
			-- Parse Auditor IDs into a table with enhanced validation
			DECLARE @AuditorIdTable TABLE (AuditorId INT);
        
			INSERT INTO @AuditorIdTable (AuditorId)
			SELECT CAST(LTRIM(RTRIM(value)) AS INT) AS AuditorId
			FROM STRING_SPLIT(@AuditorIds, ',')
			WHERE LTRIM(RTRIM(value)) <> ''
			AND ISNUMERIC(LTRIM(RTRIM(value))) = 1
			AND CAST(LTRIM(RTRIM(value)) AS INT) > 0;
        
			-- Check if certification exists
			IF NOT EXISTS (SELECT 1 FROM [SBSC].[Certification] WHERE Id = @CertificationId)
			BEGIN
				THROW 50004, 'Specified certification does not exist.', 1;
				RETURN;
			END
        
			-- Remove any existing assignments for this certification to avoid duplicates
			DELETE FROM [SBSC].[Auditor_Certifications]
			WHERE CertificationId = @CertificationId;
        
			-- Insert new assignments
			INSERT INTO [SBSC].[Auditor_Certifications] (AuditorId, CertificationId, IsDefault)
			SELECT AuditorId, @CertificationId, 0
			FROM @AuditorIdTable;
        
			-- Set default auditor
			UPDATE [SBSC].[Auditor_Certifications] 
			SET IsDefault = 1 
			WHERE AuditorId = @DefaultAuditorId AND CertificationId = @CertificationId;
        
			-- Check if certification is not auditor-initiated
			DECLARE @IsAuditorInitiatedUpdate BIT;
			SELECT @IsAuditorInitiatedUpdate = IsAuditorInitiated 
			FROM SBSC.Certification 
			WHERE Id = @CertificationId;
        
			-- If not auditor-initiated, assign default auditor to customer certifications
			IF @IsAuditorInitiatedUpdate = 0
			BEGIN
				-- Temporary table to store CustomerCertificationIds
				DECLARE @CustomerCertificationIds TABLE (
					CustomerCertificationId INT
				);
            
				-- Insert CustomerCertificationIds into temp table
				INSERT INTO @CustomerCertificationIds (CustomerCertificationId)
				SELECT CustomerCertificationId 
				FROM SBSC.Customer_Certifications 
				WHERE CertificateId = @CertificationId;
            
				-- Local variables for loop
				DECLARE @CurrentCustomerCertificationId INT;
            
				-- Cursor to loop through CustomerCertificationIds
				DECLARE CustomerCert_Cursor CURSOR FOR 
				SELECT CustomerCertificationId 
				FROM @CustomerCertificationIds;
            
				OPEN CustomerCert_Cursor;
            
				FETCH NEXT FROM CustomerCert_Cursor INTO @CurrentCustomerCertificationId;
            
				WHILE @@FETCH_STATUS = 0
				BEGIN
					BEGIN TRY
						-- Execute remote stored procedure to assign default auditor
						EXEC sp_execute_remote 
							@data_source_name = N'SbscCustomerDataSource',
							@stmt = N'EXEC [SBSC].[sp_Customers_CRUD] 
									@Action = @Action,
									@CustomerCertificationId = @CustomerCertificationId,
									@AuditorId = @AuditorId',
							@params = N'@Action NVARCHAR(100), @CustomerCertificationId INT, @AuditorId INT',
							@Action = 'ASSIGN_DEFAULT_AUDITOR',
							@CustomerCertificationId = @CurrentCustomerCertificationId,
							@AuditorId = @DefaultAuditorId;
					END TRY
					BEGIN CATCH
						-- Log the error or handle it as needed
						-- You might want to add error logging logic here
						PRINT 'Error assigning default auditor for CustomerCertificationId: ' + 
							  CAST(@CurrentCustomerCertificationId AS NVARCHAR(10)) + 
							  '. Error: ' + ERROR_MESSAGE();
					END CATCH
                
					-- Get next CustomerCertificationId
					FETCH NEXT FROM CustomerCert_Cursor INTO @CurrentCustomerCertificationId;
				END
            
				-- Close and deallocate the cursor
				CLOSE CustomerCert_Cursor;
				DEALLOCATE CustomerCert_Cursor;
			END
        
			-- Return the number of rows inserted in Auditor_Certifications
			SELECT @@ROWCOUNT AS RowsAffected;
		END TRY
		BEGIN CATCH
			-- Centralized error handling
			DECLARE @ErrorMessageAssignAuditor NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @ErrorSeverityAssignAuditor INT = ERROR_SEVERITY();
			DECLARE @ErrorStateAssignAuditor INT = ERROR_STATE();
        
			-- Log the error or perform additional error handling as needed
			RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
		END CATCH
	END


	-- READ operation
	ELSE IF @Action = 'READ_PUBLICATION_STATUS' 
	BEGIN 
		DECLARE @CertificationCode NVARCHAR(100);
		DECLARE @Result NVARCHAR(MAX); -- Variable to hold the JSON result

		-- Retrieve the CertificationCode for the specified CertificationId
		SELECT @CertificationCode = CertificateCode
		FROM [SBSC].[Certification]
		WHERE Id = @Id;

		IF @CertificationCode IS NULL
		BEGIN
			RAISERROR('Certification not found.', 16, 1);
			RETURN;
		END

		-- Get certification metaData and version publish status as JSON
		SELECT @Result = (
			SELECT 
				c.Id,
				c.CertificateTypeId,
				c.CertificateCode,
				c.Version,
				(
					SELECT 
						l.Id AS LangId,
						l.LanguageCode AS LangCode,
						l.LanguageName AS Language,
						ISNULL(cl.Published, 0) AS Published,
						cl.PublishedDate,
						cl.UpdatedAt
					FROM 
						[SBSC].[Languages] l
					LEFT JOIN 
						[SBSC].[CertificationLanguage] cl ON l.Id = cl.LangId AND cl.CertificationId = c.Id
					WHERE 
						l.IsActive = 1
					FOR JSON PATH
				) AS PublishStatus
			FROM 
				[SBSC].[Certification] c
			WHERE 
				c.CertificateCode = @CertificationCode
			ORDER BY 
				c.Version DESC
			FOR JSON PATH
		);

		-- Return the JSON result
		SELECT @Result AS CertificationPublicationStatus;
	END

	-- READ operation
	ELSE IF @Action = 'READ_PUBLICATION_STATUS_V2' 
	BEGIN 
		DECLARE @Result_V2 NVARCHAR(MAX); -- Variable to hold the JSON result
		DECLARE @CertificationCodes TABLE (CertificateCode NVARCHAR(100));
    
		IF @AssignmentId IS NOT NULL
		BEGIN
			-- Get all distinct certification codes for the specified assignmentId
			INSERT INTO @CertificationCodes (CertificateCode)
			SELECT DISTINCT c.CertificateCode 
			FROM sbsc.AssignmentOccasions ao 
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON ao.Id = acc.AssignmentId
			INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
			INNER JOIN SBSC.Customer_Certifications cc ON cc.CustomerCertificationId = ccd.CustomerCertificationId
			INNER JOIN SBSC.Certification c ON cc.CertificateId = c.Id
			WHERE ao.Id = @AssignmentId;
		END
		ELSE IF @ID IS NOT NULL
		BEGIN
			-- Get the certification code for the specified CertificationId
			INSERT INTO @CertificationCodes (CertificateCode)
			SELECT CertificateCode
			FROM [SBSC].[Certification]
			WHERE Id = @Id;
		END
		ELSE
		BEGIN
			RAISERROR('CertificateId or AssignmentId is required.', 16, 1);
			RETURN;
		END
    
		-- Check if any certification codes were found
		IF NOT EXISTS (SELECT 1 FROM @CertificationCodes)
		BEGIN
			RAISERROR('No certifications found.', 16, 1);
			RETURN;
		END
    
		-- Validate that all certification codes exist
		IF EXISTS (
			SELECT 1 
			FROM @CertificationCodes cc 
			WHERE NOT EXISTS (
				SELECT 1 
				FROM SBSC.Certification c 
				WHERE c.CertificateCode = cc.CertificateCode 
			)
		)
		BEGIN
			RAISERROR('One or more certifications do not exist.', 16, 1);
			RETURN;
		END
    
		-- Get certification metadata and version publish status as JSON with new hierarchy
		SELECT @Result_V2 = (
			SELECT 
				cc.CertificateCode,
				(
					SELECT 
						c.Id,
						c.CertificateTypeId,
						c.CertificateCode,
						c.Published AS GlobalPublishStatus,
						c.Version,
						(
							SELECT 
								l.Id AS LangId,
								l.LanguageCode AS LangCode,
								l.LanguageName AS Language,
								ISNULL(cl.Published, 0) AS Published,
								cl.PublishedDate,
								cl.UpdatedAt
							FROM 
								[SBSC].[Languages] l
							LEFT JOIN 
								[SBSC].[CertificationLanguage] cl ON l.Id = cl.LangId AND cl.CertificationId = c.Id
							WHERE 
								l.IsActive = 1
							FOR JSON PATH
						) AS PublishStatus
					FROM 
						[SBSC].[Certification] c
					WHERE 
						c.CertificateCode = cc.CertificateCode
					ORDER BY 
						c.Version DESC
					FOR JSON PATH
				) AS Versions
			FROM 
				@CertificationCodes cc
			FOR JSON PATH
		);
    
		-- Return the JSON result
		SELECT @Result_V2 AS CertificationPublicationStatus;
	END


	ELSE IF @Action = 'PUBLISH'  
	BEGIN 
		-- Declare a variable to hold the first LangId 
		DECLARE @DefaultLangIdPublish INT; 

		-- If LangId is not provided, get the default Id from Languages table 
		IF @LangId IS NULL 
		BEGIN 
			SELECT TOP 1 @DefaultLangIdPublish = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLangIdPublish; 
		END 

		IF @Id IS NULL 
		BEGIN 
			RAISERROR('CertificationId must be provided.', 16, 1);
			RETURN;
		END 


		IF @Published != 1
		BEGIN 
			IF @Published = 0
			BEGIN
				IF EXISTS (SELECT 1 FROM SBSC.Customer_Certifications WHERE CertificateId = @Id)
				BEGIN
					RAISERROR('Customers are using this certification.', 16, 1);
					RETURN;
				END
			END

			-- Simply update the published status of certification for the provided certificationId
			BEGIN TRANSACTION

				UPDATE [SBSC].[Certification]
				SET IsActive = 0,
					Published = @Published
				WHERE Id = @Id;

				UPDATE [SBSC].[CertificationLanguage]
				SET Published = @Published
				WHERE CertificationId = @Id
				AND LangId = @LangId;			

			COMMIT TRANSACTION

		END
		ELSE
		BEGIN 
			-- Validate if all the certification language data have been fulfilled for that certificationId and langId
			IF NOT EXISTS (
				SELECT 1 
				FROM [SBSC].[CertificationLanguage] 
				WHERE CertificationId = @Id 
				AND LangId = @LangId 
				AND (CertificationName IS NOT NULL AND CertificationName != '')
				AND (Description IS NOT NULL AND Description != '')
			)
			BEGIN
				RAISERROR('Certification language data is incomplete. Please provide both CertificationName and Description.', 16, 1);
				RETURN;
			END

			IF NOT EXISTS (
				SELECT 1
				FROM SBSC.Chapter
				WHERE CertificationId = @Id
			)
			BEGIN
				RAISERROR('Atleast one chapter is required to publish.', 16, 1);
				RETURN;
			END

			-- Validate if all the chapters (or chapter sections) within that certification language data have been fulfilled for that langId
			DECLARE @ChaptersWithoutRequirements INT;

			WITH ChapterDescendants AS (
				-- Base case: Start with each chapter
				SELECT 
					Id as RootChapterId,
					Id as ChapterId,
					0 as Level
				FROM SBSC.Chapter 
				WHERE CertificationId = @Id AND IsDeleted = 0
    
				UNION ALL
    
				-- Recursive case: Get all descendants for each root chapter
				SELECT 
					cd.RootChapterId,
					c.Id as ChapterId,
					cd.Level + 1
				FROM SBSC.Chapter c
				INNER JOIN ChapterDescendants cd ON c.ParentChapterId = cd.ChapterId
				WHERE c.CertificationId = @Id AND c.IsDeleted = 0
			)
			SELECT @ChaptersWithoutRequirements = COUNT(*)
			FROM SBSC.Chapter rootChapter
			WHERE rootChapter.CertificationId = @Id 
			AND rootChapter.IsDeleted = 0
			AND NOT EXISTS (
				-- Check if this chapter or any of its descendants has requirements
				SELECT 1
				FROM ChapterDescendants cd
				INNER JOIN SBSC.RequirementChapters rc ON cd.ChapterId = rc.ChapterId
				INNER JOIN SBSC.Requirement r ON r.Id = rc.RequirementId
				WHERE cd.RootChapterId = rootChapter.Id
			);

			IF @ChaptersWithoutRequirements > 0
			BEGIN
				RAISERROR('Each chapter must have a requirement associated with it or any of its child chapters.', 16, 1);
				RETURN;
			END

			-- Validate if all the requirements within the chapters within the certifications have their language data fulfilled
			IF EXISTS (
				SELECT 1
				FROM [SBSC].[RequirementChapters] rc
				INNER JOIN [SBSC].[Chapter] c ON rc.ChapterId = c.Id
				INNER JOIN [SBSC].[Requirement] r ON rc.RequirementId = r.Id
				LEFT JOIN [SBSC].[RequirementLanguage] rl 
					ON r.Id = rl.RequirementId AND rl.LangId = @LangId
				WHERE c.CertificationId = @Id 
				AND (rl.Id IS NULL OR (rl.Headlines IS NULL OR rl.Headlines = ''))
			)
			BEGIN
				RAISERROR('One or more requirements are missing language data for the selected language.', 16, 1);
				RETURN;
			END


			-- if the certification is going to be published, only set that specific certification as published and set all the previous versions as uneditable 	
			
			DECLARE @CertificationCodeFromId NVARCHAR(100);
			DECLARE @PublishingVersion DECIMAL(5,2);

			-- Retrieve the CertificationCode for the specified CertificationId
			SELECT @CertificationCodeFromId = CertificateCode,
					@PublishingVersion = [Version]
			FROM [SBSC].[Certification]
			WHERE Id = @Id;

			IF EXISTS (
				SELECT 1 
				FROM SBSC.Customer_Certifications 
				WHERE CertificateId IN (
					SELECT Id 
					FROM SBSC.Certification 
					WHERE CertificateCode = @CertificationCodeFromId
					AND [Version] > @PublishingVersion
				)
			)
			BEGIN
				RAISERROR('Newer versions have customer assignments', 16, 1);
				ROLLBACK;
				RETURN;
			END


			BEGIN TRANSACTION;
			BEGIN TRY
				-- Check if CertificationCode was found
				IF @CertificationCodeFromId IS NULL
				BEGIN
					RAISERROR('No Certification found with the specified CertificationId', 16, 1);
					ROLLBACK TRANSACTION;
					RETURN;
				END

				-- Set IsActive to 0 for all rows with the retrieved CertificationCode
				UPDATE c
				SET 
					IsActive = CASE WHEN c.Id = @Id THEN 1 ELSE 0 END,
					Published = CASE 
						WHEN c.[Version] < @PublishingVersion THEN 2 
						WHEN c.[Version] > @PublishingVersion THEN 0 
						ELSE 1 
					END
				FROM [SBSC].[Certification] c
				WHERE c.CertificateCode = @CertificationCodeFromId;


				UPDATE cl
				SET 
					Published = c.Published,
					PublishedDate = CASE 
						WHEN c.Id = @Id AND cl.LangId = @LangId 
						THEN GETUTCDATE() 
						ELSE cl.PublishedDate 
					END
				FROM [SBSC].[CertificationLanguage] cl
				JOIN [SBSC].[Certification] c ON cl.CertificationId = c.Id
				WHERE c.CertificateCode = @CertificationCodeFromId
				AND LangId = @LangId;

				-- assigns new version certification to auditor
				UPDATE SBSC.Auditor_Certifications 
				SET CertificationId = @Id
				WHERE CertificationId IN (
					SELECT c.Id 
					FROM SBSC.Certification c 
					WHERE c.CertificateCode = @CertificationCodeFromId
					AND c.Published IN (0, 2)
				)

			COMMIT TRANSACTION;
			END TRY
			BEGIN CATCH
				ROLLBACK TRANSACTION;
				DECLARE @PublishErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
				RAISERROR('Publish failed: %s', 16, 1, @PublishErrorMessage);
				RETURN;
			END CATCH
		END

		-- Return success message or updated record
		SELECT cl.*
		FROM [SBSC].[CertificationLanguage] cl
		WHERE cl.CertificationId = @Id
		AND cl.LangId = @LangId;
	END


	ELSE IF @Action = 'CLONE'
	BEGIN
	
		DECLARE @ClonedCertificateId INT = NULL;
		DECLARE @ClonedChapterId INT = NULL;
		DECLARE @ClonedRequirementId INT = NULL;
		DECLARE @ClonedRequirementAnswerId INT = NULL;


		IF EXISTS (SELECT 1 FROM SBSC.Certification WHERE LOWER(CertificateCode) = LOWER(@CertificateCode))
		BEGIN
			THROW 50005, 'Already exists certification code.', 1;
			RETURN;
		END

		IF NOT EXISTS (SELECT 1 FROM SBSC.Certification WHERE Id = @CertificationId)
		BEGIN
			THROW 50005, 'Dosenot exists certification id.', 1;
			RETURN;
		END

		BEGIN TRY
		BEGIN TRANSACTION;
		-- CERTIFICATION CLONE



		INSERT INTO [SBSC].[Certification] (
				[CertificateTypeId],
				[CertificateCode],
				[Validity],
				[AuditYears],
				[Published],
				[IsActive],
				[IsVisible],
				[AddedDate],
				[AddedBy],
				[ModifiedBy],
				[ModifiedDate],
				[Version],
				IsAuditorInitiated
			)
			SELECT
				CertificateTypeId,
				@CertificateCode,
				Validity,
				AuditYears,
				0,
				IsActive,
				IsVisible,
				GETUTCDATE(),
				@AddedBy,
				Null,
				NULL,
				[Version],
				IsAuditorInitiated
			FROM SBSC.Certification
			WHERE Id = @CertificationId

			-- Get the newly inserted Certification Id
			SET @ClonedCertificateId = SCOPE_IDENTITY();



			-- Clone CERTIFICATIONLANGUAGE entries
			
			INSERT INTO [SBSC].[CertificationLanguage] (
				[CertificationId],
				[LangId],
				[CertificationName],
				[Description],
				Published,
				PublishedDate
			)
			SELECT 
				@ClonedCertificateId,
				[LangId],
				[CertificationName],
				[Description],
				0,
				NULL
			FROM [SBSC].[CertificationLanguage]
			WHERE CertificationId = @CertificationId;

			-- Clone DocumentsCertifications entries
			INSERT INTO [SBSC].[DocumentsCertifications] (
				[DocId],
				[CertificationId]
			)
			SELECT 
				[DocId],
				@ClonedCertificateId
			FROM [SBSC].[DocumentsCertifications]
			WHERE CertificationId = @CertificationId;


			--AUDITOR_CERTIFICATION CLONE	

			INSERT INTO [SBSC].[Auditor_Certifications] (
				[AuditorId]
				,[CertificationId]
				,[IsDefault]
			)
			SELECT 
				[AuditorId]
				,@ClonedCertificateId
				,[IsDefault]
			FROM [SBSC].[Auditor_Certifications]
			WHERE CertificationId = @CertificationId;


			--REPORTBLOCKSCERTIFICATION CLONE

			INSERT INTO [SBSC].[ReportBlocksCertifications] (
				[ReportBlockId]
				,[CertificationId]
			)
			SELECT 
				[ReportBlockId]
				,@ClonedCertificateId
			FROM [SBSC].[ReportBlocksCertifications]
			WHERE CertificationId = @CertificationId;



			DECLARE @Chapter TABLE (Id INT);
			DELETE FROM @Chapter;


			INSERT INTO @Chapter (Id)
			SELECT Id FROM [SBSC].[Chapter]
			WHERE CertificationId = @CertificationId;

			DECLARE @CurrentChapId INT;

			SET @CurrentChapId = (SELECT MIN(Id) FROM @Chapter);

			-- While loop to iterate over the table
			WHILE @CurrentChapId IS NOT NULL
			BEGIN
				--CHAPTER CLONE

				INSERT INTO [SBSC].[Chapter] (
					[Title],
					[IsVisible],
					IsWarning,
					[AddedDate],
					[AddedBy],
					[ModifiedDate],
					[ModifiedBy],
					[CertificationId],
					DisplayOrder,
					ParentChapterId,
					HasChildSections,
					[Level]
				)
				SELECT 
					[Title],
					[IsVisible],
					[IsWarning],
					GETUTCDATE(),    -- New AddedDate
					@AddedBy,        -- New AddedBy
					NULL,    -- New ModifiedDate
					NULL,        -- New ModifiedBy
					@ClonedCertificateId,
					DisplayOrder,
					ParentChapterId,
					HasChildSections,
					[Level]
				FROM [SBSC].[Chapter]
				WHERE Id = @CurrentChapId

				SET @ClonedChapterId = SCOPE_IDENTITY();

				-- CHAPTERLANGUAGE CLONE

				INSERT INTO SBSC.ChapterLanguage (
					[ChapterId]
					,[ChapterTitle]
					,[ChapterDescription]
					,[LanguageId]
					,[ModifiedBy]
					,[ModifiedDate]
				)
				SELECT
					@ClonedChapterId
				  ,[ChapterTitle]
				  ,[ChapterDescription]
				  ,[LanguageId]
				  ,@AddedBy
				  ,GETUTCDATE()
				FROM SBSC.ChapterLanguage
				WHERE ChapterId = @CurrentChapId


				DECLARE @Requirement TABLE (Id INT);
				DELETE FROM @Requirement;


				INSERT INTO @Requirement (Id)
				SELECT RequirementId FROM [SBSC].RequirementChapters
				WHERE ChapterId = @CurrentChapId

				DECLARE @CurrentReqId INT;

				SET @CurrentReqId = (SELECT MIN(Id) FROM @Requirement);

				-- While loop to iterate over the table
				WHILE @CurrentReqId IS NOT NULL
				BEGIN
					-- REQUIREMENT CLONE

					INSERT INTO SBSC.Requirement (
						[RequirementTypeId]
						,[IsCommentable]
						,[IsFileUploadRequired]
						,[DisplayOrder]
						,[IsVisible]
						,[IsActive]
						,[AddedDate]
						,[AddedBy]
						,[ModifiedDate]
						,[ModifiedBy]
						,[AuditYears]
						,[IsFileUploadAble]
					)
					SELECT 
						[RequirementTypeId]
						,[IsCommentable]
						,[IsFileUploadRequired]
						,[DisplayOrder]
						,[IsVisible]
						,[IsActive]
						,GETUTCDATE()
						,@AddedBy
						,NULL
						,NULL
						,[AuditYears]
						,[IsFileUploadAble]
					FROM [SBSC].Requirement
					WHERE Id = @CurrentReqId

					SET @ClonedRequirementId = SCOPE_IDENTITY();


					-- REQUIREMENTLANGUAGE CLONE

					INSERT INTO SBSC.RequirementLanguage(
						[RequirementId]
						,[LangId]
						,[Headlines]
						,[Description]
						,[Notes]
					)
					SELECT
						@ClonedRequirementId
						,[LangId]
						,[Headlines]
						,[Description]
						,[Notes]
					FROM SBSC.RequirementLanguage
					WHERE RequirementId = @CurrentReqId


					-- REQUIREMENTCHAPTERS CLONE

					INSERT INTO SBSC.RequirementChapters(
						[RequirementId]
						,[ChapterId]
						,[ReferenceNo]
						,[IsWarning]
						,[DispalyOrder]
					)
					SELECT
						@ClonedRequirementId
						,@ClonedChapterId
						,[ReferenceNo]
						,[IsWarning]
						,[DispalyOrder]
					FROM SBSC.RequirementChapters
					WHERE RequirementId = @CurrentReqId
					AND ChapterId = @CurrentChapId


					-- REQUIREMENTDOCUMENTS CLONE

					--INSERT INTO SBSC.RequirementDocuments (
					--	[RequirementId]
					--	,[DocumentName]
					--	,[DocumentType]
					--	,[AddedDate]
					--	,[UserType]
					--	,[AdminId]
					--	,[CustomerId]
					--	,[AuditorId]
					--)
					--SELECT
					--	@ClonedRequirementId
					--	,[DocumentName]
					--	,[DocumentType]
					--	,[AddedDate]
					--	,[UserType]
					--	,[AdminId]
					--	,[CustomerId]
					--	,[AuditorId]
					--FROM [SBSC].[RequirementDocuments]
					--WHERE RequirementId = @CurrentReqId

					DECLARE @RequirementAnswer TABLE (Id INT);
					DELETE FROM @RequirementAnswer;

					INSERT INTO @RequirementAnswer (Id)
					SELECT Id FROM [SBSC].[RequirementAnswerOptions]
					WHERE RequirementId = @CurrentReqId

					DECLARE @CurrentReqAnsId INT;

					SET @CurrentReqAnsId = (SELECT MIN(Id) FROM @RequirementAnswer);

					-- While loop to iterate over the table
					WHILE @CurrentReqAnsId IS NOT NULL
					BEGIN
						-- REQUIREMENTANSWEROPTIONS CLONE

						INSERT INTO SBSC.RequirementAnswerOptions(
							[RequirementId]
							,[DisplayOrder]
							,[Value]
							,[RequirementTypeOptionId]
							,[IsCritical]
						)
						SELECT
							@ClonedRequirementId
							,[DisplayOrder]
							,[Value]
							,[RequirementTypeOptionId]
							,[IsCritical]
						FROM [SBSC].[RequirementAnswerOptions]
						WHERE Id = @CurrentReqAnsId

						SET @ClonedRequirementAnswerId = SCOPE_IDENTITY();


						-- REQUIREMENTANSWEROPTIONSLANGUAGE CLONE

						INSERT INTO SBSC.RequirementAnswerOptionsLanguage (
							[AnswerOptionId]
							,[LangId]
							,[Answer]
							,[HelpText]
						)
						SELECT 
							@ClonedRequirementAnswerId
							,[LangId]
							,[Answer]
							,[HelpText]
						FROM [SBSC].[RequirementAnswerOptionsLanguage]
						WHERE AnswerOptionId = @CurrentReqAnsId


						SET @CurrentReqAnsId = (SELECT MIN(Id) FROM @RequirementAnswer WHERE Id > @CurrentReqAnsId);
					END

					SET @CurrentReqId = (SELECT MIN(Id) FROM @Requirement WHERE Id > @CurrentReqId);
				END

				SET @CurrentChapId = (SELECT MIN(Id) FROM @Chapter WHERE Id > @CurrentChapId);
			END
			-- Clone Chapter entries	

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			THROW 50007, 'Failed cloning.', 1;
			ROLLBACK TRANSACTION;
		END CATCH
	END
END
GO