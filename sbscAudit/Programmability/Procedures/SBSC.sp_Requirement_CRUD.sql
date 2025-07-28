SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_Requirement_CRUD] 
	@Action NVARCHAR(50),
	@AssignmentId INT = NULL,
    @Id INT = NULL,
	@RequirementTypeId INT = NULL,
	@ChapterId INT = NULL,
	@ReferenceNo NVARCHAR(50) = NULL,
	@Headlines NVARCHAR(500) = NULL,
	@Description NVARCHAR(MAX) = NULL,
	@Notes NVARCHAR(MAX) = NULL,
	@DefaultLangId INT = NULL,
	@HeadlinesLang NVARCHAR(500) = NULL,
	@DescriptionLang NVARCHAR(MAX) = NULL,
	@NotesLang NVARCHAR(MAX) = NULL,
	@LangId INT = NULL,
	@IsCommentable BIT = NULL,
	@IsFileUploadRequired BIT = NULL,
	@IsFileUploadAble BIT = NULL,
	@IsWarning BIT = NULL,
	@DisplayOrder INT = 1,
    @IsActive INT = NULL,
    @IsVisible BIT = NULL,
	@AddedDate DATE = NULL,
	@AddedBy INT = null,
	@ModifiedBy INT = NULL,
	@ModifiedDate DATE = NULL,
	@AuditYears NVARCHAR(50) = NULL,
	@UserId INT = NULL,
	@UserRole INT = NULL,
	@Recertification INT = NULL,
	@Version DECIMAL(6,2) = NULL,
	@ParentRequirementId INT = NULL,
	@IsChanged BIT = NULL,

	-- For RequirementCertifications
	@RequirementChapterId INT = NULL,

	-- Requirement Answers
	@RequirementAnswerOptions [SBSC].[AnswerOption] READONLY,

	@CertificationId INT = NULL,

	@CertificationCodes [SBSC].[CertificationCodeTableType] READONLY,

	@CertificationIds [SBSC].[CertificationIdList] READONLY,
	
	@CustomerId INT = NULL,
	@DeviationStatus BIT = 0,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS

