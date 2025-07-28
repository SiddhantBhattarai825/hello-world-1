SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_Chapter_CRUD]
    @Action NVARCHAR(20),
    @Id INT = NULL,
    @Title NVARCHAR(500) = NULL,
    @Description NVARCHAR(MAX) = NULL,
    @IsWarning BIT = NULL,
    @IsVisible BIT = NULL,
	@Added_date DATE = NULL,
    @LangId INT = NULL,
    @ChapterId INT = NULL,
	@AddedBy INT = null,
	@ModifiedBy INT = NULL,
	@ModifiedDate DATE = NULL,
    @CertificationId INT = NULL,
	@DisplayOrder INT =NULL,
	--@CertificateIds VARCHAR(MAX) = NULL,
	@Level INT = NULL,
	@Sections SBSC.ChapterSectionType READONLY,

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
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST','UPDATELANG', 'DISPLAYORDER', 'CREATE_SECTION', 'CREATE_MIGRATION')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, DISPLAYORDER or CREATE_SECTION or CREATE_MIGRATION.', 16, 1);
        RETURN;
    END

    IF @Action = 'CREATE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Table to map TempId to inserted ChapterId
            CREATE TABLE #InsertedSections (
                TempId INT PRIMARY KEY,
                ChapterId INT,
                ParentTempId INT NULL
            );

            -- Insert root sections (ParentTempId = NULL) using MERGE
            MERGE INTO SBSC.Chapter AS target
            USING (
                SELECT 
                    TempId,
                    Title,
                    IsWarning,
                    IsVisible,
                    DisplayOrder,
                    ParentTempId,
                    Level
                FROM @Sections
                WHERE ParentTempId IS NULL
            ) AS src
            ON 1 = 0
            WHEN NOT MATCHED THEN
                INSERT (
                    Title, 
                    IsWarning, 
                    IsVisible, 
                    ParentChapterId, 
                    CertificationId, 
                    DisplayOrder, 
                    AddedBy, 
                    AddedDate,
                    Level
                )
                VALUES (
                    src.Title,
                    src.IsWarning,
                    src.IsVisible,
                    NULL,
                    @CertificationId,
                    ISNULL(src.DisplayOrder, (
                        SELECT ISNULL(MAX(DisplayOrder), 0) + 1 
                        FROM SBSC.Chapter 
                        WHERE CertificationId = @CertificationId 
                          AND ParentChapterId IS NULL
                    )),
                    @AddedBy,
                    GETUTCDATE(),
                    src.Level
                )
            OUTPUT 
                src.TempId, 
                INSERTED.Id, 
                src.ParentTempId
            INTO #InsertedSections (TempId, ChapterId, ParentTempId);

            -- Insert child sections iteratively using MERGE
            DECLARE @CurrentLevel INT = 0;
            WHILE @@ROWCOUNT > 0
            BEGIN
                SET @CurrentLevel += 1;

                MERGE INTO SBSC.Chapter AS target
                USING (
                    SELECT 
                        s.TempId,
                        s.Title,
                        s.IsWarning,
                        s.IsVisible,
                        s.DisplayOrder,
                        s.ParentTempId,
                        s.Level,
                        p.ChapterId AS ParentChapterId
                    FROM @Sections s
                    INNER JOIN #InsertedSections p 
                        ON s.ParentTempId = p.TempId
                    WHERE NOT EXISTS (
                        SELECT 1 
                        FROM #InsertedSections 
                        WHERE TempId = s.TempId
                    )
                ) AS src
                ON 1 = 0
                WHEN NOT MATCHED THEN
                    INSERT (
                        Title, 
                        IsWarning, 
                        IsVisible, 
                        ParentChapterId, 
                        CertificationId, 
                        DisplayOrder, 
                        AddedBy, 
                        AddedDate,
                        Level
                    )
                    VALUES (
                        src.Title,
                        src.IsWarning,
                        src.IsVisible,
                        src.ParentChapterId,
                        @CertificationId,
                        ISNULL(src.DisplayOrder, (
                            SELECT ISNULL(MAX(DisplayOrder), 0) + 1 
                            FROM SBSC.Chapter 
                            WHERE ParentChapterId = src.ParentChapterId
                        )),
                        @AddedBy,
                        GETUTCDATE(),
                        src.Level
                    )
                OUTPUT 
                    src.TempId, 
                    INSERTED.Id, 
                    src.ParentTempId
                INTO #InsertedSections (TempId, ChapterId, ParentTempId);
            END

            -- Create a temporary table to store language-specific content
			CREATE TABLE #LanguageContent (
				ChapterId INT,
				LanguageId INT,
				ChapterTitle NVARCHAR(MAX),
				ChapterDescription NVARCHAR(MAX)
			);

			-- Insert default language content
			INSERT INTO #LanguageContent (ChapterId, LanguageId, ChapterTitle, ChapterDescription)
			SELECT
				i.ChapterId,
				s.DefaultLangId,
				s.Title,
				s.Description
			FROM #InsertedSections i
			INNER JOIN @Sections s ON i.TempId = s.TempId;

			-- Insert additional language content where LangId is not null
			INSERT INTO #LanguageContent (ChapterId, LanguageId, ChapterTitle, ChapterDescription)
			SELECT
				i.ChapterId,
				s.LangId,
				s.TitleLang,
				s.DescriptionLang
			FROM #InsertedSections i
			INNER JOIN @Sections s ON i.TempId = s.TempId
			WHERE s.LangId IS NOT NULL;

			-- Insert translations for all languages
			INSERT INTO SBSC.ChapterLanguage (
				LanguageId, 
				ChapterId, 
				ChapterTitle, 
				ChapterDescription
			)
			SELECT DISTINCT
				l.Id AS LanguageId,
				i.ChapterId,
				CASE 
					WHEN l.Id = s.DefaultLangId THEN s.Title
					WHEN l.Id = s.LangId THEN s.TitleLang
					ELSE NULL
				END AS ChapterTitle,
				CASE 
					WHEN l.Id = s.DefaultLangId THEN s.Description
					WHEN l.Id = s.LangId THEN s.DescriptionLang
					ELSE NULL
				END AS ChapterDescription
			FROM SBSC.Languages l
			CROSS JOIN #InsertedSections i
			INNER JOIN @Sections s ON i.TempId = s.TempId;

            -- Update hasChildSections for parents
            UPDATE c
            SET hasChildSections = 1
            FROM SBSC.Chapter c
            WHERE EXISTS (
                SELECT 1 
                FROM #InsertedSections i 
                WHERE i.ParentTempId IS NOT NULL
                AND i.ChapterId = c.Id
            );

            COMMIT TRANSACTION;

            -- Return results
            SELECT 
                i.ChapterId AS Id,
                s.Title AS ChapterTitle,
                s.Description AS ChapterDescription,
                i.ParentTempId,
                c.ParentChapterId,
				c.DisplayOrder AS Prefix
            FROM #InsertedSections i
            INNER JOIN @Sections s ON i.TempId = s.TempId
            INNER JOIN SBSC.Chapter c ON i.ChapterId = c.Id;

        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK;
            THROW;
        END CATCH;

        -- Clean up temporary tables
        DROP TABLE IF EXISTS #InsertedSections;
        DROP TABLE IF EXISTS #LanguageContent;
    END



    ELSE IF @Action = 'READ'
	BEGIN
		-- Declare a variable to hold the default language ID
		DECLARE @DefaultLangId INT;
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLangId = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1;
			SET @LangId = @DefaultLangId;
		END

		IF @Id IS NOT NULL
		BEGIN
			-- Use NVARCHAR(MAX) to prevent truncation
			SELECT CAST((
				SELECT
					c.Id AS ChapterId,
					cl.ChapterTitle,
					cl.ChapterDescription,
					c.DisplayOrder,
					c.[Level] AS [Level],
					c.IsWarning,
					c.IsVisible,
					c.ParentChapterId,
					c.CertificationId,
					JSON_QUERY(SBSC.fn_GetChapterTree(c.Id, @LangId)) AS Sections
				FROM SBSC.Chapter AS c
				LEFT JOIN SBSC.ChapterLanguage AS cl
					ON cl.ChapterId = c.Id AND cl.LanguageId = @LangId
				WHERE c.Id = @Id
				ORDER BY c.DisplayOrder
				FOR JSON PATH, ROOT('Chapters')
			) AS NVARCHAR(MAX));
		END
		ELSE
		BEGIN
			-- Otherwise, fetch all top-level chapters for the given certification.
			SELECT CAST((
            SELECT
                c.Id AS ChapterId,
                cl.ChapterTitle,
                cl.ChapterDescription,
                c.DisplayOrder,
                c.[Level] AS [Level],
                c.IsWarning,
                c.IsVisible,
                c.ParentChapterId,
                c.CertificationId,
                JSON_QUERY(SBSC.fn_GetChapterTree(c.Id, @LangId)) AS Sections
            FROM SBSC.Chapter AS c
            LEFT JOIN SBSC.ChapterLanguage AS cl
                ON cl.ChapterId = c.Id AND cl.LanguageId = @LangId
            WHERE c.ParentChapterId IS NULL 
              AND c.CertificationId = @CertificationId
            ORDER BY c.DisplayOrder
            FOR JSON PATH, ROOT('Chapters')
        ) AS NVARCHAR(MAX));
		END
	END


    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
	
		BEGIN TRY
			UPDATE [SBSC].[Chapter]
			SET 
				IsWarning = ISNULL(@IsWarning, IsWarning),
				IsVisible = ISNULL(@IsVisible, IsVisible),
				ModifiedBy = ISNULL(@ModifiedBy, ModifiedBy),
				DisplayOrder = ISNULL(@DisplayOrder, DisplayOrder),
				[Level] = ISNULL(@Level, [Level])
			WHERE Id = @ChapterId;

			-- Return the updated values
			SELECT Title, IsWarning, IsVisible, AddedDate, AddedBy, ModifiedDate, ModifiedBy, DisplayOrder
			FROM [SBSC].[Chapter]
			WHERE Id = @ChapterId;
		
		END TRY
		BEGIN CATCH

            DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @UpdateErrorState INT = ERROR_STATE()

            RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState)
        END CATCH
    END

	-- UPDATE Language operation
    ELSE IF @Action = 'UPDATELANG'
    BEGIN
	    DECLARE @DefaultUpdateLangId INT;
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultUpdateLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
            SET @LangId = @DefaultUpdateLangId;
        END

        IF @ChapterId IS NULL
            BEGIN
                RAISERROR('Chapter Id must be provided for updating language.', 16, 1);
            END
        ELSE
            BEGIN TRY
                UPDATE [SBSC].[ChapterLanguage]
                SET 
					[ChapterTitle] = ISNULL(@Title, [ChapterTitle]),
					[ChapterDescription] = ISNULL(@Description, [ChapterDescription])
				WHERE [ChapterId] = @ChapterId AND [LanguageId] = @LangId;

                SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected

				-- Return the updated values
				-- SELECT [LanguageId], [ChapterId], [ChapterTitle], [ChapterDescription]
				-- FROM [SBSC].[ChapterLanguage] 
				-- --where  [ChapterId] = 1069 AND [LanguageId] = 6
				-- WHERE [ChapterId] = @ChapterId AND [LanguageId] = @LangId;
            END TRY
        BEGIN CATCH
            THROW; -- Re-throw the error
        END CATCH
    END

    -- Add Sub sections
	ELSE IF @Action = 'CREATE_SECTION'
    BEGIN
		DECLARE @DefaultLanguageCreateSectionId INT;
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLanguageCreateSectionId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageCreateSectionId;
		END

        -- Validate that Parent Chapter exists and get its Level
        DECLARE @ParentLevel INT;
		DECLARE @ParentCertificationId INT;

        SELECT @ParentLevel = Level,
				@ParentCertificationId = CertificationId
        FROM [SBSC].[Chapter] 
        WHERE Id = @Id;

        IF @ParentLevel IS NULL
        BEGIN
            RAISERROR('Invalid Parent Chapter ID', 16, 1);
            RETURN;
        END

        BEGIN TRY
            -- Start the transaction
            BEGIN TRANSACTION;
            
            -- Handle DisplayOrder logic
            DECLARE @NewDisplayOrder INT;
            SET @NewDisplayOrder = @DisplayOrder;
            
            -- Updated DisplayOrder logic to check within the same parent section
            IF @DisplayOrder IS NULL OR EXISTS (
                SELECT 1 
                FROM SBSC.Chapter
                WHERE ParentChapterId = @Id 
                AND DisplayOrder = @DisplayOrder
            )
            BEGIN
                SELECT @NewDisplayOrder = ISNULL(MAX(DisplayOrder), 0) + 1
                FROM SBSC.Chapter
                WHERE ParentChapterId = @Id;
                SET @DisplayOrder = @NewDisplayOrder;
            END

            -- Insert the new Chapter record with ParentChapterId and Level
            INSERT INTO SBSC.Chapter 
                (Title, IsWarning, IsVisible, AddedDate, AddedBy, ModifiedBy, ModifiedDate, 
                 CertificationId, DisplayOrder, ParentChapterId, Level)
            VALUES 
                (
                    @Title,
                    ISNULL(@IsWarning, 1), 
                    ISNULL(@IsVisible, 0),
                    ISNULL(@Added_date, GETUTCDATE()), 
                    @AddedBy, 
                    @ModifiedBy, 
                    @ModifiedDate,
                    @ParentCertificationId,
                    @NewDisplayOrder,
                    @Id,                    -- Set ParentChapterId to @Id
                    @ParentLevel + 1        -- Set Level to parent's level + 1
                );

            DECLARE @NewChapterId INT = SCOPE_IDENTITY();

            DECLARE @CurrentLangId INT;
            DECLARE LanguageCursor CURSOR FOR
            SELECT Id FROM [SBSC].[Languages];
            OPEN LanguageCursor;
            FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @CurrentLangId = @LangId
                BEGIN
                    INSERT INTO [SBSC].[ChapterLanguage] (
                        [LanguageId], [ChapterId], [ChapterTitle], [ChapterDescription]
                    )
                    VALUES (
                        @CurrentLangId, 
                        @NewChapterId, 
                        @Title,
                        @Description
                    );
                END
                ELSE
                BEGIN
                    INSERT INTO [SBSC].[ChapterLanguage] (
                        [LanguageId], [ChapterId], [ChapterTitle], [ChapterDescription]
                    )
                    VALUES (
                        @CurrentLangId, 
                        @NewChapterId, 
                        NULL,
                        NULL
                    );
                END
                FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
            END
            CLOSE LanguageCursor;
            DEALLOCATE LanguageCursor;

            -- Calculate the hierarchical prefix using recursive CTE
            DECLARE @Prefix NVARCHAR(500);
            
            WITH ChapterHierarchy AS (
                -- Base case: Start with the newly created chapter
                SELECT 
                    Id,
                    ParentChapterId,
                    DisplayOrder,
                    Level,
                    CAST(DisplayOrder AS NVARCHAR(500)) AS Prefix,
                    0 AS Depth
                FROM SBSC.Chapter 
                WHERE Id = @NewChapterId
                
                UNION ALL
                
                -- Recursive case: Add parent chapters
                SELECT 
                    p.Id,
                    p.ParentChapterId,
                    p.DisplayOrder,
                    p.Level,
                    CAST(CAST(p.DisplayOrder AS NVARCHAR) + '.' + ch.Prefix AS NVARCHAR(500)),
                    ch.Depth + 1
                FROM SBSC.Chapter p
                INNER JOIN ChapterHierarchy ch ON p.Id = ch.ParentChapterId
            )
            SELECT @Prefix = Prefix
            FROM ChapterHierarchy
            WHERE ParentChapterId IS NULL  -- This will be the root chapter
            OR Id IN (  -- Or the topmost chapter we can reach
                SELECT TOP 1 Id 
                FROM ChapterHierarchy 
                ORDER BY Depth DESC
            );

            -- If no parent chain was found, use just the display order
            IF @Prefix IS NULL
                SET @Prefix = CAST(@NewDisplayOrder AS NVARCHAR(500));

            -- Commit the transaction
            COMMIT TRANSACTION;

            -- Return success message with prefix
            SELECT 
                @NewChapterId AS [Id], 
                @Title AS [ChapterTitle], 
                @Description AS [ChapterDescription],
                ISNULL(@IsWarning, 0) AS [IsWarning],
                @LangId AS [LangId],
                @NewDisplayOrder AS [DisplayOrder],
                @Id AS [ParentChapterId],
                @ParentLevel + 1 AS [Level],
                @Prefix AS [Prefix];
    
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END;
            DECLARE @ErrorMessageCreateSection NVARCHAR(4000), @ErrorSeverityCreateSection INT, @ErrorStateCreateSection INT;
            SELECT 
                @ErrorMessageCreateSection = ERROR_MESSAGE(),
                @ErrorSeverityCreateSection = ERROR_SEVERITY(),
                @ErrorStateCreateSection = ERROR_STATE();
            RAISERROR (@ErrorMessageCreateSection, @ErrorSeverityCreateSection, @ErrorStateCreateSection);
        END CATCH;
    END

	ELSE IF @Action = 'CREATE_MIGRATION'
    BEGIN
		DECLARE @DefaultLanguageCreateChapterId INT;
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLanguageCreateChapterId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageCreateChapterId;
		END

  --      -- Validate that Parent Chapter exists and get its Level
  --      DECLARE @ParentLevel INT;
		--DECLARE @ParentCertificationId INT;

  --      SELECT @ParentLevel = Level,
		--		@ParentCertificationId = CertificationId
  --      FROM [SBSC].[Chapter] 
  --      WHERE Id = @Id;

  --      IF @ParentLevel IS NULL
  --      BEGIN
  --          RAISERROR('Invalid Parent Chapter ID', 16, 1);
  --          RETURN;
  --      END

        BEGIN TRY
            -- Start the transaction
            BEGIN TRANSACTION;
            
            -- Handle DisplayOrder logic
            DECLARE @NewDisplayOrderChapter INT;
            SET @NewDisplayOrderChapter = @DisplayOrder;
            
            -- Updated DisplayOrder logic to check within the same parent section
            IF @DisplayOrder IS NULL OR EXISTS (
                SELECT 1 
                FROM SBSC.Chapter
                WHERE ParentChapterId = @Id 
                AND DisplayOrder = @DisplayOrder
            )
            BEGIN
                SELECT @NewDisplayOrderChapter = ISNULL(MAX(DisplayOrder), 0) + 1
                FROM SBSC.Chapter
                WHERE ParentChapterId = @Id;
                SET @DisplayOrder = @NewDisplayOrderChapter;
            END

            -- Insert the new Chapter record with ParentChapterId and Level
            INSERT INTO SBSC.Chapter 
                (Title, IsWarning, IsVisible, AddedDate, AddedBy, ModifiedBy, ModifiedDate, 
                 CertificationId, DisplayOrder, ParentChapterId, Level)
            VALUES 
                (
                    @Title,
                    ISNULL(@IsWarning, 1), 
                    ISNULL(@IsVisible, 0),
                    ISNULL(@Added_date, GETUTCDATE()), 
                    @AddedBy, 
                    @ModifiedBy, 
                    @ModifiedDate,
                    @CertificationId,--@ParentCertificationId,
                    @NewDisplayOrderChapter,
                    @Id,                    -- Set ParentChapterId to @Id
                    0--@ParentLevel + 1        -- Set Level to parent's level + 1
                );

            DECLARE @NewChapterIdMigration INT = SCOPE_IDENTITY();

            -- Rest of your existing code for language handling remains the same
            DECLARE @CurrentLangIdMigration INT;
            DECLARE LanguageCursor CURSOR FOR
            SELECT Id FROM [SBSC].[Languages];
            OPEN LanguageCursor;
            FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
            WHILE @@FETCH_STATUS = 0
            BEGIN
                IF @CurrentLangIdMigration = @LangId
                BEGIN
                    INSERT INTO [SBSC].[ChapterLanguage] (
                        [LanguageId], [ChapterId], [ChapterTitle], [ChapterDescription]
                    )
                    VALUES (
                        @CurrentLangId, 
                        @NewChapterIdMigration, 
                        @Title,
                        @Description
                    );
                END
                ELSE
                BEGIN
                    INSERT INTO [SBSC].[ChapterLanguage] (
                        [LanguageId], [ChapterId], [ChapterTitle], [ChapterDescription]
                    )
                    VALUES (
                        @CurrentLangId, 
                        @NewChapterIdMigration, 
                        NULL,
                        NULL
                    );
                END
                FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
            END
            CLOSE LanguageCursor;
            DEALLOCATE LanguageCursor;

            -- Commit the transaction
            COMMIT TRANSACTION;

            -- Return success message
            SELECT 
                @NewChapterIdMigration AS [Id], 
                @Title AS [ChapterTitle], 
                @Description AS [ChapterDescription],
                ISNULL(@IsWarning, 0) AS [IsWarning],
                @LangId AS [LangId],
                @NewDisplayOrderChapter AS [DisplayOrder],
                @Id AS [ParentChapterId],
                0 AS [Level]-- @ParentLevel + 1 AS [Level];
    
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
            BEGIN
                ROLLBACK TRANSACTION;
            END;
            DECLARE @ErrorMessageCreateSectionMigration NVARCHAR(4000), @ErrorSeverityCreateSectionMigration INT, @ErrorStateCreateSectionMigration INT;
            SELECT 
                @ErrorMessageCreateSectionMigration = ERROR_MESSAGE(),
                @ErrorSeverityCreateSectionMigration = ERROR_SEVERITY(),
                @ErrorStateCreateSectionMigration = ERROR_STATE();
            RAISERROR (@ErrorMessageCreateSectionMigration, @ErrorSeverityCreateSectionMigration, @ErrorStateCreateSectionMigration);
        END CATCH;
    END
   
	-- DELETE operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		DECLARE @DeletedChapterDisplayOrder INT;
		DECLARE @DeletedChapterCertificationId INT;
		DECLARE @DeletedChapterParentId INT;

		-- Get the DisplayOrder, CertificationId, and ParentChapterId of the chapter being deleted
		SELECT 
			@DeletedChapterDisplayOrder = DisplayOrder,
			@DeletedChapterCertificationId = CertificationId,
			@DeletedChapterParentId = ParentChapterId
		FROM [SBSC].[Chapter]
		WHERE Id = @Id;

		BEGIN TRANSACTION;
		BEGIN TRY
			-- Delete the chapter and its subsections
			WITH ChapterHierarchy AS (
				-- Start with the selected chapter
				SELECT Id FROM [SBSC].[Chapter]
				WHERE Id = @Id
            
				UNION ALL
            
				-- Recursively get all children
				SELECT c.Id
				FROM [SBSC].[Chapter] c
				INNER JOIN ChapterHierarchy ch ON c.ParentChapterId = ch.Id
			)
			DELETE FROM [SBSC].[Chapter]
			WHERE Id IN (SELECT Id FROM ChapterHierarchy);

			-- Update DisplayOrder based on whether it was a top-level chapter or subsection
			IF @DeletedChapterParentId IS NULL
			BEGIN
				-- Update DisplayOrder for top-level chapters
				UPDATE [SBSC].[Chapter]
				SET DisplayOrder = DisplayOrder - 1
				WHERE CertificationId = @DeletedChapterCertificationId
				AND ParentChapterId IS NULL
				AND DisplayOrder > @DeletedChapterDisplayOrder;
			END
			ELSE
			BEGIN
				-- Update DisplayOrder for subsections within the same parent
				UPDATE [SBSC].[Chapter]
				SET DisplayOrder = DisplayOrder - 1
				WHERE ParentChapterId = @DeletedChapterParentId
				AND DisplayOrder > @DeletedChapterDisplayOrder;
			END

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION;
			THROW;
		END CATCH
	END

	IF @Action = 'LIST'
	BEGIN
		DECLARE @JsonOutput NVARCHAR(MAX);
		DECLARE @DefaultLanguageId INT;
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLanguageId = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageId;
		END

		-- Validate and sanitize the sort column
		IF @SortColumn NOT IN ('ChapterId', 'ChapterTitle', 'DisplayOrder')
			SET @SortColumn = 'DisplayOrder';

		-- Validate the sort direction
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		-- Declare variables for pagination and dynamic SQL
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @SQLCount NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- Build the WHERE clause (note: we cast c.Id to NVARCHAR for text search)
		SET @WhereClause = N'
			WHERE ( @SearchValue IS NULL 
					OR CAST(c.Id AS NVARCHAR(50)) LIKE ''%'' + @SearchValue + ''%'' 
					OR cl.ChapterTitle LIKE ''%'' + @SearchValue + ''%'')
			  AND ( @CertificationId IS NULL OR c.CertificationId = @CertificationId )
			  AND ( cl.LanguageId = @LangId )
			  AND c.ParentChapterId IS NULL';

		-- Build the count query first
		SET @SQLCount = N'
			SELECT @TotalRecords_OUT = COUNT(*)
			FROM SBSC.Chapter AS c
			LEFT JOIN SBSC.ChapterLanguage AS cl 
				ON cl.ChapterId = c.Id AND cl.LanguageId = @LangId
			' + @WhereClause;

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @CertificationId INT, @LangId INT, @TotalRecords_OUT INT OUTPUT';
		EXEC sp_executesql 
			@SQLCount, 
			@ParamDefinition, 
			@SearchValue = @SearchValue, 
			@CertificationId = @CertificationId, 
			@LangId = @LangId, 
			@TotalRecords_OUT = @TotalRecords OUTPUT;

		-- Calculate total pages based on @TotalRecords
		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Build the paginated query. Notice the placement of the WHERE clause, ORDER BY, OFFSET and FETCH clauses.
		SET @SQL = N'
        SELECT @JsonOutput_OUT = (
            SELECT
                c.Id AS ChapterId,
                cl.ChapterTitle,
                cl.ChapterDescription,
                c.DisplayOrder,
                c.[Level] AS [Level],
                c.IsWarning,
                c.IsVisible,
                c.ParentChapterId,
                c.CertificationId,
                JSON_QUERY(SBSC.fn_GetChapterTree(c.Id, @LangId)) AS Sections
            FROM SBSC.Chapter AS c
            LEFT JOIN SBSC.ChapterLanguage AS cl 
                ON cl.ChapterId = c.Id AND cl.LanguageId = @LangId
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY
            FOR JSON PATH, ROOT(''Chapters'')
        );';

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @CertificationId INT, @LangId INT, @JsonOutput_OUT NVARCHAR(MAX) OUTPUT';

		EXEC sp_executesql 
        @SQL, 
        @ParamDefinition, 
        @SearchValue = @SearchValue, 
        @CertificationId = @CertificationId, 
        @LangId = @LangId,
        @JsonOutput_OUT = @JsonOutput OUTPUT;

		-- Return the JSON result
		SELECT @JsonOutput AS JsonResult;

		-- Return pagination details (existing code remains the same)
		SELECT @TotalRecords AS TotalRecords, 
			   @TotalPages AS TotalPages, 
			   @PageNumber AS CurrentPage, 
			   @PageSize AS PageSize,
			   CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			   CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END



	-- DISPLAYORDER operation
	ELSE IF @Action = 'DISPLAYORDER'
	BEGIN
		DECLARE @OldDisplayOrder INT;
		DECLARE @CertificationIdDisplayOrder INT;
		DECLARE @CurrentParentChapterId INT;

		-- Validate that Chapter exists and get its details
		IF NOT EXISTS (SELECT 1 FROM [SBSC].[Chapter] WHERE Id = @Id)
		BEGIN
			RAISERROR('Invalid Chapter ID', 16, 1);
			RETURN;
		END

		-- Get the current DisplayOrder, CertificationId and ParentChapterId for the given Chapter
		SELECT 
			@OldDisplayOrder = DisplayOrder,
			@CertificationIdDisplayOrder = CertificationId,
			@CurrentParentChapterId = ParentChapterId
		FROM [SBSC].[Chapter]
		WHERE Id = @Id;

		IF @DisplayOrder = @OldDisplayOrder
		BEGIN
			RETURN; -- No update needed
		END

		BEGIN TRANSACTION;
		BEGIN TRY
			-- Handle top-level chapters (ParentChapterId is NULL)
			IF @CurrentParentChapterId IS NULL
			BEGIN
				-- If DisplayOrder is increasing
				IF @DisplayOrder > @OldDisplayOrder
				BEGIN
					UPDATE [SBSC].[Chapter]
					SET DisplayOrder = DisplayOrder - 1
					WHERE CertificationId = @CertificationIdDisplayOrder
					AND ParentChapterId IS NULL
					AND DisplayOrder > @OldDisplayOrder 
					AND DisplayOrder <= @DisplayOrder
					AND Id != @Id;
				END
				-- If DisplayOrder is decreasing
				ELSE IF @DisplayOrder < @OldDisplayOrder
				BEGIN
					UPDATE [SBSC].[Chapter]
					SET DisplayOrder = DisplayOrder + 1
					WHERE CertificationId = @CertificationIdDisplayOrder
					AND ParentChapterId IS NULL
					AND DisplayOrder >= @DisplayOrder 
					AND DisplayOrder < @OldDisplayOrder
					AND Id != @Id;
				END
			END
			-- Handle subsections (ParentChapterId is not NULL)
			ELSE
			BEGIN
				-- If DisplayOrder is increasing
				IF @DisplayOrder > @OldDisplayOrder
				BEGIN
					UPDATE [SBSC].[Chapter]
					SET DisplayOrder = DisplayOrder - 1
					WHERE ParentChapterId = @CurrentParentChapterId
					AND DisplayOrder > @OldDisplayOrder 
					AND DisplayOrder <= @DisplayOrder
					AND Id != @Id;
				END
				-- If DisplayOrder is decreasing
				ELSE IF @DisplayOrder < @OldDisplayOrder
				BEGIN
					UPDATE [SBSC].[Chapter]
					SET DisplayOrder = DisplayOrder + 1
					WHERE ParentChapterId = @CurrentParentChapterId
					AND DisplayOrder >= @DisplayOrder 
					AND DisplayOrder < @OldDisplayOrder
					AND Id != @Id;
				END
			END

			-- Update the dragged item's DisplayOrder to the new value
			UPDATE [SBSC].[Chapter]
			SET DisplayOrder = @DisplayOrder
			WHERE Id = @Id;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION;
			THROW;
		END CATCH
	END
END
GO