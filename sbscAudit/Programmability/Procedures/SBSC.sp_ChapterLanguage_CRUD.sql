SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_ChapterLanguage_CRUD]
    @Action NVARCHAR(20),
    @Id INT = NULL, 
    @LangId INT = NULL,
    @ChapterId INT = NULL,
    @Title NVARCHAR(500) = NULL,
    @Description NVARCHAR(MAX) = NULL,
    @ChapterTitle NVARCHAR(500) = NULL,

    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'

AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('READ', 'UPDATE', 'DELETE', 'LIST')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, or LIST', 16, 1);
        RETURN;
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        IF @ChapterId IS NULL AND @LangId IS NULL
        BEGIN
            SELECT * FROM [SBSC].[ChapterLanguage];
        END
        ELSE
        BEGIN
            IF @ChapterId IS NOT NULL AND @LangId IS NOT NULL
            BEGIN
                -- Return filtered results by ChapterTitle and LangId
                SELECT *
                FROM [SBSC].[ChapterLanguage]
                WHERE [ChapterId] = @ChapterId AND [LanguageId] = @LangId;
            END
            ELSE
            BEGIN
                -- If one of the parameters is missing, handle as an error or default case
                RAISERROR('ChapterId and LanguageId must both be provided for filtering.', 16, 1);
            END
        END
    END

    -- --UPDATE operation
    --ELSE IF @Action = 'UPDATE'
    --BEGIN
    --    -- Check if any records were provided
    --    IF NOT EXISTS (SELECT 1 FROM @Translations)
    --    BEGIN
    --        RAISERROR('No records provided for UPDATE operation', 16, 1);
    --        RETURN;
    --    END

    --    BEGIN TRY
    --        -- Update operation
    --        UPDATE ETL
    --        SET 
    --            ETL.Title = T.Title,
    --            ETL.Description = T.Description
    --        FROM [SBSC].[ChapterLanguage] ETL
    --        INNER JOIN @Translations T ON ETL.ChapterId = T.ChapterId AND ETL.LangId = T.LangId;

    --        SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
    --    END TRY
    --    BEGIN CATCH
    --        THROW; -- Re-throw the error
    --    END CATCH
    --END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        DELETE FROM [SBSC].[ChapterLanguage]
        WHERE [Id] = @Id;

        SELECT @@ROWCOUNT AS RowsAffected;
    END

    -- LIST operation
    ELSE IF @Action = 'LIST'
    BEGIN
        IF @LangId IS NULL
        BEGIN
            RAISERROR('Language Id is missing.', 16, 1);
            RETURN;
        END

        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('ChapterTitle', 'ChapterDescription', 'LanguageId')
            SET @SortColumn = 'ChapterTitle';  -- Set default sort column to 'Title'

        -- Validate the sort direction
        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'ASC';

        -- Declare variables for pagination
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @WhereClause NVARCHAR(MAX);
        DECLARE @ParamDefinition NVARCHAR(500);
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        DECLARE @TotalRecords INT = 0;  -- Initialize the total records variable
        DECLARE @TotalPages INT;

        -- Define the WHERE clause for filtering by ChapterTitle and LangId
        SET @WhereClause = N'
            WHERE LanguageId = @LangId
            AND (@SearchValue IS NULL
            OR ChapterTitle LIKE ''%'' + @SearchValue + ''%''
            OR ChapterDescription LIKE ''%'' + @SearchValue + ''%''
            OR CAST(LanguageId AS NVARCHAR) LIKE ''%'' + @SearchValue + ''%'')';

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(*)
            FROM [SBSC].[vw_ChapterDetails]
            ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @LangId INT, @TotalRecords INT OUTPUT'; 
    
        -- Execute the total count query and assign the result to @TotalRecords
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @TotalRecords OUTPUT;


        -- Calculate total pages based on @TotalRecords
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'
            SELECT *
            FROM [SBSC].[vw_ChapterDetails]
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

        -- Execute the paginated query
        EXEC sp_executesql @SQL, N'@SearchValue NVARCHAR(100), @LangId INT', @SearchValue, @LangId;

        -- Return pagination details
        SELECT @TotalRecords AS TotalRecords, 
               @TotalPages AS TotalPages, 
               @PageNumber AS CurrentPage, 
               @PageSize AS PageSize,
               CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
               CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
    END
END
GO