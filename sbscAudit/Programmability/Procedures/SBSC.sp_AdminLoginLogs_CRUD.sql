SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

-- =============================================
-- Author:      <Author, , Name>
-- Create Date: <Create Date, , >
-- Description: <Description, , >
-- =============================================
CREATE PROCEDURE [SBSC].[sp_AdminLoginLogs_CRUD]
	@Action NVARCHAR(6),
	@UserId INT = NULL,
    @Browser NVARCHAR(255) = NULL,
    @IpAddress NVARCHAR(50) = NULL,
	@OS NVARCHAR (50) = NULL,
    @LoginAttemptsCount INT = NULL,
    @LoginStatus NVARCHAR(50) = NULL,
	@Email NVARCHAR(50) = NULL,
	
	@PageNumber INT = 1,
    @PageSize INT = 100,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'LoginDateTime',
    @SortDirection NVARCHAR(4) = 'DESC'
AS
BEGIN

    SET NOCOUNT ON

	    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'LIST')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE or LIST', 16, 1);
        RETURN;
    END

	    -- CREATE operation
    IF @Action = 'CREATE'
	BEGIN
		DECLARE @PreviousLoginAttempts INT;
		DECLARE @PreviousLoginStatus NVARCHAR(50);

		-- Fetch the last login attempt for the user
		SELECT TOP 1
			@PreviousLoginAttempts = LoginAttemptsCount,
			@PreviousLoginStatus = LoginStatus
		FROM [SBSC].[AdminLoginLog]
		WHERE UserId = @UserId
		ORDER BY LoginDateTime DESC;

		-- Determine the current LoginAttemptsCount based on previous login status
		IF @PreviousLoginStatus = 'Failed'
		BEGIN
			SET @PreviousLoginAttempts = ISNULL(@PreviousLoginAttempts, 0) + 1;
		END
		ELSE
		BEGIN
			-- Reset the login attempts to 1 if the previous login was successful
			SET @PreviousLoginAttempts = 1;
		END

		-- Insert the new login attempt with the updated LoginAttemptsCount
		INSERT INTO [SBSC].[AdminLoginLog] (UserId, Email, LoginDateTime, Browser, IpAddress, OS, LoginAttemptsCount, LoginStatus)
		VALUES (@UserId, @Email, FORMAT(GETDATE(), 'yyyy-MM-dd HH:mm:ss'), @Browser, @IpAddress, @OS, @PreviousLoginAttempts, @LoginStatus);
	END

	ELSE IF @Action = 'LIST'
    BEGIN
        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('Email', 'LoginDateTime')
            SET @SortColumn = 'LoginDateTime';

        -- Validate the sort direction
        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'DESC';

        -- Declare variables for pagination
        DECLARE @SQL NVARCHAR(MAX);
        DECLARE @WhereClause NVARCHAR(MAX);
        DECLARE @ParamDefinition NVARCHAR(500);
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
        DECLARE @TotalRecords INT = 0;
        DECLARE @TotalPages INT;

        -- Define the WHERE clause for search filtering
        SET @WhereClause = N'
            WHERE 1=1 '; -- Start with a true condition

        IF @SearchValue IS NOT NULL
        BEGIN
            SET @WhereClause += N'
                AND (Email LIKE ''%'' + @SearchValue + ''%''
                OR CONVERT(VARCHAR(19), LoginDateTime, 120) LIKE ''%'' + @SearchValue + ''%'')';
        END

        IF @UserId IS NOT NULL
        BEGIN
            SET @WhereClause += N' AND UserId = @UserId';
        END

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(Id)
            FROM SBSC.AdminLoginLog
        ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @UserId INT, @TotalRecords INT OUTPUT';
    
        -- Execute the total count query
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @UserId, @TotalRecords OUTPUT;

        -- Calculate total pages
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'
            SELECT Id, UserId, Email, LoginDateTime, Browser, Ipaddress, OS, LoginAttemptsCount, LoginStatus
            FROM SBSC.AdminLoginLog
            ' + @WhereClause + '
            ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

        -- Execute the paginated query
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @UserId, @TotalRecords OUTPUT;

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