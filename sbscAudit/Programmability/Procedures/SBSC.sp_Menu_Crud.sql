SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_Menu_Crud]
    @Action NVARCHAR(6),
    @Id INT = NULL,
    @ParentMenuId INT = NULL,
    @LabelTextId INT = NULL,
    @Url NVARCHAR(50) = NULL,
    @IsActive BIT = NULL,
    @MenuOrder INT = NULL,

    @OrderIndex INT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'OrderIndex',
    @SortDirection NVARCHAR(4) = 'ASC'

AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATE_COLUMN')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, or UPDATE_COLUMN', 16, 1);
        RETURN;
    END

    -- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		BEGIN TRY
			-- Check if ParentMenuId exists if it's not NULL
			IF @ParentMenuId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM SBSC.Menu WHERE Id = @ParentMenuId)
			BEGIN
				RAISERROR('ParentMenuId does not exist in the Menu table.', 16, 1);
				RETURN;
			END

			-- Check if LabelTextId exists if it's not NULL
			IF @LabelTextId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM SBSC.LabelTexts WHERE Id = @LabelTextId)
			BEGIN
				RAISERROR('LabelTextId does not exist in the Menu table.', 16, 1);
				RETURN;
			END

			-- Insert into Menu table
			INSERT INTO SBSC.Menu(ParentMenuId, LabelTextId, [Url], IsActive, MenuOrder)
			VALUES (@ParentMenuId, @LabelTextId, @Url, ISNULL(@IsActive, 1), ISNULL(@MenuOrder, 0));

			-- Capture the newly inserted Menu ID
			DECLARE @NewMenuId INT;
			SET @NewMenuId = SCOPE_IDENTITY();

			-- Return the new Menu ID    
			SELECT @NewMenuId AS Id, @ParentMenuId AS ParentMenuId, @LabelTextId AS LabelTextId, @Url AS [Url], @IsActive AS IsActive, @MenuOrder AS MenuOrder;
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
        SELECT Id, ParentMenuId, LabelTextId, [Url], IsActive, MenuOrder
        FROM SBSC.Menu
        WHERE Id = @Id;
    END

    -- LIST operation
    ELSE IF @Action = 'LIST'
    BEGIN
        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('Id', 'ParentMenuId', 'LabelTextId', 'Url')
            SET @SortColumn = 'ParentMenuId';

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
            OR Id LIKE ''%'' + @SearchValue + ''%''
            OR ParentMenuId LIKE ''%'' + @SearchValue + ''%''
            OR Url LIKE ''%'' + @SearchValue + ''%''
            OR LabelTextId LIKE ''%'' + @SearchValue + ''%'')';

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(Id)
            FROM SBSC.Menu
            ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT'; 
    
        -- Execute the total count query and assign the result to @TotalRecords
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

        -- Calculate total pages based on @TotalRecords
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'
            SELECT Id, ParentMenuId, LabelTextId, Url, IsActive, MenuOrder
            FROM SBSC.Menu
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
            -- Update Menu table
            UPDATE SBSC.Menu
            SET ParentMenuId = ISNULL(@ParentMenuId, ParentMenuId),  -- Preserve existing value if NULL
                LabelTextId = ISNULL(@LabelTextId, LabelTextId),
                Url = ISNULL(@Url, [Url]),
                IsActive = ISNULL(@IsActive, IsActive),
                MenuOrder = ISNULL(@MenuOrder, MenuOrder)
            WHERE Id = @Id;

            -- Select the updated record to return it
            SELECT * FROM SBSC.Menu WHERE Id = @Id;
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
        IF EXISTS(SELECT 1 FROM SBSC.Menu WHERE Id = @Id)
        BEGIN TRY
            -- Delete from Menu table
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