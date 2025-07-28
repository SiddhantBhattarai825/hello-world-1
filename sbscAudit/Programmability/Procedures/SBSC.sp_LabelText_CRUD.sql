SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_LabelText_CRUD]
    @Action NVARCHAR(10),
    @Id INT = NULL, 
    @Code NVARCHAR(50) = NULL, 
    @LabelTitle NVARCHAR(50) = NULL,
    @LabelDescription NVARCHAR(500) = NULL,
    @PageCode NVARCHAR(MAX) = NULL,
	@LangId INT = NULL,
    @Section NVARCHAR(50) = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
	@ParamDefinition NVARCHAR(MAX) = NULL,
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

    -- CREATE action: Insert a new record into LabelTexts
    IF @Action = 'CREATE'
    BEGIN
        -- Check if required parameters are provided
        IF @Code IS NULL OR @LabelTitle IS NULL OR @PageCode IS NULL 
        BEGIN
            RAISERROR('Missing required parameters for CREATE operation. Please enter Code, LabelTitle, and PageCode.', 16, 1);
            RETURN;
        END

        -- Check if a record with the same Code already exists
        IF EXISTS (SELECT 1 FROM SBSC.LabelTexts WHERE Code = @Code)
        BEGIN
            RAISERROR('A record with the provided Code already exists.', 16, 1);
            RETURN;
        END

        -- Start the transaction
        BEGIN TRY
            -- Insert the new record into LabelTexts table
            INSERT INTO SBSC.LabelTexts (Code, LabelTitle, LabelDescription, PageCode, Section)
            VALUES (@Code, @LabelTitle, @LabelDescription, @PageCode, @Section);

            -- Get the newly inserted Id
            DECLARE @NewId INT;
            SET @NewId = SCOPE_IDENTITY();			
            SELECT @NewId AS Id, @Code AS Code, @LabelTitle AS LabelTitle, @LabelDescription AS LabelDescription, @PageCode AS PageCode, @Section AS Section;  -- Return the ID of the newly created record

        END TRY
        BEGIN CATCH
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

   -- READ action: Select a single record by @Id, @PageCode, and @LangId
IF @Action = 'READ'
BEGIN
    -- Fetch by Id
    IF @Id IS NOT NULL
    BEGIN
        SELECT 
            LT.Id, 
            LT.Code, 
            LT.LabelTitle, 
            LT.LabelDescription, 
            LT.PageCode, 
            LT.Section,
            LTT.LanguageId,
            LTT.TranslatedTitle,
            LTT.TranslatedDescription
        FROM SBSC.LabelTexts LT
        LEFT JOIN SBSC.LabelTextTranslations LTT 
            ON LT.Id = LTT.LabelTextId
        WHERE LT.Id = @Id;
    END
    -- Fetch by PageCode and LangId
    ELSE IF @PageCode IS NOT NULL AND @LangId IS NOT NULL
    BEGIN
        SELECT 
            LT.Id, 
            LT.Code, 
            LT.LabelTitle, 
            LT.LabelDescription, 
            LT.PageCode, 
            LT.Section,
            ISNULL(LTT.LanguageId, @LangId) AS LanguageId,
            ISNULL(LTT.TranslatedTitle, LT.LabelTitle) AS TranslatedTitle,
            ISNULL(LTT.TranslatedDescription, LT.LabelDescription) AS TranslatedDescription
        FROM SBSC.LabelTexts LT
        LEFT JOIN SBSC.LabelTextTranslations LTT 
            ON LT.Id = LTT.LabelTextId AND LTT.LanguageId = @LangId
        WHERE LT.PageCode IN (
			SELECT value 
			FROM STRING_SPLIT(@PageCode, ','));
    END
    -- Fetch by PageCode (all translations)
    ELSE IF @PageCode IS NOT NULL
    BEGIN
        SELECT 
            LT.Id, 
            LT.Code, 
            LT.LabelTitle, 
            LT.LabelDescription, 
            LT.PageCode, 
            LT.Section,
            LTT.LanguageId,
            LTT.TranslatedTitle,
            LTT.TranslatedDescription
        FROM SBSC.LabelTexts LT
        LEFT JOIN SBSC.LabelTextTranslations LTT 
            ON LT.Id = LTT.LabelTextId
        WHERE LT.PageCode IN (
			SELECT value 
			FROM STRING_SPLIT(@PageCode, ','));
    END
    -- Fetch all label texts with translations
    ELSE
    BEGIN
        SELECT 
            LT.Id, 
            LT.Code, 
            LT.LabelTitle, 
            LT.LabelDescription, 
            LT.PageCode, 
            LT.Section,
            LTT.LanguageId,
            LTT.TranslatedTitle,
            LTT.TranslatedDescription
        FROM SBSC.LabelTexts LT
        LEFT JOIN SBSC.LabelTextTranslations LTT 
            ON LT.Id = LTT.LabelTextId;
    END
    RETURN;
