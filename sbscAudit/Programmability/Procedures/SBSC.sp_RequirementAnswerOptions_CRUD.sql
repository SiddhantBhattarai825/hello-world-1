SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE PROCEDURE [SBSC].[sp_RequirementAnswerOptions_CRUD]
    @Action NVARCHAR(50),
    @OptionId INT = NULL,             
    @RequirementId INT = NULL,      
    @LangId INT = NULL, 
	@DefaultLangId INT = NULL,
	@RequirementTypeId INT = NULL,
	
	-- Requirement Answers
	@RequirementAnswerOptions [SBSC].[AnswerOption] READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'DELETE')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, or DELETE', 16, 1);
        RETURN;
    END

    -- Handle CREATE action
    IF @Action = 'CREATE'
    BEGIN
		-- Insert into AnswerOption and AnswerOptionLanguage tables
		IF EXISTS (SELECT 1 FROM @RequirementAnswerOptions)
		BEGIN
			WITH NumberedAnswerOptions AS (
				SELECT 
					[Id],
					[AnswerDefault],
					[HelpTextDefault],
					[AnswerLang],
					[HelpTextLang],
					[DisplayOrder],
					[Value],
					[IsCritical], 
					ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
				FROM @RequirementAnswerOptions
			)

			-- Insert into AnswerOption table with row number as DisplayOrder if NULL
			INSERT INTO [SBSC].[RequirementAnswerOptions] (
				[RequirementId], [DisplayOrder], [Value], [RequirementTypeOptionId], [IsCritical]
			)
			SELECT 
				@RequirementId,
				ISNULL([DisplayOrder], RowNum),
				ISNULL([Value], RowNum),
				CASE 
						WHEN @RequirementTypeId = 2 AND TRY_CAST([AnswerDefault] AS INT) IS NOT NULL 
						THEN CAST([AnswerDefault] AS INT) 
						ELSE NULL 
					END,
				ISNULL([IsCritical], 0)
			FROM NumberedAnswerOptions;

			DECLARE @DefaultLanguageCreateId INT;
			IF @DefaultLangId IS NULL
			BEGIN
				SELECT TOP 1 @DefaultLanguageCreateId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
				SET @DefaultLangId = @DefaultLanguageCreateId;
			END

			-- Declare cursor for languages
			DECLARE @CurrentLangId INT;
			DECLARE LanguageCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Languages];

			OPEN LanguageCursor;
			FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				WITH NumberedAnswerOptions AS (
					SELECT 
						[Id],
						[AnswerDefault],
						[HelpTextDefault],
						[AnswerLang],
						[HelpTextLang],
						[DisplayOrder],
						[Value],
						[IsCritical], 
						ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
					FROM @RequirementAnswerOptions
				)
				-- Insert into AnswerOptionLanguage table
				INSERT INTO [SBSC].[RequirementAnswerOptionsLanguage] (
					[AnswerOptionId], [LangId], [Answer], [HelpText]
				)
				SELECT
					COALESCE(R.[Id], AO.[Id]),
					@CurrentLangId,
					CASE 
						WHEN @CurrentLangId = @LangId THEN R.[AnswerLang]
						WHEN @CurrentLangId = @DefaultLangId THEN R.[AnswerDefault]
						ELSE NULL
					END,
					CASE 
						WHEN @CurrentLangId = @LangId THEN R.[HelpTextLang]
						WHEN @CurrentLangId = @DefaultLangId THEN R.[HelpTextDefault]
						ELSE NULL
					END
				FROM [SBSC].[RequirementAnswerOptions] AO
				JOIN NumberedAnswerOptions R
					ON AO.[RequirementId] = @RequirementId
					AND AO.[DisplayOrder] = ISNULL(R.[DisplayOrder], R.RowNum);

				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			END

			CLOSE LanguageCursor;
			DEALLOCATE LanguageCursor;
		END
    END

    -- Handle DELETE action
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY

            DELETE FROM [SBSC].[RequirementAnswerOptions] WHERE Id = @OptionId;

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
END;
GO