BEGIN
    SET NOCOUNT ON;


    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'ASSIGNCERT', 'UPDATECERT', 'DELETECERT', 'UPDATELANG', 'DISPLAYORDER', 'LIST_BY_CERTIFICATION_CODES', 'LIST_BY_CERTIFICATION_IDS')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, ASSIGNCERT, UPDATECERT, DELETECERT, UPDATELANG, DISPLAYORDER, LIST_BY_CERTIFICATION_IDS or LIST_BY_CERT_CODE.', 16, 1);
        RETURN;
    END

	DECLARE @CurrentLangId INT;
	DECLARE @NewRequirementId INT;


	-- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		
		BEGIN TRY
			BEGIN TRANSACTION;

			DECLARE @CertificateAuditYears NVARCHAR(255) = NULL;
			DECLARE @InvalidValue NVARCHAR(MAX) = '';

			SELECT @CertificateAuditYears = (SELECT AuditYears from sbsc.Certification where Id = (Select CertificationId from sbsc.Chapter where Id = @ChapterId))

			DECLARE @AllowedValues TABLE (
				Value NVARCHAR(10)
			);

			INSERT INTO @AllowedValues (Value)
				SELECT TRIM(value)
				FROM STRING_SPLIT(@CertificateAuditYears, ',')
				WHERE TRIM(value) <> '';

			
			DECLARE @TempInvalidValue NVARCHAR(MAX) = '';

			SELECT @TempInvalidValue = 
				CASE 
					WHEN @TempInvalidValue = '' THEN TRIM(SA.value)  -- For the first value, just set the value without a comma
					ELSE @TempInvalidValue + ', ' + TRIM(SA.value)  -- For subsequent values, concatenate with a comma
				END
			FROM STRING_SPLIT(@AuditYears, ',') AS SA
			WHERE TRIM(SA.value) <> ''
			  AND NOT EXISTS (
				  SELECT 1 FROM @AllowedValues 
				  WHERE Value = TRIM(SA.value)
			  );

			-- Set the final value without trailing comma
			SET @InvalidValue = @TempInvalidValue;

			IF LEN(@InvalidValue) > 0
			BEGIN
    
				RAISERROR('Invalid audit year values found: %s. These values are not in the allowed list.', 16, 1, @InvalidValue);
				RETURN;
			END

			DECLARE @SortedValues TABLE (
				SortOrder INT IDENTITY(1,1),
				Value NVARCHAR(10)
			);

			INSERT INTO @SortedValues (Value)
			SELECT LTRIM(RTRIM(value))
			FROM STRING_SPLIT(@AuditYears, ',')
			ORDER BY CAST(LTRIM(RTRIM(value)) AS INT);

			SELECT @AuditYears = STRING_AGG(Value, ', ') 
			FROM @SortedValues;

			IF (LEFT(@AuditYears, 1) <> '0' OR @AuditYears LIKE '%,0,%' OR @AuditYears LIKE '%,0')
			   AND EXISTS (SELECT 1 FROM @AllowedValues WHERE Value = '0')
			BEGIN
				SET @AuditYears = '0, ' + @AuditYears;
			END


			SELECT @Version = MAX([Version]) FROM SBSC.Certification where Id IN (SELECT CertificationId FROM SBSC.Chapter where Id = @ChapterId); 

			-- Insert into Requirement table
			INSERT INTO [SBSC].[Requirement] (
				[RequirementTypeId], [IsCommentable], [IsFileUploadAble], [IsFileUploadRequired],
				[DisplayOrder], [IsVisible], [IsActive], [AddedDate],
				[AddedBy], AuditYears, Version, ParentRequirementId, IsChanged
			)
			VALUES (
				@RequirementTypeId, @IsCommentable, @IsFileUploadAble, @IsFileUploadRequired,
				NULLIF(@DisplayOrder, NULL), ISNULL(@IsVisible, 1), ISNULL(@IsActive, 1),
				GETDATE(), @AddedBy, @AuditYears, @Version, NULL, 0
			);
			-- Get the newly inserted RequirementId
			SET @NewRequirementId = SCOPE_IDENTITY();
			-- Update DisplayOrder to match NewRequirementId if DisplayOrder was NULL
			IF @DisplayOrder IS NULL
			BEGIN
				UPDATE [SBSC].[Requirement]
				SET [DisplayOrder] = @NewRequirementId
				WHERE [Id] = @NewRequirementId;
			END

			-- Adjust DisplayOrder for other requirements
			UPDATE r
			SET r.[DisplayOrder] = 
				CASE 
					WHEN [DisplayOrder] >= @DisplayOrder THEN [DisplayOrder] + 1
					ELSE [DisplayOrder] - 1
				END
			FROM SBSC.Requirement r
			WHERE [Id] <> @NewRequirementId
			 AND NOT EXISTS (
				  SELECT 1
				  FROM [SBSC].[Requirement] r2
				  WHERE r.Id = r2.ParentRequirementId);

			DECLARE @ChapterDisplayOrder INT;

			-- Calculate the next display order for the given ChapterId
			SELECT @ChapterDisplayOrder = ISNULL(MAX(DispalyOrder), 0) + 1
			FROM [SBSC].[RequirementChapters]
			WHERE ChapterId = @ChapterId;

			-- Check if ChapterId and ReferenceNo are not NULL
			IF @ChapterId IS NOT NULL AND @ReferenceNo IS NOT NULL
			BEGIN
				-- Insert the new record with the calculated DisplayOrder
				INSERT INTO [SBSC].[RequirementChapters] ([ReferenceNo], [RequirementId], [ChapterId], [IsWarning], DispalyOrder)
				VALUES (@ReferenceNo, @NewRequirementId, @ChapterId, ISNULL(@IsWarning, 0), @ChapterDisplayOrder);
			END;

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
					@NewRequirementId,
					ISNULL([DisplayOrder], RowNum),
					ISNULL([Value], RowNum),
					CASE 
						WHEN @RequirementTypeId = 2 AND TRY_CAST([AnswerDefault] AS INT) IS NOT NULL 
						THEN CAST([AnswerDefault] AS INT) 
						ELSE NULL 
					END,
					ISNULL([IsCritical], 0) -- Add IsCritical with default value 0
				FROM NumberedAnswerOptions;

				DECLARE @DefaultLanguageCreateId INT;
				IF @DefaultLangId IS NULL
				BEGIN
					SELECT TOP 1 @DefaultLanguageCreateId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
					SET @DefaultLangId = @DefaultLanguageCreateId;
				END
				
				-- Declare cursor for languages
				
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
						ON AO.[RequirementId] = @NewRequirementId
						AND AO.[DisplayOrder] = ISNULL(R.[DisplayOrder], R.RowNum);

					FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
				END

				CLOSE LanguageCursor;
				DEALLOCATE LanguageCursor;
			END

			-- Cursor to loop through all languages
			DECLARE LanguageCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Languages];
			OPEN LanguageCursor;
			FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Check if the current LangId matches the provided @LangId or DefaultLangId
				IF @CurrentLangId = @DefaultLangId
				BEGIN
					-- Insert with the provided Headlines and Description for the specified LangId
					INSERT INTO [SBSC].[RequirementLanguage] (
						[RequirementId], [LangId], [Headlines], [Description], [Notes]
					)
					VALUES (
						@NewRequirementId, @DefaultLangId, @Headlines, @Description, @Notes
					);
				END
				ELSE IF @CurrentLangId = @LangId
				BEGIN
					-- Insert with the default Headlines and Description for the DefaultLangId
					INSERT INTO [SBSC].[RequirementLanguage] (
						[RequirementId], [LangId], [Headlines], [Description], [Notes]
					)
					VALUES (
						@NewRequirementId, @LangId, @HeadlinesLang, @DescriptionLang, @NotesLang
					);
				END
				ELSE
				BEGIN
					-- Insert with NULL values for other languages
					INSERT INTO [SBSC].[RequirementLanguage] (
						[RequirementId], [LangId], [Headlines], [Description], [Notes]
					)
					VALUES (
						@NewRequirementId, @CurrentLangId, NULL, NULL, NULL
					);
				END

				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
			END
			-- Close and deallocate the cursor
			CLOSE LanguageCursor;
			DEALLOCATE LanguageCursor;

			-- Commit the transaction
			COMMIT TRANSACTION;
			-- Return newly inserted requirement
			SELECT
				@NewRequirementId AS [Id],
				@RequirementTypeId AS [RequirementTypeId],
				@ReferenceNo AS [ReferenceNo],
				@Headlines AS [Headlines],
				@Description AS [Description],
				@Notes AS [Notes];
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
			DECLARE @DefaultLanguageIdRead INT; 
			SELECT TOP 1 @DefaultLanguageIdRead = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLanguageIdRead; 
		END

		IF @Id IS NULL 
		BEGIN 
			SELECT * ,
			-- Get AnswerOptions as a JSON array
			(
				SELECT 
					ao.Id, 
					ao.DisplayOrder, 
					ao.RequirementTypeOptionId as Answer,
					ao.IsCritical,
					ISNULL(
						CASE 
							WHEN ao.RequirementTypeOptionId IS NOT NULL THEN 
								(SELECT 
									 ISNULL(rtol.AnswerOptions, '') 
								 FROM 
									 [SBSC].[RequirementTypeOptionLanguage] rtol 
								 WHERE 
									 rtol.RequirementTypeOptionId = ao.RequirementTypeOptionId 
									 AND rtol.LangId = @LangId)
							ELSE 
								aol.Answer 
						END, 
					'') AS AnswerText,  -- Handle NULL values
					ISNULL(aol.HelpText, '') AS HelpText
				FROM 
					[SBSC].[RequirementAnswerOptions] ao
				LEFT JOIN  
					[SBSC].[RequirementAnswerOptionsLanguage] aol 
					ON ao.Id = aol.AnswerOptionId 
					AND aol.LangId = @LangId  -- language filter within JOIN condition
				WHERE 
					ao.RequirementId = r.RequirementId
				ORDER BY 
					ao.DisplayOrder  -- Order the answer options
				FOR JSON PATH
			) AS AnswerOptionsJson,
			-- Get RequirementChapters as a JSON array
			(
				SELECT 
					rc.Id, 
					rc.ReferenceNo, 
					rc.ChapterId, 
					ISNULL(cl.ChapterTitle, ch.Title) AS ChapterTitle,
					ch.CertificationId,
					cert.CertificateCode,
					cert.Validity,
					cert.IsAuditorInitiated,
					cert.AuditYears,
					rc.IsWarning,
					ch.DisplayOrder,
					[SBSC].[GetChapterDisplayOrderHistory](rc.ChapterId) AS DisplayOrderHistory,
					CASE 
						WHEN rc.ChapterId = @ChapterId THEN 0
						WHEN ch.CertificationId = @CertificationId THEN 1
						ELSE 2
					END AS SortOrder
				FROM 
					[SBSC].[RequirementChapters] rc
				INNER JOIN 
					[SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
				LEFT JOIN 
					[SBSC].[ChapterLanguage] cl ON cl.ChapterId = ch.Id AND cl.LanguageId = @LangId
				INNER JOIN 
					[SBSC].[Certification] cert ON ch.CertificationId = cert.Id
				WHERE 
					rc.RequirementId = r.RequirementId
				ORDER BY 
					CASE 
						WHEN rc.ChapterId = @ChapterId THEN 0
						WHEN ch.CertificationId = @CertificationId THEN 1
						ELSE 2
					END,
					rc.Id
				FOR JSON PATH
			) AS RequirementChaptersJson
			FROM [SBSC].[vw_RequirementDetails] r
			WHERE r.LangId = @LangId
			  AND NOT EXISTS (
				  SELECT 1
				  FROM [SBSC].[vw_RequirementDetails] r2
				  WHERE r.RequirementId = r2.ParentRequirementId
			  )
			ORDER BY r.DisplayOrder;  -- Order the main results
		END 
		ELSE 
		BEGIN 
			SELECT * ,
			-- Get AnswerOptions as a JSON array
			(
				SELECT 
					ao.Id, 
					ao.DisplayOrder, 
					ao.RequirementTypeOptionId as Answer,
					ao.IsCritical,
					ISNULL(
						CASE 
							WHEN ao.RequirementTypeOptionId IS NOT NULL THEN 
								(SELECT 
									 ISNULL(rtol.AnswerOptions, '') 
								 FROM 
									 [SBSC].[RequirementTypeOptionLanguage] rtol 
								 WHERE 
									 rtol.RequirementTypeOptionId = ao.RequirementTypeOptionId 
									 AND rtol.LangId = @LangId)
							ELSE 
								aol.Answer 
						END, 
					'') AS AnswerText,  -- Handle NULL values
					ISNULL(aol.HelpText, '') AS HelpText 
				FROM 
					[SBSC].[RequirementAnswerOptions] ao
				LEFT JOIN  
					[SBSC].[RequirementAnswerOptionsLanguage] aol 
					ON ao.Id = aol.AnswerOptionId 
					AND aol.LangId = @LangId  -- language filter within JOIN condition
				WHERE 
					ao.RequirementId = r.RequirementId
				ORDER BY 
					ao.DisplayOrder  -- Order the answer options
				FOR JSON PATH
			) AS AnswerOptionsJson,
			-- Get RequirementChapters as a JSON array
			(
				SELECT 
					rc.Id, 
					rc.ReferenceNo, 
					rc.ChapterId, 
					ISNULL(cl.ChapterTitle, ch.Title) AS ChapterTitle,
					ch.CertificationId,
					cert.CertificateCode,
					cert.Validity,
					cert.IsAuditorInitiated,
					cert.AuditYears,
					rc.IsWarning,
					ch.DisplayOrder,
					[SBSC].[GetChapterDisplayOrderHistory](rc.ChapterId) AS DisplayOrderHistory,
					CASE 
						WHEN rc.ChapterId = @ChapterId THEN 0
						WHEN ch.CertificationId = @CertificationId THEN 1
						ELSE 2
					END AS SortOrder
				FROM 
					[SBSC].[RequirementChapters] rc
				INNER JOIN 
					[SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
				LEFT JOIN 
					[SBSC].[ChapterLanguage] cl ON cl.ChapterId = ch.Id AND cl.LanguageId = @LangId
				INNER JOIN 
					[SBSC].[Certification] cert ON ch.CertificationId = cert.Id
				WHERE 
					rc.RequirementId = r.RequirementId
				ORDER BY 
					CASE 
						WHEN rc.ChapterId = @ChapterId THEN 0
						WHEN ch.CertificationId = @CertificationId THEN 1
						ELSE 2
					END,
					rc.Id
				FOR JSON PATH
			) AS RequirementChaptersJson
			FROM [SBSC].[vw_RequirementDetails] r
			WHERE r.LangId = @LangId
			AND r.RequirementId = @Id 
			AND r.ChapterId = @ChapterId
			ORDER BY r.DisplayOrder;
		END 
	END

    -- UPDATE operation
	ELSE IF @Action = 'UPDATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;

			IF @ChapterId IS NULL
			BEGIN
				RAISERROR ('ChapterId is required.', 16, 1);
				RETURN;
			END

			IF NOT EXISTS (
				SELECT 1 
				FROM [SBSC].[RequirementChapters] 
				WHERE RequirementId = @Id 
				AND ChapterId = @ChapterId
			)
			BEGIN
				RAISERROR('Invalid Requirement ID or Chapter ID combination', 16, 1);
				RETURN;
			END

			DECLARE @CertificateAuditYear NVARCHAR(255) = NULL;
			DECLARE @InvalidValues NVARCHAR(MAX) = '';

			SELECT @CertificateAuditYear = (SELECT AuditYears from sbsc.Certification where Id = (Select CertificationId from sbsc.Chapter where Id = @ChapterId))

			DECLARE @AllowedValue TABLE (
				Value NVARCHAR(10)
			);

			INSERT INTO @AllowedValue (Value)
				SELECT TRIM(value)
				FROM STRING_SPLIT(@CertificateAuditYear, ',')
				WHERE TRIM(value) <> '';

			
			DECLARE @TempInvalidValues NVARCHAR(MAX) = '';

			SELECT @TempInvalidValues = 
				CASE 
					WHEN @TempInvalidValues = '' THEN TRIM(SA.value)  -- For the first value, just set the value without a comma
					ELSE @TempInvalidValues + ', ' + TRIM(SA.value)  -- For subsequent values, concatenate with a comma
				END
			FROM STRING_SPLIT(@AuditYears, ',') AS SA
			WHERE TRIM(SA.value) <> ''
			  AND NOT EXISTS (
				  SELECT 1 FROM @AllowedValue 
				  WHERE Value = TRIM(SA.value)
			  );

			-- Set the final value without trailing comma
			SET @InvalidValues = @TempInvalidValues;

			IF LEN(@InvalidValues) > 0
			BEGIN
    
				RAISERROR('Invalid audit year values found: %s. These values are not in the allowed list.', 16, 1, @InvalidValues);
				RETURN;
			END

			DECLARE @SortedValue TABLE (
				SortOrder INT IDENTITY(1,1),
				Value NVARCHAR(10)
			);

			INSERT INTO @SortedValue (Value)
			SELECT LTRIM(RTRIM(value))
			FROM STRING_SPLIT(@AuditYears, ',')
			ORDER BY CAST(LTRIM(RTRIM(value)) AS INT);

			SELECT @AuditYears = STRING_AGG(Value, ', ') 
			FROM @SortedValue;

			IF (LEFT(@AuditYears, 1) <> '0' OR @AuditYears LIKE '%,0,%' OR @AuditYears LIKE '%,0')
			   AND EXISTS (SELECT 1 FROM @AllowedValue WHERE Value = '0')
			BEGIN
				SET @AuditYears = '0, ' + @AuditYears;
			END
        
			SELECT @Version = MAX(Version) FROM SBSC.Certification WHERE Id IN (SELECT CertificationId FROM SBSC.Chapter WHERE Id = @ChapterId);

			IF EXISTS (SELECT 1 FROM SBSC.Requirement WHERE Id = @Id AND Version = @Version)
			BEGIN
				-- Update the main Requirement table
				UPDATE [SBSC].[Requirement]
				SET 
					RequirementTypeId = ISNULL(@RequirementTypeId, RequirementTypeId),
					IsCommentable = ISNULL(@IsCommentable, IsCommentable),
					IsFileUploadAble = ISNULL(@IsFileUploadAble, IsFileUploadAble),
					IsFileUploadRequired = ISNULL(@IsFileUploadRequired, IsFileUploadRequired),
					DisplayOrder = ISNULL(@DisplayOrder, DisplayOrder),
					IsVisible = ISNULL(@IsVisible, IsVisible),
					IsActive = ISNULL(@IsActive, IsActive),
					ModifiedBy = ISNULL(@ModifiedBy, ModifiedBy),
					ModifiedDate = ISNULL(@ModifiedDate, GETDATE()),
					AuditYears = ISNULL(@AuditYears, AuditYears),
					IsChanged = ISNULL(@IsChanged, IsChanged)
				WHERE 
					Id = @Id;

				-- Update language-specific requirement data
				IF @DefaultLangId IS NOT NULL
				BEGIN
					UPDATE [SBSC].[RequirementLanguage]
					SET [Headlines] = ISNULL(@Headlines, Headlines),
						[Description] = ISNULL(@Description, [Description]),
						[Notes] = ISNULL(@Notes, [Notes])
					WHERE [RequirementId] = @Id AND [LangId] = @DefaultLangId;
				END

				-- Update language-specific requirement data
				IF @LangId IS NOT NULL
				BEGIN
					UPDATE [SBSC].[RequirementLanguage]
					SET [Headlines] = ISNULL(@HeadlinesLang, Headlines),
						[Description] = ISNULL(@DescriptionLang, [Description]),
						[Notes] = ISNULL(@NotesLang, [Notes])
					WHERE [RequirementId] = @Id AND [LangId] = @LangId;
				END

				-- Handle RequirementAnswerOptions
				IF EXISTS (SELECT 1 FROM @RequirementAnswerOptions)
				BEGIN
					-- Iterate through each row in the @RequirementAnswerOptions table
					DECLARE @OptionId INT, 
							@AnswersDisplayOrder INT,
							@AnswerDefault NVARCHAR(500), 
							@HelpTextDefault NVARCHAR(MAX), 
							@AnswerLang NVARCHAR(500), 
							@HelpTextLang NVARCHAR(MAX),
							@AnswersValue INT,
							@IsCritical BIT;

					DECLARE AnswerOptionCursor CURSOR FOR
					SELECT 
						[Id],
						[DisplayOrder],
						[AnswerDefault],
						[HelpTextDefault],
						[AnswerLang],
						[HelpTextLang],
						[Value],
						[IsCritical]
					FROM @RequirementAnswerOptions;

					OPEN AnswerOptionCursor;
					FETCH NEXT FROM AnswerOptionCursor INTO @OptionId, @AnswersDisplayOrder, @AnswerDefault, @HelpTextDefault, @AnswerLang, @HelpTextLang, @AnswersValue, @IsCritical;

					WHILE @@FETCH_STATUS = 0
					BEGIN
						-- Update RequirementAnswerOptions table
						UPDATE [SBSC].[RequirementAnswerOptions]
						SET 
							[DisplayOrder] = ISNULL(@AnswersDisplayOrder, [DisplayOrder]),
							[Value] = ISNULL(@AnswersValue, [Value]),
							[RequirementTypeOptionId] = 
							CASE 
								WHEN @RequirementTypeId = 2 AND ISNUMERIC(@AnswerDefault) = 1 THEN CAST(@AnswerDefault AS INT)
								ELSE [RequirementTypeOptionId]
							END,
							[IsCritical] = ISNULL(@IsCritical, 0)
						WHERE 
							[Id] = @OptionId;

						-- Update language-specific data for LangId
						IF @LangId IS NOT NULL
						BEGIN
							UPDATE [SBSC].[RequirementAnswerOptionsLanguage]
							SET 
								[Answer] = ISNULL(@AnswerLang, [Answer]),
								[HelpText] = ISNULL(@HelpTextLang, [HelpText])
							WHERE 
								[AnswerOptionId] = @OptionId 
								AND [LangId] = @LangId;

							-- Ensure no data inconsistency
							IF @@ROWCOUNT = 0
							BEGIN
								RAISERROR('AnswerOptionId %d with LangId %d not found in RequirementAnswerOptionsLanguage.', 16, 1, @OptionId, @LangId);
							END
						END

						-- Update language-specific data for DefaultLangId
						IF @DefaultLangId IS NOT NULL
						BEGIN
							UPDATE [SBSC].[RequirementAnswerOptionsLanguage]
							SET 
								[Answer] = ISNULL(@AnswerDefault, [Answer]),
								[HelpText] = ISNULL(@HelpTextDefault, [HelpText])
							WHERE 
								[AnswerOptionId] = @OptionId 
								AND [LangId] = @DefaultLangId;

							-- Ensure no data inconsistency
							IF @@ROWCOUNT = 0
							BEGIN
								RAISERROR('AnswerOptionId %d with DefaultLangId %d not found in RequirementAnswerOptionsLanguage.', 16, 1, @OptionId, @DefaultLangId);
							END
						END

						FETCH NEXT FROM AnswerOptionCursor INTO @OptionId, @AnswersDisplayOrder, @AnswerDefault, @HelpTextDefault, @AnswerLang, @HelpTextLang, @AnswersValue, @IsCritical;
					END

					CLOSE AnswerOptionCursor;
					DEALLOCATE AnswerOptionCursor;
				END


			END
			ELSE
			BEGIN
				INSERT INTO [SBSC].[Requirement] (
					[RequirementTypeId], [IsCommentable], [IsFileUploadAble], [IsFileUploadRequired],
					[DisplayOrder], [IsVisible], [IsActive], [AddedDate],
					[AddedBy], AuditYears, Version, ParentRequirementId, IsChanged
				)
				SELECT
					ISNULL(@RequirementTypeId, RequirementTypeId),
					ISNULL(@IsCommentable, IsCommentable),
					ISNULL(@IsFileUploadAble, IsFileUploadAble),
					ISNULL(@IsFileUploadRequired, IsFileUploadRequired),
					ISNULL(@DisplayOrder, DisplayOrder),
					ISNULL(@IsVisible, IsVisible),
					ISNULL(@IsActive, IsActive),
					ISNULL(@ModifiedDate, GETDATE()),
					ISNULL(@ModifiedBy, ModifiedBy),
					ISNULL(@AuditYears, AuditYears),
					@Version,
					@Id,
					0
				FROM SBSC.Requirement 
				WHERE Id = @Id
				
				-- Get the newly inserted RequirementId
				SET @NewRequirementId = SCOPE_IDENTITY();


				UPDATE SBSC.RequirementChapters
				SET RequirementId = @NewRequirementId,
					ReferenceNo = ISNULL(@ReferenceNo, ReferenceNo),
					IsWarning = ISNULL(@IsWarning, IsWarning)
				WHERE ChapterId = @ChapterId
				AND RequirementId = @Id

				DECLARE LanguageCursor CURSOR FOR
				SELECT Id FROM [SBSC].[Languages];
				OPEN LanguageCursor;
				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
				WHILE @@FETCH_STATUS = 0
				BEGIN
					-- Check if the current LangId matches the provided @LangId or DefaultLangId
					IF @CurrentLangId = @DefaultLangId
					BEGIN
						-- Insert with the provided Headlines and Description for the specified LangId
						INSERT INTO [SBSC].[RequirementLanguage] (
							[RequirementId], [LangId], [Headlines], [Description], [Notes]
						)
						SELECT
							@NewRequirementId,
							ISNULL(@DefaultLangId, [LangId]),
							ISNULL(@Headlines, [Headlines]),
							ISNULL(@Description, [Description]),
							ISNULL(@Notes, [Notes])
						FROM SBSC.RequirementLanguage
						WHERE RequirementId = @Id
						AND LangId = @DefaultLangId;
					END
					ELSE IF @CurrentLangId = @LangId
					BEGIN
						-- Insert with the default Headlines and Description for the DefaultLangId
						INSERT INTO [SBSC].[RequirementLanguage] (
							[RequirementId], [LangId], [Headlines], [Description], [Notes]
						)
						SELECT
							@NewRequirementId,
							ISNULL(@LangId, [LangId]),
							ISNULL(@HeadlinesLang, [Headlines]),
							ISNULL(@DescriptionLang, [Description]),
							ISNULL(@NotesLang, [Notes])
						FROM SBSC.RequirementLanguage
						WHERE RequirementId = @Id
						AND LangId = @LangId;
					END
					ELSE
					BEGIN
						-- Insert with NULL values for other languages
						INSERT INTO [SBSC].[RequirementLanguage] (
							[RequirementId], [LangId], [Headlines], [Description], [Notes]
						)
						SELECT
							@NewRequirementId,
							@CurrentLangId,
							[Headlines],
							[Description],
							[Notes]
						FROM SBSC.RequirementLanguage
						WHERE RequirementId = @Id
						AND LangId = @CurrentLangId;
					END

					FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
				END
				-- Close and deallocate the cursor
				CLOSE LanguageCursor;
				DEALLOCATE LanguageCursor;


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
						@NewRequirementId,
						ISNULL([DisplayOrder], RowNum),
						ISNULL([Value], RowNum),
						CASE 
							WHEN @RequirementTypeId = 2 AND TRY_CAST([AnswerDefault] AS INT) IS NOT NULL 
							THEN CAST([AnswerDefault] AS INT) 
							ELSE NULL 
						END,
						ISNULL([IsCritical], 0) -- Add IsCritical with default value 0
					FROM NumberedAnswerOptions;

					DECLARE @DefLanguageId INT;
					IF @DefaultLangId IS NULL
					BEGIN
						SELECT TOP 1 @DefLanguageId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
						SET @DefaultLangId = @DefLanguageId;
					END
				
					-- Declare cursor for languages
				
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
								ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS RowNum
							FROM @RequirementAnswerOptions
						)
						-- Insert into AnswerOptionLanguage table
						INSERT INTO [SBSC].[RequirementAnswerOptionsLanguage] (
							[AnswerOptionId], [LangId], [Answer], [HelpText]
						)
						SELECT
							AO.[Id],
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
							ON AO.[RequirementId] = @NewRequirementId
							AND AO.[DisplayOrder] = ISNULL(R.[DisplayOrder], R.RowNum);

						FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
					END

					CLOSE LanguageCursor;
					DEALLOCATE LanguageCursor;
				END

			END

			-- Output the updated row's details
			SELECT 
				@Id AS Id, 
				@RequirementTypeId AS RequirementTypeId, 
				@IsCommentable AS IsCommentable, 
				@IsFileUploadAble AS IsFileUploadAble,
				@IsFileUploadRequired AS IsFileUploadRequired, 
				@DisplayOrder AS DisplayOrder, 
				@IsVisible AS IsVisible, 
				@IsActive AS IsActive,
				@IsCritical AS IsCritical;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
        
			DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY();
			DECLARE @UpdateErrorState INT = ERROR_STATE();
			RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState);
		END CATCH
	END;

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRANSACTION;
		BEGIN TRY

			SELECT @Version = MAX(Version) FROM SBSC.Certification WHERE Id IN (SELECT CertificationId FROM SBSC.Chapter where Id = @ChapterId);

			UPDATE rc
			SET rc.DispalyOrder = rc.DispalyOrder - 1
			FROM [SBSC].[RequirementChapters] rc
			WHERE rc.ChapterId = @ChapterId
			AND rc.DispalyOrder > (SELECT DispalyOrder FROM SBSC.RequirementChapters WHERE RequirementId = @Id AND ChapterId = @ChapterId);

			-- Delete the requirement and from RequirementChapters
			DELETE FROM [SBSC].[RequirementChapters] 
			WHERE RequirementId = @Id
			AND ChapterId = @ChapterId;

			SELECT @Id AS Id;
        
			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
        
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
			SET @LangId = @DefaultLanguageId;
		END

		-- Validate and sanitize the sort column
		IF @SortColumn NOT IN ('RequirementId', 'DisplayOrder', 'ReferenceNo')
			SET @SortColumn = 'DisplayOrder';

		-- Validate the sort direction
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		-- Declare variables for dynamic SQL and pagination
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(MAX);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;
		DECLARE @OrderByClause NVARCHAR(MAX);

		-- Define the WHERE clause for search filtering
		SET @WhereClause = N'
			WHERE LangId = @LangId
			--AND NOT EXISTS (
			--	  SELECT 1
			--	  FROM [SBSC].[Requirement] r2
			--	  WHERE r.RequirementId = r2.ParentRequirementId)
			AND (@SearchValue IS NULL
			OR Headlines LIKE ''%'' + @SearchValue + ''%'')';

		-- Add filters for CertificationId and ChapterId
		IF @CertificationId IS NOT NULL
			SET @WhereClause = @WhereClause + N' 
			AND ChapterId IN (SELECT ID FROM SBSC.Chapter c WHERE c.CertificationId = @CertificationId)';

		IF @ChapterId IS NOT NULL
			SET @WhereClause = @WhereClause + N' 
			AND ChapterId = @ChapterId';

		IF @UserRole = 2
		BEGIN
			SET @WhereClause += N'
				AND r.RequirementId IN (
					SELECT RequirementId FROM SBSC.RequirementChapters 
					WHERE ChapterId IN (
						SELECT Id FROM SBSC.Chapter 
						WHERE CertificationId IN (
							SELECT CertificationId FROM SBSC.Auditor_Certifications 
							WHERE AuditorId = @UserId)))';
		END

		-- Set OrderBy clause based on SortColumn
		IF @SortColumn = 'ReferenceNo'
		BEGIN
			SET @OrderByClause = N'
			ORDER BY 
				-- First sort by whether the requirement has a ReferenceNo within the specified Certification (0 for with ReferenceNo, 1 for without)
				CASE 
					WHEN EXISTS (
						SELECT 1
						FROM [SBSC].[RequirementChapters] rc 
						INNER JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
						WHERE rc.RequirementId = r.RequirementId
						AND rc.ReferenceNo IS NOT NULL
						AND rc.ReferenceNo <> ''''
						AND (@CertificationId IS NULL OR ch.CertificationId = @CertificationId)
					) THEN 0
					ELSE 1
				END ASC,
				-- Then sort by the first ReferenceNo within the specified Certification
				CASE 
					WHEN EXISTS (
						SELECT 1
						FROM [SBSC].[RequirementChapters] rc 
						INNER JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
						WHERE rc.RequirementId = r.RequirementId
						AND rc.ReferenceNo IS NOT NULL
						AND rc.ReferenceNo <> ''''
						AND (@CertificationId IS NULL OR ch.CertificationId = @CertificationId)
					) THEN (
						SELECT TOP 1 rc.ReferenceNo
						FROM [SBSC].[RequirementChapters] rc 
						INNER JOIN [SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
						WHERE rc.RequirementId = r.RequirementId
						AND rc.ReferenceNo IS NOT NULL
						AND rc.ReferenceNo <> ''''
						AND (@CertificationId IS NULL OR ch.CertificationId = @CertificationId)
						ORDER BY rc.Id
					)
				END ' + @SortDirection;
		END
		ELSE
		BEGIN
			SET @OrderByClause =
					N' ORDER BY 
                (SELECT MIN([SBSC].[GetChapterDisplayOrderHistory](rc.ChapterId)) 
                 FROM [SBSC].[RequirementChapters] rc 
                 WHERE rc.RequirementId = r.RequirementId) ASC,
                (SELECT MIN(rc.DispalyOrder) 
                 FROM [SBSC].[RequirementChapters] rc 
                 WHERE rc.RequirementId = r.RequirementId) ASC'; 
				--CASE 
				--	WHEN @ChapterId IS NOT NULL THEN N'
				--		ORDER BY 
				--			(SELECT rc.DispalyOrder 
				--			 FROM [SBSC].[RequirementChapters] rc 
				--			 WHERE rc.RequirementId = r.RequirementId 
				--			 AND rc.ChapterId = @ChapterId) ' + @SortDirection + N', 
				--			' + QUOTENAME(@SortColumn) + N' ' + @SortDirection
				--	ELSE N'ORDER BY ' + QUOTENAME(@SortColumn) + N' ' + @SortDirection
				--END;
		END

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(*)
			FROM [SBSC].[vw_RequirementDetails] r
			' + @WhereClause;

		-- Define parameter types for sp_executesql
		SET @ParamDefinition = N'
			@LangId INT, 
			@SearchValue NVARCHAR(100), 
			@CertificationId INT, 
			@ChapterId INT, 
			@UserId INT,
			@TotalRecords INT OUTPUT';

		-- Execute the total count query
		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@LangId, 
			@SearchValue, 
			@CertificationId, 
			@ChapterId, 
			@UserId,
			@TotalRecords OUTPUT;

		-- Calculate total pages
		SET @TotalPages = CASE 
			WHEN @TotalRecords > 0 
			THEN CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize) 
			ELSE 0 
		END;

		-- Retrieve paginated data with AnswerOptionsJson and RequirementChaptersJson
		SET @SQL = N'
		SELECT r.*,
		(
			SELECT 
				ao.Id, 
				ao.DisplayOrder, 
				ao.RequirementTypeOptionId as Answer,
				ISNULL(
					CASE 
						WHEN ao.RequirementTypeOptionId IS NOT NULL THEN 
							(SELECT 
								 ISNULL(rtol.AnswerOptions, '''') 
							 FROM 
								 [SBSC].[RequirementTypeOptionLanguage] rtol 
							 WHERE 
								 rtol.RequirementTypeOptionId = ao.RequirementTypeOptionId 
								 AND rtol.LangId = @LangId)
						ELSE 
							aol.Answer 
					END, 
				'''') AS AnswerText,
				ISNULL(aol.HelpText, '''') AS HelpText,
				ao.IsCritical
			FROM 
				[SBSC].[RequirementAnswerOptions] ao
			LEFT JOIN  
				[SBSC].[RequirementAnswerOptionsLanguage] aol 
				ON ao.Id = aol.AnswerOptionId 
				AND aol.LangId = @LangId
			WHERE 
				ao.RequirementId = r.RequirementId
			ORDER BY 
				ao.DisplayOrder
			FOR JSON PATH
		) AS AnswerOptionsJson,
		(
			SELECT 
				rc.Id, 
				rc.ReferenceNo, 
				rc.ChapterId, 
				ISNULL(cl.ChapterTitle, ch.Title) AS ChapterTitle,
				ch.CertificationId,
				cert.CertificateCode,
				cert.Validity,
				cert.IsAuditorInitiated,
				cert.AuditYears,
				rc.IsWarning,
				ch.DisplayOrder,
				rc.DispalyOrder AS ReqDisplayOrder,
				[SBSC].[GetChapterDisplayOrderHistory](rc.ChapterId) AS DisplayOrderHistory,
				CASE 
					WHEN rc.ChapterId = @ChapterId THEN 0
					WHEN ch.CertificationId = @CertificationId THEN 1
					ELSE 2
				END AS SortOrder
			FROM 
				[SBSC].[RequirementChapters] rc
			INNER JOIN 
				[SBSC].[Chapter] ch ON rc.ChapterId = ch.Id
			LEFT JOIN 
				[SBSC].[ChapterLanguage] cl ON cl.ChapterId = ch.Id AND cl.LanguageId = @LangId
			INNER JOIN 
				[SBSC].[Certification] cert ON ch.CertificationId = cert.Id
			WHERE 
				rc.RequirementId = r.RequirementId
			ORDER BY 
				CASE 
					WHEN rc.ChapterId = @ChapterId THEN 0
					WHEN ch.CertificationId = @CertificationId THEN 1
					ELSE 2
				END,
				DisplayOrderHistory, ReqDisplayOrder
			FOR JSON PATH
		) AS RequirementChaptersJson
		FROM [SBSC].[vw_RequirementDetails] r
		' + @WhereClause + N'
		' + @OrderByClause + N'
		OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + N' ROWS 
		FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + N' ROWS ONLY';
		
		-- Execute the paginated query
		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@LangId, 
			@SearchValue, 
			@CertificationId, 
			@ChapterId, 
			@UserId,
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

	ELSE IF @Action = 'ASSIGNCERT'
	BEGIN
		BEGIN TRY
			DECLARE @LastDisplayOrder INT;
        
			-- Get the current maximum display order for the chapter
			SELECT @LastDisplayOrder = ISNULL(MAX(DispalyOrder), 0)
			FROM [SBSC].[RequirementChapters]
			WHERE ChapterId = @ChapterId;
        
			-- Insert the new requirement with incremented display order
			UPDATE [SBSC].[RequirementChapters]
			SET DispalyOrder = @LastDisplayOrder + 1,
				ReferenceNo = @ReferenceNo,
				IsWarning = @IsWarning
			WHERE RequirementId = @Id
			AND ChapterId = @ChapterId
            
			-- Return the inserted data
			SELECT
				@Id AS [RequirementId],
				@ChapterId AS [ChapterId],
				@ReferenceNo AS [ReferenceNo],
				@IsWarning AS [IsWarning],
				@LastDisplayOrder + 1 AS [DispalyOrder];
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION
        
			DECLARE @AssignCertErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
			DECLARE @AssignCertErrorSeverity INT = ERROR_SEVERITY()
			DECLARE @AssignCertErrorState INT = ERROR_STATE()
			RAISERROR(@AssignCertErrorMessage, @AssignCertErrorSeverity, @AssignCertErrorState)
		END CATCH
	END

	-- Update Certifications
	ELSE IF @Action = 'UPDATECERT'
	BEGIN
		BEGIN TRY
			UPDATE [SBSC].[RequirementChapters]
			SET 
				ReferenceNo = ISNULL(@ReferenceNo, ReferenceNo),
				RequirementId = ISNULL(@Id, RequirementId),
				ChapterId = ISNULL(@ChapterId, ChapterId),
				IsWarning = ISNULL(@IsWarning, IsWarning)
			WHERE 
				Id = @RequirementChapterId;

			SELECT
					@Id AS [RequirementId],
					@ChapterId AS [ChapterId],
					@ReferenceNo AS [ReferenceNo],
					@IsWarning AS [IsWarning];
		END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @UpdateCertErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @UpdateCertErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @UpdateCertErrorState INT = ERROR_STATE()

            RAISERROR(@UpdateCertErrorMessage, @UpdateCertErrorSeverity, @UpdateCertErrorState)
        END CATCH
	END

	-- Remove Certifications
	ELSE IF @Action = 'DELETECERT'
	BEGIN
		BEGIN TRY

			DELETE FROM [SBSC].[RequirementChapters] WHERE Id = @RequirementChapterId;
			
		END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @DeleteCertErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @DeleteCertErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @DeleteCertErrorState INT = ERROR_STATE()

            RAISERROR(@DeleteCertErrorMessage, @DeleteCertErrorSeverity, @DeleteCertErrorState)
        END CATCH
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
                RAISERROR('Requirement Id must be provided for updating language.', 16, 1);
            END
        ELSE
			BEGIN TRY
				UPDATE [SBSC].[RequirementLanguage]
				SET [Headlines] = ISNULL(@Headlines, Headlines),
					[Description] = ISNULL(@Description, [Description]),
					[Notes] = ISNULL(@Notes, [Notes])
				WHERE [RequirementId] = @Id and [LangId] = @LangId

				SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
			END TRY
			BEGIN CATCH
				THROW; -- Re-throw the error
			END CATCH
	END

	-- DISPLAYORDER operation
	ELSE IF @Action = 'DISPLAYORDER'
	BEGIN
		DECLARE @OldDisplayOrder INT;
		DECLARE @ErrorMessage NVARCHAR(4000);

		-- Validate that the RequirementChapter combination exists
		IF NOT EXISTS (
			SELECT 1 
			FROM [SBSC].[RequirementChapters] 
			WHERE RequirementId = @Id 
			AND ChapterId = @ChapterId
		)
		BEGIN
			SET @ErrorMessage = 'Invalid Requirement ID or Chapter ID combination';
			RAISERROR(@ErrorMessage, 16, 1);
			RETURN;
		END

		-- Get the current DisplayOrder
		SELECT @OldDisplayOrder = DispalyOrder
		FROM [SBSC].[RequirementChapters]
		WHERE RequirementId = @Id 
		AND ChapterId = @ChapterId;

		-- If the old DisplayOrder is NULL, we need to handle it as a special case
		IF @OldDisplayOrder IS NULL
		BEGIN
        BEGIN TRANSACTION;
        
			-- Shift all existing items up
			UPDATE [SBSC].[RequirementChapters]
			SET DispalyOrder = DispalyOrder + 1
			WHERE ChapterId = @ChapterId
			AND DispalyOrder >= @DisplayOrder
			AND DispalyOrder IS NOT NULL;

			-- Set the new DisplayOrder
			UPDATE [SBSC].[RequirementChapters]
			SET DispalyOrder = @DisplayOrder
			WHERE RequirementId = @Id 
			AND ChapterId = @ChapterId;

			IF @@ERROR <> 0
			BEGIN
				ROLLBACK TRANSACTION;
				RAISERROR('Error updating display order', 16, 1);
				RETURN;
			END

			COMMIT TRANSACTION;
			RETURN;
		END

		-- If the new and old DisplayOrder are the same, no update needed
		IF @DisplayOrder = @OldDisplayOrder
		BEGIN
			RETURN;
		END

		BEGIN TRANSACTION;
    
		-- If DisplayOrder is increasing
		IF @DisplayOrder > @OldDisplayOrder
		BEGIN
			UPDATE [SBSC].[RequirementChapters]
			SET DispalyOrder = DispalyOrder - 1
			WHERE ChapterId = @ChapterId
			AND DispalyOrder > @OldDisplayOrder 
			AND DispalyOrder <= @DisplayOrder;
        
			IF @@ERROR <> 0
			BEGIN
				ROLLBACK TRANSACTION;
				RAISERROR('Error updating display order', 16, 1);
				RETURN;
			END
		END
		-- If DisplayOrder is decreasing
		ELSE IF @DisplayOrder < @OldDisplayOrder
		BEGIN
			UPDATE [SBSC].[RequirementChapters]
			SET DispalyOrder = DispalyOrder + 1
			WHERE ChapterId = @ChapterId
			AND DispalyOrder >= @DisplayOrder 
			AND DispalyOrder < @OldDisplayOrder;
        
			IF @@ERROR <> 0
			BEGIN
				ROLLBACK TRANSACTION;
				RAISERROR('Error updating display order', 16, 1);
				RETURN;
			END
		END

		-- Update the target requirement's DisplayOrder
		UPDATE [SBSC].[RequirementChapters]
		SET DispalyOrder = @DisplayOrder
		WHERE RequirementId = @Id 
		AND ChapterId = @ChapterId;

		IF @@ERROR <> 0
		BEGIN
			ROLLBACK TRANSACTION;
			RAISERROR('Error updating display order', 16, 1);
			RETURN;
		END

		COMMIT TRANSACTION;
	END

	ELSE IF @Action = 'LIST_BY_CERTIFICATION_CODES'
	BEGIN
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @LangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
		END

		SELECT 
			CertificationRequirementJson = (
				SELECT 
					c.Id AS CertificationId,
					c.CertificateTypeId,
					cc.Title AS CertificationType,
					c.CertificateCode,
					ccl.CertificationName AS CertificationName,
					c.Validity,
					c.AuditYears,
					c.Published,
					c.IsActive,
					c.IsVisible,
					c.IsAuditorInitiated,
					(
						SELECT 
							ch.Id AS ChapterId,
							chl.ChapterTitle AS ChapterTitle,
							chl.ChapterDescription AS ChapterDescription,
							ch.IsWarning,
							ch.IsVisible,
							ch.DisplayOrder,
							-- Updated chapter-level status (0/1/2)
							CASE 
                                WHEN @CustomerId IS NULL THEN NULL
                                ELSE CASE
                                    WHEN NOT EXISTS (
                                        SELECT 1 
                                        FROM [SBSC].[RequirementChapters] rc 
                                        INNER JOIN [SBSC].[Requirement] r ON rc.RequirementId = r.Id
                                        WHERE rc.ChapterId = ch.Id
                                        AND EXISTS (SELECT 1 FROM @CertificationIds ci WHERE ci.CertificationId = c.Id)
                                    ) THEN 0
                                    WHEN EXISTS (
                                        SELECT 1 
                                        FROM [SBSC].[RequirementChapters] rc 
                                        LEFT JOIN [SBSC].[CustomerResponse] cr 
                                            ON cr.RequirementId = rc.RequirementId 
                                            AND cr.CustomerId = @CustomerId
                                        WHERE rc.ChapterId = ch.Id
                                        AND cr.Id IS NULL
                                    ) THEN 0
                                    ELSE 1
                                END
                            END AS isAllAnswered,
							(
								SELECT DISTINCT  -- Added DISTINCT keyword
									r.Id,
									rl.Headlines,
									rl.Description,
									@LangId AS LangId,
									r.RequirementTypeId,
									rt.Name AS RequirementType,
									rc.DispalyOrder AS DisplayOrder,
									r.IsCommentable,
									r.IsFileUploadAble,
									r.IsFileUploadRequired,
									r.IsVisible,
									r.IsActive,
									r.AddedDate,
									-- Use MAX to get the latest answer status for duplicate responses
									MAX(CASE 
										WHEN @CustomerId IS NULL THEN NULL
										WHEN cr.Id IS NULL THEN 0
										ELSE 1
									END) AS isAnswered,
									(
										SELECT 
											rao.Id,
											rao.DisplayOrder,
											rao.RequirementTypeOptionId AS Answer,
											rao.IsCritical,
											ISNULL(
												CASE 
													WHEN rao.RequirementTypeOptionId IS NOT NULL THEN 
														(SELECT 
															ISNULL(rtol.AnswerOptions, '') 
														 FROM 
															[SBSC].[RequirementTypeOptionLanguage] rtol 
														 WHERE 
															rtol.RequirementTypeOptionId = rao.RequirementTypeOptionId 
															AND rtol.LangId = @LangId)
													ELSE 
														raol.Answer 
												END, 
											'') AS AnswerText,
											raol.HelpText
										FROM [SBSC].[RequirementAnswerOptions] rao
										LEFT JOIN [SBSC].[RequirementAnswerOptionsLanguage] raol 
											ON raol.AnswerOptionId = rao.Id AND raol.LangId = @LangId
										WHERE rao.RequirementId = r.Id
										ORDER BY rao.DisplayOrder
										FOR JSON PATH
									) AS AnswerOptionsJson,
									(
										SELECT 
											rc_inner.Id,
											rc_inner.ReferenceNo,
											rc_inner.ChapterId,
											ch_inner.Title AS ChapterTitle,
											ch_inner.CertificationId,
											cert_inner.CertificateCode,
											cert_inner.Validity,
											rc_inner.IsWarning
										FROM 
											[SBSC].[RequirementChapters] rc_inner
										INNER JOIN 
											[SBSC].[Chapter] ch_inner ON rc_inner.ChapterId = ch_inner.Id
										INNER JOIN 
											[SBSC].[Certification] cert_inner ON ch_inner.CertificationId = cert_inner.Id
										WHERE 
											rc_inner.RequirementId = r.Id
										ORDER BY 
											rc_inner.DispalyOrder
										FOR JSON PATH
									) AS RequirementChaptersJson
								FROM [SBSC].[Requirement] r
								INNER JOIN [SBSC].[RequirementChapters] rc ON rc.RequirementId = r.Id
								INNER JOIN [SBSC].[RequirementType] rt ON rt.Id = r.RequirementTypeId
								LEFT JOIN [SBSC].[CustomerResponse] cr 
									ON cr.RequirementId = r.Id 
									AND cr.CustomerId = @CustomerId
								LEFT JOIN [SBSC].[CustomerDocuments] cd 
									ON cd.CustomerResponseId = cr.Id
								LEFT JOIN [SBSC].[RequirementLanguage] rl 
									ON rl.RequirementId = r.Id AND rl.LangId = @LangId
								WHERE rc.ChapterId = ch.Id
								GROUP BY -- Added GROUP BY clause for DISTINCT and MAX aggregation
									r.Id,
									rl.Headlines,
									rl.Description,
									r.RequirementTypeId,
									rt.Name,
									rc.DispalyOrder,
									r.IsCommentable,
									r.IsFileUploadAble,
									r.IsFileUploadRequired,
									r.IsVisible,
									r.IsActive,
									r.AddedDate
								ORDER BY rc.DispalyOrder
								FOR JSON PATH
							) AS RequirementsJson
						FROM [SBSC].[Chapter] ch
						LEFT JOIN [SBSC].[ChapterLanguage] chl 
							ON chl.ChapterId = ch.Id AND chl.LanguageId = @LangId
						WHERE ch.CertificationId = c.Id
						ORDER BY ch.DisplayOrder
						FOR JSON PATH
					) AS ChaptersJson
				FROM [SBSC].[Certification] c
				INNER JOIN [SBSC].[CertificationCategory] cc ON cc.Id = c.CertificateTypeId
				LEFT JOIN [SBSC].[CertificationLanguage] ccl 
					ON ccl.CertificationId = c.Id AND ccl.LangId = @LangId
				WHERE EXISTS (
					SELECT 1 
					FROM @CertificationCodes cc
					WHERE cc.CertificationCode = c.CertificateCode
				)
				ORDER BY c.CertificateCode
				FOR JSON PATH
			);
	END

	ELSE IF @Action = 'LIST_BY_CERTIFICATION_IDS'
	BEGIN
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @LangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
		END

		-- Fetch CustomerCertificationDetailsId based on AssignmentId
		DECLARE @TempCertDetails TABLE (CustomerCertificationDetailsId INT);
		INSERT INTO @TempCertDetails 
		SELECT ccd.Id 
		FROM SBSC.AssignmentCustomerCertification acc
			INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
			WHERE acc.AssignmentId = @AssignmentId;


		SELECT 
			CertificationRequirementJson = (
				SELECT 
					@AssignmentId AS AssignmentId,
					c.Id AS CertificationId,
					ccd.Id AS CustomerCertificationDetailsId,
					cc_main.CustomerCertificationId,
					c.Version,
					c.CertificateTypeId,
					cc.Title AS CertificationType,
					cc.IsActive AS CertificationTypeActiveStatus,
					c.CertificateCode,
					ccl.CertificationName AS CertificationName,
					ccl.[Description] AS CertificationDescription,
					c.Validity,
					c.AuditYears,
					ccl.Published,
					c.IsActive,
					c.IsVisible,
					c.IsAuditorInitiated,
					cc_main.CertificateNumber,      -- Certificate data from Customer_Certifications table
					ao.[Status],					-- Status from AssignmentOccasions
					-- DeviationEndDate, Recertification and other data from CustomerCertificationDetails table
					ccd.DeviationEndDate,
					ccd.Recertification,
					ccd.AddressId,
					ccd.DepartmentId,
					ccd.Status AS CertificationDetailsStatus,
					ccd.IssueDate AS DetailsIssueDate,
					ccd.ExpiryDate AS DetailsExpiryDate,
					-- Total Deviation count using CustomerCertificationDetailsId
					(SELECT COUNT(IsApproved) 
					 FROM SBSC.AuditorCustomerResponses 
					 WHERE CustomerResponseId IN (
						 SELECT Id 
						 FROM SBSC.CustomerResponse 
						 WHERE CustomerCertificationDetailsId = ccd.Id
						 AND RequirementId IN (
							 SELECT rc.RequirementId 
							 FROM SBSC.RequirementChapters rc
							 INNER JOIN SBSC.Chapter ch ON rc.ChapterId = ch.Id
							 WHERE ch.CertificationId = c.Id
						 )
					 )
					 AND IsApproved != 1) AS TotalDeviation,
					-- Response Status JSON using CustomerCertificationDetailsId
					JSON_QUERY(
						(
							SELECT 
								ars.ResponseStatusId AS Id, 
								COALESCE(COUNT(acr.ResponseStatusId), 0) AS [Count]
							FROM 
								(VALUES (1), (2), (3)) AS ars(ResponseStatusId)
							LEFT JOIN 
								SBSC.AuditorCustomerResponses acr
								ON acr.ResponseStatusId = ars.ResponseStatusId
								AND acr.CustomerResponseId IN (
									SELECT Id 
									FROM SBSC.CustomerResponse 
									WHERE CustomerCertificationDetailsId = ccd.Id
									AND RequirementId IN (
										SELECT rc.RequirementId 
										FROM SBSC.RequirementChapters rc
										INNER JOIN SBSC.Chapter ch ON rc.ChapterId = ch.Id
										WHERE ch.CertificationId = c.Id
									)
								)
								AND acr.ResponseStatusId < 4
							GROUP BY 
								ars.ResponseStatusId
							ORDER BY 
								ars.ResponseStatusId
							FOR JSON PATH
						)
					) AS ResponseStatusJson,
					-- Use the recursive function to retrieve the full chapter tree with requirements
					JSON_QUERY(
						SBSC.fn_GetChapterTreeRequirementByDetailsId(
							NULL,                    -- ParentChapterId (NULL for root level)
							@LangId,                 -- Language ID
							ccd.Id,					 -- Customer Certification DetailsId
							@DeviationStatus         -- Deviation status filter
						)
					) AS ChaptersJson
				FROM [SBSC].[Certification] c
				INNER JOIN [SBSC].[CertificationCategory] cc 
					ON cc.Id = c.CertificateTypeId
				LEFT JOIN [SBSC].[CertificationLanguage] ccl 
					ON ccl.CertificationId = c.Id AND ccl.LangId = @LangId
				INNER JOIN SBSC.CustomerCertificationDetails ccd  -- Join CustomerCertificationDetails first
					ON ccd.Id IN (SELECT CustomerCertificationDetailsId FROM @TempCertDetails)
				INNER JOIN SBSC.Customer_Certifications cc_main  -- Then join Customer_Certifications through CustomerCertificationId
					ON cc_main.CustomerCertificationId = ccd.CustomerCertificationId
					AND cc_main.CertificateId = c.Id
				LEFT JOIN SBSC.AssignmentOccasions ao -- Join AssignmentOccasions for status
					ON ao.Id = @AssignmentId
				ORDER BY c.CertificateCode
				FOR JSON PATH
			);
	END;
END
GO