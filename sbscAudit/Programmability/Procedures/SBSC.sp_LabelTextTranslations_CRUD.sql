SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_LabelTextTranslations_CRUD]
    @Action NVARCHAR(10),
    @Id INT = NULL, 
    @LabelTextId INT = NULL,
    @LanguageId INT = NULL,
    @TranslatedTitle NVARCHAR(255) = NULL,
    @TranslatedDescription NVARCHAR(MAX) = NULL,
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
        RAISERROR('Invalid Action parameter. Use CREATE, READ, UPDATE, DELETE, or LIST.', 16, 1);
        RETURN;
    END

    -- CREATE action: Insert a new record into LabelTextTranslations
    IF @Action = 'CREATE'
    BEGIN
        IF @LabelTextId IS NULL OR @LanguageId IS NULL 
        BEGIN
            RAISERROR('Missing required parameters for CREATE operation. Please provide LabelTextId, LanguageId.', 16, 1);
            RETURN;
        END

        BEGIN TRY
            INSERT INTO SBSC.LabelTextTranslations (LabelTextId, LanguageId, TranslatedTitle, TranslatedDescription)
            VALUES (@LabelTextId, @LanguageId, @TranslatedTitle, @TranslatedDescription);

            -- Get the newly inserted Id
            DECLARE @NewId INT;
            SET @NewId = SCOPE_IDENTITY();
            SELECT @NewId AS Id, @LabelTextId AS LabelTextId, @LanguageId AS LanguageId, @TranslatedTitle AS TranslatedTitle, @TranslatedDescription AS TranslatedDescription;
        END TRY
        BEGIN CATCH
            DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
            SELECT 
                @ErrorMessage = ERROR_MESSAGE(),
                @ErrorSeverity = ERROR_SEVERITY(),
                @ErrorState = ERROR_STATE();

            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        END CATCH;
    END

    -- READ action: Select a single record by @Id or fetch all records
    IF @Action = 'READ'
    BEGIN
        IF @Id IS NULL
        BEGIN
            SELECT * FROM SBSC.LabelTextTranslations;  -- Select all if Id is not provided
        END
        ELSE
        BEGIN
            SELECT * FROM SBSC.LabelTextTranslations WHERE Id = @Id;
        END
        RETURN;
    END

    -- UPDATE action: Update an existing record by @Id
IF @Action = 'UPDATE'
BEGIN
    -- Validate required parameters
    IF @Id IS NULL
    BEGIN
        RAISERROR('Missing Id parameter for UPDATE operation.', 16, 1);
        RETURN;
    END

    BEGIN TRY
        -- Update the translation entry safely
        UPDATE SBSC.LabelTextTranslations
        SET 
            TranslatedTitle = ISNULL(@TranslatedTitle, TranslatedTitle),
            TranslatedDescription = ISNULL(@TranslatedDescription, TranslatedDescription)
        WHERE LabelTextId = @Id AND LanguageId = @LanguageId;

        -- If no row was updated, handle it
        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR('No record found to update with the given Id and LanguageId.', 16, 1);
        END

        -- Return the updated record
        SELECT * 
        FROM SBSC.LabelTextTranslations 
        WHERE LabelTextId = @Id AND LanguageId = @LanguageId;
    END TRY
    BEGIN CATCH
        DECLARE @UpdateErrorMessage NVARCHAR(4000), @UpdateErrorSeverity INT, @UpdateErrorState INT;
        SELECT 
            @UpdateErrorMessage = ERROR_MESSAGE(),
            @UpdateErrorSeverity = ERROR_SEVERITY(),
            @UpdateErrorState = ERROR_STATE();

        RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState);
    END CATCH;
END


    -- DELETE action: Delete a record by @Id
    IF @Action = 'DELETE'
    BEGIN
        IF @Id IS NULL
        BEGIN
            RAISERROR('Missing Id parameter for DELETE operation.', 16, 1);
            RETURN;
        END
		IF EXISTS(SELECT 1 FROM SBSC.LabelTextTranslations WHERE Id = @Id)
        BEGIN TRY
			
            DELETE FROM SBSC.LabelTextTranslations WHERE Id = @Id;
            SELECT @Id AS Id;
        END TRY
        BEGIN CATCH
            DECLARE @DeleteErrorMessage NVARCHAR(4000), @DeleteErrorSeverity INT, @DeleteErrorState INT;
            SELECT 
                @DeleteErrorMessage = ERROR_MESSAGE(),
                @DeleteErrorSeverity = ERROR_SEVERITY(),
                @DeleteErrorState = ERROR_STATE();

            RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState);
        END CATCH;
    END

    -- LIST action: Select records with pagination, search, and sorting
    IF @Action = 'LIST'
    BEGIN
        IF @SortColumn NOT IN ('Id', 'LabelTextId', 'LanguageId', 'TranslatedTitle', 'TranslatedDescription')
            SET @SortColumn = 'Id';

        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'ASC';

        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @WhereClause NVARCHAR(MAX) = N'';
        DECLARE @ParamDefinition NVARCHAR(500);
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        DECLARE @TotalRecords INT = 0;
        DECLARE @TotalPages INT;

        -- Filter based on the search value
        SET @WhereClause = N'
            WHERE (@SearchValue IS NULL
			OR LabelTextId LIKE ''%'' + @SearchValue + ''%''
            OR TranslatedTitle LIKE ''%'' + @SearchValue + ''%''
            OR LanguageId LIKE ''%'' + @SearchValue + ''%'')';

        -- Get total record count
        SET @SQL = N'SELECT @TotalRecords = COUNT(Id) FROM SBSC.LabelTextTranslations ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT';
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'SELECT Id, LabelTextId, LanguageId, TranslatedTitle, TranslatedDescription
                     FROM SBSC.LabelTextTranslations ' + @WhereClause + '
                     ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
                     OFFSET @Offset ROWS 
                     FETCH NEXT @PageSize ROWS ONLY';

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @Offset INT, @PageSize INT';
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @Offset, @PageSize;

        -- Return pagination details
        SELECT @TotalRecords AS TotalRecords, 
               @TotalPages AS TotalPages, 
               @PageNumber AS CurrentPage, 
               @PageSize AS PageSize,
               CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
               CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
    END
END;
GO