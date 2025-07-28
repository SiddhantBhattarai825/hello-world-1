SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_SubMenu_Crud]
    @Action NVARCHAR(6),
    @Id INT = NULL,
    @MenuId INT = NULL,
    @Code NVARCHAR(50) = NULL,
    @PageType NVARCHAR(50) = 'content', -- Default value as defined in the table
    @LanguageCode NVARCHAR(10) = NULL,
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

    -- CREATE operation
    IF @Action = 'CREATE'
    BEGIN
        BEGIN TRY
            -- Ensure PageType is set to 'content' if NULL or empty string is passed
            INSERT INTO SBSC.SubMenus(MenuId, Code, PageType, LanguageCode)
            VALUES (@MenuId, @Code, ISNULL(NULLIF(@PageType, ''), 'content'), @LanguageCode);
        
            -- Capture the newly inserted SubMenu ID
            DECLARE @NewSubMenuId INT;
            SET @NewSubMenuId = SCOPE_IDENTITY();

            -- Return the new SubMenu ID    
            SELECT @NewSubMenuId AS Id, @MenuId AS MenuId, @Code AS Code, ISNULL(NULLIF(@PageType, ''), 'content') AS PageType, @LanguageCode AS LanguageCode;
        END TRY
        BEGIN CATCH        
            DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
            DECLARE @ErrorState INT = ERROR_STATE();

            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        END CATCH
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        SELECT Id, MenuId, Code, PageType, LanguageCode
        FROM SBSC.SubMenus
        WHERE Id = @Id;
    END

    -- LIST operation
    ELSE IF @Action = 'LIST'
    BEGIN
        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('Id', 'MenuId', 'Code', 'PageType', 'LanguageCode')
            SET @SortColumn = 'Id';

        -- Validate the sort direction
        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'ASC';

        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @WhereClause NVARCHAR(MAX);
        DECLARE @ParamDefinition NVARCHAR(500);
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        DECLARE @TotalRecords INT = 0;  
        DECLARE @TotalPages INT;

        -- Define the WHERE clause for search filtering
        SET @WhereClause = N'
            WHERE (@SearchValue IS NULL
            OR Code LIKE ''%'' + @SearchValue + ''%''
            OR LanguageCode LIKE ''%'' + @SearchValue + ''%'')';

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(Id)
            FROM SBSC.SubMenus
            ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT'; 
    
        -- Execute the total count query and assign the result to @TotalRecords
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

        -- Calculate total pages based on @TotalRecords
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'
            SELECT Id, MenuId, Code, PageType, LanguageCode
            FROM SBSC.SubMenus
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET @Offset ROWS 
            FETCH NEXT @PageSize ROWS ONLY';
        
        -- Execute the paginated query
        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @Offset INT, @PageSize INT, @TotalRecords INT OUTPUT'; 
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @Offset, @PageSize, @TotalRecords OUTPUT;

        -- Return pagination details
        SELECT @TotalRecords AS TotalRecords, 
               @TotalPages AS TotalPages, 
               @PageNumber AS CurrentPage, 
               @PageSize AS PageSize,
               CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
    END

    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        BEGIN TRY
            -- Ensure PageType gets its default value 'content' if NULL or empty string is passed
            UPDATE SBSC.SubMenus
            SET MenuId = ISNULL(@MenuId, MenuId),
                Code = ISNULL(@Code, Code),
                PageType = ISNULL(NULLIF(@PageType, ''), 'content'), -- Use default if PageType is NULL or empty
                LanguageCode = ISNULL(@LanguageCode, LanguageCode)
            WHERE Id = @Id;

            -- Select the updated record to return it
            SELECT * FROM SBSC.SubMenus WHERE Id = @Id;
        END TRY
        BEGIN CATCH        
            DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
            DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY();
            DECLARE @UpdateErrorState INT = ERROR_STATE();

            RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState);
        END CATCH
    END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        IF EXISTS(SELECT 1 FROM SBSC.Menus WHERE Id = @Id)
    BEGIN TRY
        -- Delete all submenus associated with the menu
        DELETE FROM SBSC.SubMenus WHERE MenuId = @Id;

        -- Delete the menu
        DELETE FROM SBSC.Menu WHERE Id = @Id;

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
END;
GO