END




    -- UPDATE action: Update an existing record by @Id
    IF @Action = 'UPDATE'
    BEGIN
        IF @Id IS NULL
        BEGIN
            RAISERROR('Missing @Id parameter for UPDATE operation', 16, 1);
            RETURN;
        END
		BEGIN TRY

        UPDATE SBSC.LabelTexts
        SET 
            Code = ISNULL(@Code, Code),
            LabelTitle = ISNULL(@LabelTitle, LabelTitle),
            LabelDescription = ISNULL(@LabelDescription, LabelDescription),
            PageCode = ISNULL(@PageCode, PageCode),
            Section = ISNULL(@Section, Section)
        WHERE Id = @Id;

		-- Select the updated record to return it
			SELECT * FROM SBSC.LabelTexts WHERE Id = @Id;
		END TRY
		BEGIN CATCH        
			DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY();
			DECLARE @UpdateErrorState INT = ERROR_STATE();

			RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState);
		END CATCH
    END

    -- DELETE action: Delete a record by @Id
    IF @Action = 'DELETE'
    BEGIN
		IF EXISTS(SELECT 1 FROM SBSC.LabelTexts WHERE Id = @Id)
		BEGIN TRY
			DELETE FROM SBSC.LabelTexts
			WHERE Id = @Id;
			-- Return the deleted Menu ID
			SELECT @Id AS Id;
		END TRY
		 BEGIN CATCH
            DECLARE @DeleteErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @DeleteErrorSeverity INT = ERROR_SEVERITY();
            DECLARE @DeleteErrorState INT = ERROR_STATE();

            RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState);
        END CATCH
    END

    -- LIST action: Select records with pagination, search, sorting, and group by pageCode
IF @Action = 'LIST'
BEGIN
    -- Validate sort column and direction
    IF @SortColumn NOT IN ('Id', 'Code', 'LabelTitle', 'LabelDescription', 'PageCode', 'Section')
        SET @SortColumn = 'Id';
    IF @SortDirection NOT IN ('ASC', 'DESC')
        SET @SortDirection = 'ASC';

    -- Set up pagination and WHERE clause
    DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
    DECLARE @WhereClause NVARCHAR(MAX) = N'WHERE (@SearchValue IS NULL 
        OR Code LIKE ''%'' + @SearchValue + ''%''
        OR LabelTitle LIKE ''%'' + @SearchValue + ''%''
        OR LabelDescription LIKE ''%'' + @SearchValue + ''%''
        OR PageCode LIKE ''%'' + @SearchValue + ''%''
        OR Section LIKE ''%'' + @SearchValue + ''%'')';

    -- Count total records for pagination
    DECLARE @TotalRecords INT;
    DECLARE @TotalPages INT;
    DECLARE @SQL NVARCHAR(MAX) = N'
        SELECT @TotalRecords = COUNT(DISTINCT Id)
        FROM SBSC.LabelTexts ' + @WhereClause;
    
    EXEC sp_executesql @SQL, 
        N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT', 
        @SearchValue, @TotalRecords OUTPUT;

    -- Calculate total pages
    SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

    -- Return both JSON data and pagination info in a single result set
    SET @SQL = N'
    SELECT 
        (SELECT DISTINCT t1.PageCode,
            (
                SELECT t2.Id, t2.Code, t2.LabelTitle, t2.LabelDescription, 
                       t2.Section
                FROM SBSC.LabelTexts t2
                WHERE t2.PageCode = t1.PageCode
                AND ' + SUBSTRING(@WhereClause, 7, LEN(@WhereClause)) + '
                ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
                OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS
                FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY
                FOR JSON PATH
            ) AS LabelTexts
            FROM SBSC.LabelTexts t1
            ' + @WhereClause + '
            GROUP BY t1.PageCode
            FOR JSON PATH
        ) AS Data,
        @TotalRecords AS TotalRecords,
        @TotalPages AS TotalPages,
        @PageNumber AS CurrentPage,
        @PageSize AS PageSize';

    -- Execute the query
    EXEC sp_executesql @SQL,
        N'@SearchValue NVARCHAR(100), @TotalRecords INT, @TotalPages INT, @PageNumber INT, @PageSize INT',
        @SearchValue, @TotalRecords, @TotalPages, @PageNumber, @PageSize;
END;





END;
GO