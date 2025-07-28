SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_Language_CRUD]
    @Action VARCHAR(10),
    @Id INT = NULL,
    @LanguageName NVARCHAR(100) = NULL,
    @LanguageCode NVARCHAR(100) = NULL,
    @IsActive BIT = 1,
    @IsDefault BIT = 1,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC' 
AS
BEGIN
    SET NOCOUNT ON;
	-- Check if @Action is valid
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, or LIST', 16, 1);
        RETURN;
    END


	IF @Action = 'CREATE'
BEGIN
    -- Check if a record with the same Code already exists
    IF EXISTS (SELECT 1 FROM [SBSC].[Languages] WHERE LanguageCode = @LanguageCode)
    BEGIN
        RAISERROR('A record with the provided language code already exists.', 16, 1);
        RETURN;
    END
    
    -- If creating a default language, set other languages' IsDefault to false
    IF @IsDefault = 1
    BEGIN
        UPDATE [SBSC].[Languages]
        SET IsDefault = 0
        WHERE IsDefault = 1;
    END

    BEGIN TRY
        BEGIN TRANSACTION;
			-- Insert the new language
			INSERT INTO [SBSC].[Languages] (LanguageCode, LanguageName, IsActive, IsDefault)
			VALUES (@LanguageCode, @LanguageName, @IsActive, @IsDefault);

			-- Get the newly created LangId
			DECLARE @LangId INT;
			SELECT @LangId = SCOPE_IDENTITY();

			-- Declare variables for IDs
			DECLARE @EmailTemplateId INT, @CertificationId INT, @CertificationCategoryId INT, @ChapterId INT, @DocId INT, @ReportBlockId INT, @RequirementAnswerOptionId INT, @RequirementId INT, @RequirementTypeOptionId INT;

			-- Cursor for EmailTemplate table
			DECLARE EmailTemplateCursor CURSOR FOR
			SELECT Id FROM [SBSC].[EmailTemplate];

			OPEN EmailTemplateCursor;
			FETCH NEXT FROM EmailTemplateCursor INTO @EmailTemplateId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into EmailTemplateLanguage
				INSERT INTO [SBSC].[EmailTemplateLanguage] (LangId, EmailTemplateId, EmailBody, EmailSubject)
				VALUES (@LangId, @EmailTemplateId, NULL, NULL);

				FETCH NEXT FROM EmailTemplateCursor INTO @EmailTemplateId;
			END

			CLOSE EmailTemplateCursor;
			DEALLOCATE EmailTemplateCursor;

			-- Cursor for Certification table
			DECLARE CertificationCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Certification];

			OPEN CertificationCursor;
			FETCH NEXT FROM CertificationCursor INTO @CertificationId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into CertificationLanguage
				INSERT INTO [SBSC].[CertificationLanguage] (LangId, CertificationId, CertificationName, [Description])
				VALUES (@LangId, @CertificationId, NULL, NULL);

				FETCH NEXT FROM CertificationCursor INTO @CertificationId;
			END

			CLOSE CertificationCursor;
			DEALLOCATE CertificationCursor;

			-- Cursor for CertificationCategory table
			DECLARE CertificationCategoryCursor CURSOR FOR
			SELECT Id FROM [SBSC].[CertificationCategory];

			OPEN CertificationCategoryCursor;
			FETCH NEXT FROM CertificationCategoryCursor INTO @CertificationCategoryId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into CertificationCategoryLanguage
				INSERT INTO [SBSC].[CertificationCategoryLanguage] (LanguageId, CertificationCategoryId, CertificationCategoryTitle)
				VALUES (@LangId, @CertificationCategoryId, NULL);

				FETCH NEXT FROM CertificationCategoryCursor INTO @CertificationCategoryId;
			END

			CLOSE CertificationCategoryCursor;
			DEALLOCATE CertificationCategoryCursor;

			-- Cursor for Chapter table
			DECLARE ChapterCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Chapter];

			OPEN ChapterCursor;
			FETCH NEXT FROM ChapterCursor INTO @ChapterId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into ChapterLanguage
				INSERT INTO [SBSC].[ChapterLanguage] (LanguageId, ChapterId, ChapterTitle, ChapterDescription, ModifiedBy, ModifiedDate)
				VALUES (@LangId, @ChapterId, NULL, NULL, NULL, NULL);

				FETCH NEXT FROM ChapterCursor INTO @ChapterId;
			END

			CLOSE ChapterCursor;
			DEALLOCATE ChapterCursor;

			-- Cursor for Document table
			DECLARE DocumentCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Documents];

			OPEN DocumentCursor;
			FETCH NEXT FROM DocumentCursor INTO @DocId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into DocumentLanguage
				INSERT INTO [SBSC].[DocumentLanguage] (LangId, DocId, Headlines, [Description])
				VALUES (@LangId, @DocId, NULL, NULL);

				FETCH NEXT FROM DocumentCursor INTO @DocId;
			END

			CLOSE DocumentCursor;
			DEALLOCATE DocumentCursor;

			-- Cursor for ReportBlocksLanguage table
			DECLARE ReportBlocksCursor CURSOR FOR
			SELECT Id FROM [SBSC].[ReportBlocks];

			OPEN ReportBlocksCursor;
			FETCH NEXT FROM ReportBlocksCursor INTO @ReportBlockId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into DocumentLanguage
				INSERT INTO [SBSC].[ReportBlocksLanguage] (LangId, ReportBlockId, Headlines)
				VALUES (@LangId, @ReportBlockId, NULL);

				FETCH NEXT FROM ReportBlocksCursor INTO @ReportBlockId;
			END

			CLOSE ReportBlocksCursor;
			DEALLOCATE ReportBlocksCursor;



			-- Cursor for RequirementAnswerOptions table
			DECLARE RequirementAnswerOptionsCursor CURSOR FOR
			SELECT Id FROM [SBSC].[RequirementAnswerOptions];

			OPEN RequirementAnswerOptionsCursor;
			FETCH NEXT FROM RequirementAnswerOptionsCursor INTO @RequirementAnswerOptionId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into DocumentLanguage
				INSERT INTO [SBSC].[RequirementAnswerOptionsLanguage] (LangId, AnswerOptionId, Answer, HelpText)
				VALUES (@LangId, @RequirementAnswerOptionId, NULL, NULL);

				FETCH NEXT FROM RequirementAnswerOptionsCursor INTO @RequirementAnswerOptionId;
			END

			CLOSE RequirementAnswerOptionsCursor;
			DEALLOCATE RequirementAnswerOptionsCursor;


			-- Cursor for Requirements table
			DECLARE RequirementCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Requirement];

			OPEN RequirementCursor;
			FETCH NEXT FROM RequirementCursor INTO @RequirementId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into DocumentLanguage
				INSERT INTO [SBSC].[RequirementLanguage] (LangId, RequirementId, Headlines, [Description], Notes)
				VALUES (@LangId, @RequirementId, NULL, NULL, NULL);

				FETCH NEXT FROM RequirementCursor INTO @RequirementId;
			END

			CLOSE RequirementCursor;
			DEALLOCATE RequirementCursor;



			-- Cursor for RequirementTypeOption table
			DECLARE RequirementTypeOptionCursor CURSOR FOR
			SELECT Id FROM [SBSC].[RequirementTypeOption];

			OPEN RequirementTypeOptionCursor;
			FETCH NEXT FROM RequirementTypeOptionCursor INTO @RequirementTypeOptionId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Insert into DocumentLanguage
				INSERT INTO [SBSC].[RequirementTypeOptionLanguage] (LangId, RequirementTypeOptionId, AnswerOptions, [Description], HelpText)
				VALUES (@LangId, @RequirementTypeOptionId, NULL, NULL, NULL);

				FETCH NEXT FROM RequirementTypeOptionCursor INTO @RequirementTypeOptionId;
			END

			CLOSE RequirementTypeOptionCursor;
			DEALLOCATE RequirementTypeOptionCursor;





			-- Commit the transaction
			COMMIT TRANSACTION;

			-- Return success message
			SELECT @LangId AS Id, @LanguageCode AS LanguageCode, @LanguageName AS LanguageName, @IsActive AS IsActive, @IsDefault AS IsDefault;
		END TRY
		BEGIN CATCH
			-- Rollback the transaction if any error occurs
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END;

			-- Capture the error details
			DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
			SELECT 
				@ErrorMessage = ERROR_MESSAGE(),
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE();

			-- Rethrow the error
			RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
		END CATCH;
	END



    ELSE IF @Action = 'READ'
    BEGIN
        IF @Id IS NULL
            SELECT * FROM [SBSC].[Languages]
        ELSE
            SELECT [Id], [LanguageCode], [LanguageName], [IsActive], [IsDefault]
            FROM [SBSC].[Languages]
            WHERE Id = @Id
    END

    ELSE IF @Action = 'UPDATE'
    BEGIN
	-- If updating a language to be the default, first reset IsDefault for all other languages
        IF @IsDefault = 1
        BEGIN
            UPDATE [SBSC].[Languages]
            SET IsDefault = 0
            WHERE IsDefault = 1 AND Id <> @Id;
        END
        UPDATE [SBSC].[Languages]
        SET LanguageCode = ISNULL(@LanguageCode, LanguageCode),
            LanguageName = ISNULL(@LanguageName, LanguageName),
            IsActive = ISNULL(@IsActive, IsActive),
            IsDefault = ISNULL(@IsDefault, IsDefault)
        WHERE Id = @Id

		-- Select the updated record to return it
		SELECT * FROM SBSC.[Languages] WHERE Id = @Id;
        
        SELECT @@ROWCOUNT AS RowsAffected
    END

    ELSE IF @Action = 'DELETE'
	IF EXISTS(SELECT 1 FROM SBSC.[Languages] WHERE Id = @Id)
    BEGIN
        DELETE FROM [SBSC].[Languages]
        WHERE Id = @Id
        
		-- Return the deleted Menu ID
		SELECT @Id AS Id;
        SELECT @@ROWCOUNT AS RowsAffected
    END


	-- LIST action with pagination, search, and sorting
	IF @Action = 'LIST'
	BEGIN
		IF @SortColumn NOT IN ('Id', 'LanguageCode', 'LanguageName', 'IsActive', 'IsDefault')
			SET @SortColumn = 'Id';

		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- Constructing the WHERE clause with search filtering
		SET @WhereClause = N'
			WHERE (@SearchValue IS NULL
			OR LanguageCode LIKE ''%'' + @SearchValue + ''%''
			OR LanguageName LIKE ''%'' + @SearchValue + ''%'')';

		-- Counting total records with the filter applied
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM [SBSC].[Languages] ' + @WhereClause;

		-- Execute the count query to get total records
		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT';
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

		-- Calculate total pages based on total records and page size
		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Main query for pagination, sorting, and fetching the data
		SET @SQL = N'
			SELECT Id, LanguageCode, LanguageName, IsActive, IsDefault
			FROM [SBSC].[Languages] ' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
			OFFSET @Offset ROWS 
			FETCH NEXT @PageSize ROWS ONLY;';

		-- Execute the main query to fetch the records
		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @Offset INT, @PageSize INT';
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @Offset, @PageSize;

		-- Return pagination information
		SELECT @TotalRecords AS TotalRecords, 
			   @TotalPages AS TotalPages, 
			   @PageNumber AS CurrentPage, 
			   @PageSize AS PageSize,
			   CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			   CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END

END
GO