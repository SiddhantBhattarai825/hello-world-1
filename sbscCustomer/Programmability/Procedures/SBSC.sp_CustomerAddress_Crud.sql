SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_CustomerAddress_Crud]
    @Action NVARCHAR(6),
    @Id INT = NULL,
    @CustomerId INT = NULL,
    @PlaceName NVARCHAR(500) = NULL,
    @StreetAddress NVARCHAR(500) = NULL,
    @PostalCode NVARCHAR(20) = NULL,
    @City NVARCHAR(100) = NULL,
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
            BEGIN TRANSACTION;

            -- Insert a new customer address
            INSERT INTO SBSC.Customer_Address (CustomerId, PlaceName, StreetAddress, PostalCode, City)
            VALUES (@CustomerId, @PlaceName, @StreetAddress, @PostalCode, @City);

            COMMIT TRANSACTION;

            -- Return the new address details
            SELECT SCOPE_IDENTITY() AS Id, @CustomerId AS CustomerId, @PlaceName AS PlaceName, 
                   @StreetAddress AS StreetAddress, @PostalCode AS PostalCode, @City AS City;
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

            RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState);
        END CATCH;
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        SELECT 
            Id, 
            CustomerId, 
            PlaceName, 
            StreetAddress, 
            PostalCode, 
            City
        FROM SBSC.Customer_Address
        WHERE (@Id IS NULL OR Id = @Id)
          AND (@CustomerId IS NULL OR CustomerId = @CustomerId);
    END

    -- LIST operation
	ELSE IF @Action = 'LIST'
	BEGIN
		IF @SortColumn NOT IN ('Id', 'CustomerId', 'PlaceName', 'StreetAddress', 'PostalCode', 'City')
			SET @SortColumn = 'City';

		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		DECLARE @ListSQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX) = N'';
		DECLARE @ListParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- WHERE clause for search filtering with CustomerId filtering
		SET @WhereClause = N'WHERE 1 = 1'; -- Always true to simplify appending conditions

		-- Add SearchValue condition
		IF @SearchValue IS NOT NULL
			SET @WhereClause = @WhereClause + N'
				AND (PlaceName LIKE ''%'' + @SearchValue + ''%'' 
				OR StreetAddress LIKE ''%'' + @SearchValue + ''%'' 
				OR PostalCode LIKE ''%'' + @SearchValue + ''%'' 
				OR City LIKE ''%'' + @SearchValue + ''%'')';

		-- Add CustomerId condition if provided
		IF @CustomerId IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND CustomerId = @CustomerId';

		-- Count total records
		SET @ListSQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM SBSC.Customer_Address
			' + @WhereClause;

		SET @ListParamDefinition = N'@SearchValue NVARCHAR(100), @CustomerId INT, @TotalRecords INT OUTPUT';

		EXEC sp_executesql @ListSQL, @ListParamDefinition, @SearchValue, @CustomerId, @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Retrieve paginated data
		SET @ListSQL = N'
			SELECT Id, CustomerId, PlaceName, StreetAddress, PostalCode, City
			FROM SBSC.Customer_Address
			' + @WhereClause + '
			ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
			OFFSET @Offset ROWS 
			FETCH NEXT @PageSize ROWS ONLY';

		SET @ListParamDefinition = N'@SearchValue NVARCHAR(100), @CustomerId INT, @Offset INT, @PageSize INT';

		EXEC sp_executesql @ListSQL, @ListParamDefinition, @SearchValue, @CustomerId, @Offset, @PageSize;

		SELECT @TotalRecords AS TotalRecords, @TotalPages AS TotalPages;
	END


    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            -- Update the customer address table
            UPDATE SBSC.Customer_Address
            SET 
                PlaceName = ISNULL(@PlaceName, PlaceName),
                StreetAddress = ISNULL(@StreetAddress, StreetAddress),
                PostalCode = ISNULL(@PostalCode, PostalCode),
                City = ISNULL(@City, City)
            WHERE Id = @Id;

            COMMIT TRANSACTION;

            -- Return the updated address details
            SELECT @Id AS Id, @CustomerId AS CustomerId, @PlaceName AS PlaceName, 
                   @StreetAddress AS StreetAddress, @PostalCode AS PostalCode, @City AS City;
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

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
			DECLARE @Exists INT;
			SELECT @Exists = COUNT(*)
			FROM SBSC.Customer_Address
			WHERE Id = @Id;

			IF @Exists = 0
			BEGIN
				RAISERROR('Customer Address with Id %d does not exist.', 16, 1, @Id);
				RETURN; -- Exit the procedure if the auditor does not exist
			END
        BEGIN TRY

            BEGIN TRANSACTION;

            -- Delete customer address
            DELETE FROM SBSC.Customer_Address WHERE Id = @Id;

            COMMIT TRANSACTION;

            -- Return success message
			SELECT @Id AS Id;
            SELECT 'Address deleted successfully' AS Message;
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
END
GO