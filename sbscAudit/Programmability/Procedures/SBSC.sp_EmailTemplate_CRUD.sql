SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_EmailTemplate_CRUD]
    @Action NVARCHAR(20),
    @Id INT = NULL, -- Used for READ, UPDATE, DELETE, UPDATE_COLUMN
    @Title NVARCHAR(100) = NULL,
    @Description NVARCHAR(500) = NULL,
    @EmailCode NVARCHAR(100) = NULL,
    @IsActive BIT = NULL,
    @LangId INT = NULL,
    @Tags NVARCHAR(500) = NULL,
    @AddedBy INT = NULL, 
    @AddedDate DATETIME = NULL, 
	@ExpiryTime FLOAT = NULL,

	@EmailBody NVARCHAR(MAX) = NULL,
    @EmailSubject NVARCHAR(500) = NULL,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, or LIST', 16, 1);
        RETURN;
    END

	IF @ACTION = 'CREATE'
	BEGIN
		DECLARE @EmailTemplateId INT;

		-- Check if a record with the same Code already exists
		IF EXISTS (SELECT 1 FROM [SBSC].[EmailTemplate] WHERE EmailCode = @EmailCode)
		BEGIN
			RAISERROR('A record with the provided Email Code already exists.', 16, 1);
			RETURN;
		END

		-- Start the transaction
		BEGIN TRY
			BEGIN TRANSACTION;

			-- Insert into EmailTemplate table
			INSERT INTO [SBSC].[EmailTemplate] (
				[Title], [Description], [EmailCode], [IsActive], [Tags], [AddedDate], [AddedBy], [ExpiryTime]
			)
			VALUES (
				@Title,
				@Description,
				@EmailCode,
				@IsActive,
				@Tags,
				GETDATE(),
				@AddedBy,
				ISNULL(@ExpiryTime, 9999999)
			);

			-- Get the newly inserted EmailTemplate Id
			SET @EmailTemplateId = SCOPE_IDENTITY();

			-- Loop through all languages and insert into EmailTemplateLanguage table
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
					-- Insert with the provided EmailBody and EmailSubject for the specified LangId
					INSERT INTO [SBSC].[EmailTemplateLanguage] (
						[LangId], [EmailTemplateId], [EmailBody], [EmailSubject]
					)
					VALUES (
						@CurrentLangId, 
						@EmailTemplateId, 
						@EmailBody,  -- Provided EmailBody
						@EmailSubject -- Provided EmailSubject
					);
				END
				ELSE
				BEGIN
					-- Insert with NULL EmailBody and EmailSubject for other languages
					INSERT INTO [SBSC].[EmailTemplateLanguage] (
						[LangId], [EmailTemplateId], [EmailBody], [EmailSubject]
					)
					VALUES (
						@CurrentLangId, 
						@EmailTemplateId, 
						NULL,  -- NULL EmailBody
						NULL   -- NULL EmailSubject
					);
				END

				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			END

			-- Close and deallocate the cursor
			CLOSE LanguageCursor;
			DEALLOCATE LanguageCursor;

			-- Commit the transaction
			COMMIT TRANSACTION;

			-- Return success message
			SELECT 
				@EmailTemplateId AS [Id], 
				@Title AS [Title], 
				@Description AS [Description],
				@EmailCode AS [EmailCode],
				ISNULL(@IsActive, 0) AS [IsActive],
				@Tags AS [Tags],
				@LangId AS [LangId],
				@EmailBody AS [EmailBody],
				@EmailSubject AS [EmailSubject]
			           
		END TRY
		BEGIN CATCH
			-- Rollback the transaction if any error occurs
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END;

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
	    DECLARE @DefaultLanguageId INT;
        -- If LangId is not provided, get the first Id from Languages table
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultLanguageId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageId; -- Set LangId to the first language Id
        END

	    IF @Id IS NULL
		BEGIN
			SELECT * FROM [SBSC].[vw_EmailTemplateDetails]
			WHERE [LanguageId] = @LangId;
		END
		ELSE
		BEGIN
			SELECT *
			FROM [SBSC].[vw_EmailTemplateDetails]
			WHERE [EmailTemplateId] = @Id AND [LanguageId] = @LangId;
		END
    END

    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
			-- Check if a record with the same Code already exists
		IF EXISTS (SELECT 1 FROM [SBSC].[EmailTemplate] WHERE EmailCode = @EmailCode AND [Id] <> @Id)
		BEGIN
			RAISERROR('A record with the provided Email Code already exists.', 16, 1);
			RETURN;
		END

		BEGIN TRY
			UPDATE [SBSC].[EmailTemplate]
			SET 
				[Title] = ISNULL(@Title, [Title]),
				[Description] = ISNULL(@Description, [Description]),
				[EmailCode] = ISNULL(@EmailCode, [EmailCode]),
				[IsActive] = ISNULL(@IsActive, [IsActive]),
				[Tags] = ISNULL(@Tags, [Tags]),
				[ExpiryTime] = ISNULL(@ExpiryTime, 9999999)
			WHERE [Id] = @Id;
		
		END TRY
		BEGIN CATCH

            DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @UpdateErrorState INT = ERROR_STATE()

            RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState)
        END CATCH
    END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        DELETE FROM [SBSC].[EmailTemplate]
        WHERE [Id] = @Id;
    END
END
GO