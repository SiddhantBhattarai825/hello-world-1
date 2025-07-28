SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [SBSC].[sp_RequirementTypeOption_CRUD] 
	@Action NVARCHAR(20),
    @Id INT = NULL,
    @RequirementTypeId INT = NULL,
	@AnswerOptions NVARCHAR (500) = NULL,
	@Description NVARCHAR(MAX) = NULL,
	@HelpText NVARCHAR(MAX) = NULL,
    @Score DECIMAL(5,2) = NULL,
	@DisplayOrder INT = NULL,
	@IsActive BIT = NULL,
    @IsVisible BIT = NULL,
	@AddedDate DATE = NULL,
	@AddedBy INT = null,
	@ModifiedBy INT = NULL,
	@ModifiedDate DATE = NULL,
	@LangId INT = NULL,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS

BEGIN
    SET NOCOUNT ON;


    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATELANG')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST or UPDATELANG.', 16, 1);
        RETURN;
    END

    -- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		DECLARE @NewRequirementTypeOptionId INT;
		BEGIN TRY
			BEGIN TRANSACTION;
        
			-- Insert into RequirementTypeOption table
			INSERT INTO [SBSC].[RequirementTypeOption] (
				[RequirementTypeId], [IsVisible], [IsActive],
				[AddedDate], [AddedBy], [ModifiedDate],
				[ModifiedBy], [Score], [DisplayOrder]
			)
			VALUES (
				@RequirementTypeId, ISNULL(@IsVisible, 1), ISNULL(@IsActive, 1),
				GETDATE(), @AddedBy, GETDATE(),
				@AddedBy, ISNULL(@Score, 0), NULLIF(@DisplayOrder, NULL)
			);

			-- Get the newly inserted RequirementTypeOptionId
			SET @NewRequirementTypeOptionId = SCOPE_IDENTITY();

			-- Update DisplayOrder to match NewRequirementTypeOptionId if DisplayOrder was NULL
			IF @DisplayOrder IS NULL
			BEGIN
				UPDATE [SBSC].[RequirementTypeOption]
				SET [DisplayOrder] = @NewRequirementTypeOptionId
				WHERE [Id] = @NewRequirementTypeOptionId;
			END

			-- Loop through all languages and insert into RequirementTypeOptionLanguage table
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
					-- Insert with the provided values for the specified LangId
					INSERT INTO [SBSC].[RequirementTypeOptionLanguage] (
						[RequirementTypeOptionId],
						[LangId],
						[AnswerOptions],
						[Description],
						[HelpText]
					)
					VALUES (
						@NewRequirementTypeOptionId,
						@LangId,
						@AnswerOptions,
						@Description,
						@HelpText
					);
				END
				ELSE
				BEGIN
					-- Insert with NULL values for other languages
					INSERT INTO [SBSC].[RequirementTypeOptionLanguage] (
						[RequirementTypeOptionId],
						[LangId],
						[AnswerOptions],
						[Description],
						[HelpText]
					)
					VALUES (
						@NewRequirementTypeOptionId,
						@CurrentLangId,
						NULL,
						NULL,
						NULL
					);
				END
            
				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			END

			-- Close and deallocate the cursor
			CLOSE LanguageCursor;
			DEALLOCATE LanguageCursor;

			-- Commit the transaction
			COMMIT TRANSACTION;

			-- Return newly inserted requirement type option
			SELECT
				@NewRequirementTypeOptionId AS [Id],
				@RequirementTypeId AS [RequirementTypeId],
				@AnswerOptions AS [AnswerOptions],
				@Description AS [Description],
				@HelpText AS [HelpText],
				@Score AS [Score];
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
			THROW; -- Re-throw error
		END CATCH;
	END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
		IF @LangId IS NULL
		BEGIN
			DECLARE @DefaultLangId INT;
			SELECT TOP 1 @DefaultLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLangId;
		END

		IF @Id IS NULL
		BEGIN
			SELECT * FROM [SBSC].[vw_RequirementTypeOptionsDetails]
			WHERE [LangId] = @LangId;
		END
		ELSE
		BEGIN
			SELECT *
			FROM [SBSC].[vw_RequirementTypeOptionsDetails]
			WHERE Id = @Id AND [LangId] = @LangId;
		END
    END

	-- UPDATE operation
	ELSE IF @Action = 'UPDATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
        
			-- Update the RequirementTypeOption table
			UPDATE [SBSC].[RequirementTypeOption]
			SET 
				RequirementTypeId = ISNULL(@RequirementTypeId, RequirementTypeId),
				IsVisible = ISNULL(@IsVisible, IsVisible),
				IsActive = ISNULL(@IsActive, IsActive),
				ModifiedDate = ISNULL(@ModifiedDate, GETDATE()),
				ModifiedBy = ISNULL(@ModifiedBy, ModifiedBy),
				Score = ISNULL(@Score, Score),
				DisplayOrder = ISNULL(@DisplayOrder, DisplayOrder)
			WHERE 
				Id = @Id;

			-- If language-specific data is provided, update RequirementTypeOptionLanguage
			IF @LangId IS NOT NULL
			BEGIN
				UPDATE [SBSC].[RequirementTypeOptionLanguage]
				SET 
					AnswerOptions = ISNULL(@AnswerOptions, AnswerOptions),
					Description = ISNULL(@Description, Description),
					HelpText = ISNULL(@HelpText, HelpText)
				WHERE 
					RequirementTypeOptionId = @Id
					AND LangId = @LangId;
			END

			-- Output the updated row's details
			SELECT 
				@Id AS Id,
				@RequirementTypeId AS RequirementTypeId,
				@IsVisible AS IsVisible,
				@IsActive AS IsActive,
				@Score AS Score,
				@DisplayOrder AS DisplayOrder,
				@LangId AS LangId,
				@AnswerOptions AS AnswerOptions,
				@Description AS Description,
				@HelpText AS HelpText;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
        
			DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY()
			DECLARE @UpdateErrorState INT = ERROR_STATE()
			RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState)
		END CATCH
	END;

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY

            DELETE FROM SBSC.RequirementTypeOption WHERE Id = @Id;

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

   ELSE IF @Action = 'LIST'
	BEGIN
		-- Declare default language ID variable
		DECLARE @DefaultLanguageId INT;

		-- If LangId is not provided, get the default language ID
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLanguageId = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageId; -- Set LangId to the default language ID
		END

		-- Validate and sanitize the sort column
		IF @SortColumn NOT IN ('Id', 'DisplayOrder', 'Score')
			SET @SortColumn = 'DisplayOrder';

		-- Validate the sort direction
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		-- Declare variables for pagination
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- Define the WHERE clause for search filtering
		SET @WhereClause = N'
			WHERE LangId = @LangId
			AND (@SearchValue IS NULL
			OR AnswerOptions LIKE ''%'' + @SearchValue + ''%''
			OR Description LIKE ''%'' + @SearchValue + ''%'')';

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(*)
			FROM [SBSC].[vw_RequirementTypeOptionsDetails]
			' + @WhereClause;

		-- Set parameter definition including all necessary parameters
		SET @ParamDefinition = N'
			@LangId INT,
			@SearchValue NVARCHAR(100),
			@TotalRecords INT OUTPUT';

		-- Execute the total count query
		EXEC sp_executesql 
			@SQL,
			@ParamDefinition,
			@LangId = @LangId,
			@SearchValue = @SearchValue,
			@TotalRecords = @TotalRecords OUTPUT;

		-- Calculate total pages
		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Build the main query for data retrieval
		SET @SQL = N'
			SELECT * FROM [SBSC].[vw_RequirementTypeOptionsDetails]
			' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
			OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
			FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY;

			-- Return pagination metadata
			SELECT 
				@TotalRecords AS TotalRecords,
				@TotalPages AS TotalPages,
				@PageNumber AS CurrentPage,
				@PageSize AS PageSize,
				CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
				CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;';

		-- Update parameter definition to include @TotalPages
		SET @ParamDefinition = N'
			@LangId INT,
			@SearchValue NVARCHAR(100),
			@TotalRecords INT,
			@TotalPages INT,
			@PageNumber INT,
			@PageSize INT';

		-- Execute the final query with all parameters
		EXEC sp_executesql 
			@SQL,
			@ParamDefinition,
			@LangId = @LangId,
			@SearchValue = @SearchValue,
			@TotalRecords = @TotalRecords,
			@TotalPages = @TotalPages,
			@PageNumber = @PageNumber,
			@PageSize = @PageSize;
	END
	
	-- UPDATELANG Operation to update language-specific requirement
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
                RAISERROR('RequirementTypeOption Id must be provided for updating language.', 16, 1);
            END
        ELSE
			BEGIN TRY
				UPDATE [SBSC].[RequirementTypeOptionLanguage]
				SET 
					AnswerOptions = ISNULL(@AnswerOptions, AnswerOptions),
					Description = ISNULL(@Description, Description),
					HelpText = ISNULL(@HelpText, HelpText)
				WHERE 
					RequirementTypeOptionId = @Id
					AND LangId = @LangId;

				SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
			END TRY
			BEGIN CATCH
				THROW; -- Re-throw the error
			END CATCH
	END
END
GO