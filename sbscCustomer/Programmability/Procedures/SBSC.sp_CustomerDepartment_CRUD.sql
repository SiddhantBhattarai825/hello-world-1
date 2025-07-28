SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_CustomerDepartment_CRUD]
    @Action NVARCHAR(10),                    
    @Id INT = NULL,                           
    @CustomerId INT = NULL,                   
    @DepartmentName NVARCHAR(500) = NULL,     
    @PageNumber INT = 1,                      
    @PageSize INT = 10,                       
    @SearchValue NVARCHAR(100) = NULL,     
	@Remarks NVARCHAR(MAX) = NULL,
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

    -- CREATE operation: Add a new department for a customer
    IF @Action = 'CREATE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            INSERT INTO [SBSC].[Customer_Department] (CustomerId, DepartmentName, Remarks)
            VALUES (@CustomerId, @DepartmentName, @Remarks);

            COMMIT TRANSACTION;

            -- Return the newly created department ID and details, including address (if needed)
            SELECT SCOPE_IDENTITY() AS NewDepartmentId, @CustomerId AS CustomerId, 
                   @DepartmentName AS DepartmentName, @Remarks AS Remarks
            FROM [SBSC].[Customer_Department]
            WHERE Id = SCOPE_IDENTITY();
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            DECLARE @CatchErrorMessage NVARCHAR(4000);
            DECLARE @CatchErrorSeverity INT;
            DECLARE @CatchErrorState INT;

            SET @CatchErrorMessage = ERROR_MESSAGE();
            SET @CatchErrorSeverity = ERROR_SEVERITY();
            SET @CatchErrorState = ERROR_STATE();

			RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState)
        END CATCH;
    END

    -- READ operation: Get details of a specific department by Id
    ELSE IF @Action = 'READ'
    BEGIN
        SELECT *
        FROM [SBSC].[Customer_Department]
        WHERE Id = @Id;
    END

    -- UPDATE operation: Update department details
    ELSE IF @Action = 'UPDATE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            UPDATE [SBSC].[Customer_Department]
            SET DepartmentName = ISNULL(@DepartmentName, DepartmentName),
			Remarks = ISNULL(@Remarks, Remarks)
            WHERE Id = @Id;

            COMMIT TRANSACTION;

            -- Return updated department details, including address (if needed)
            SELECT Id AS DepartmentId, CustomerId, DepartmentName, Remarks
            FROM [SBSC].[Customer_Department]
            WHERE Id = @Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            DECLARE @CatchErrorMessageUpdate NVARCHAR(4000);
            DECLARE @CatchErrorSeverityUpdate INT;
            DECLARE @CatchErrorStateUpdate INT;

            SET @CatchErrorMessage = ERROR_MESSAGE();
            SET @CatchErrorSeverity = ERROR_SEVERITY();
            SET @CatchErrorState = ERROR_STATE();

            RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState);
        END CATCH;
    END

    -- DELETE operation: Remove a department by Id
    ELSE IF @Action = 'DELETE'
    BEGIN
			DECLARE @Exists INT;
			SELECT @Exists = COUNT(*)
			FROM SBSC.Customer_Department
			WHERE Id = @Id;

			IF @Exists = 0
			BEGIN
				RAISERROR('Customer Department with Id %d does not exist.', 16, 1, @Id);
				RETURN; -- Exit the procedure if the auditor does not exist
			END	
        BEGIN TRY
            BEGIN TRANSACTION;

            DELETE FROM [SBSC].[Customer_Department]
            WHERE Id = @Id;

            COMMIT TRANSACTION;

            -- Return success message
			SELECT @Id AS Id;
            SELECT 'Department deleted successfully' AS Message;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;

            DECLARE @CatchErrorMessageDelete NVARCHAR(4000);
            DECLARE @CatchErrorSeverityDelete INT;
            DECLARE @CatchErrorStateDelete INT;

            SET @CatchErrorMessage = ERROR_MESSAGE();
            SET @CatchErrorSeverity = ERROR_SEVERITY();
            SET @CatchErrorState = ERROR_STATE();

            RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState);
        END CATCH;
    END

    -- LIST operation: Retrieve departments filtered by CustomerId with pagination, search, and sorting
    ELSE IF @Action = 'LIST'
    BEGIN
        IF @SortColumn NOT IN ('Id', 'CustomerId', 'DepartmentName')
            SET @SortColumn = 'Id';

        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'ASC';

        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        DECLARE @TotalRecords INT = 0;
        DECLARE @TotalPages INT;
        DECLARE @ListSQL NVARCHAR(MAX);
        DECLARE @WhereClause NVARCHAR(MAX) = N'WHERE 1 = 1';  -- Always true to simplify appending conditions

        -- Add search and filter conditions
        IF @SearchValue IS NOT NULL
            SET @WhereClause = @WhereClause + N'
                AND (DepartmentName LIKE ''%'' + @SearchValue + ''%'')';

        IF @CustomerId IS NOT NULL
            SET @WhereClause = @WhereClause + N' AND CustomerId = @CustomerId';

        -- Count total records for pagination
        SET @ListSQL = N'
            SELECT @TotalRecords = COUNT(Id)
            FROM [SBSC].[Customer_Department]
            ' + @WhereClause;

        EXEC sp_executesql @ListSQL, N'@SearchValue NVARCHAR(100), @CustomerId INT, @TotalRecords INT OUTPUT', 
            @SearchValue, @CustomerId, @TotalRecords OUTPUT;

        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated and sorted data with Address
        SET @ListSQL = N'
            SELECT *
            FROM [SBSC].[Customer_Department]
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET @Offset ROWS 
            FETCH NEXT @PageSize ROWS ONLY';

        EXEC sp_executesql @ListSQL, N'@SearchValue NVARCHAR(100), @CustomerId INT, @Offset INT, @PageSize INT', 
            @SearchValue, @CustomerId, @Offset, @PageSize;

        -- Return pagination metadata
        SELECT @TotalRecords AS TotalRecords, @TotalPages AS TotalPages;
    END
END
GO