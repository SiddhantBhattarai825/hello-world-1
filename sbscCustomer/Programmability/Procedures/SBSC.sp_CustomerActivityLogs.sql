SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_CustomerActivityLogs]
    @Action NVARCHAR(10),
    @IpAddress NVARCHAR(45) = NULL,
    @ActivityAction NVARCHAR(10) = NULL,
    @EventType NVARCHAR(50) = NULL,
    @ExecutedSpName NVARCHAR(200) = NULL,
    @UpdatedBy NVARCHAR(50) = NULL,
    @PageName NVARCHAR(200) = NULL,
    @TableName NVARCHAR(100) = NULL,
    @EditedByEmail NVARCHAR(256) = NULL, -- New field for the editor's email
    @TargetEmail NVARCHAR(256) = NULL, -- New field for the target's email
    @Browser NVARCHAR(200) = NULL,
    @Details NVARCHAR(MAX) = NULL,
    @ColumnDetails NVARCHAR(MAX) = NULL, -- JSON string containing column details
	
	@StartDate DATETIME = NULL,
	@EndDate DATETIME = NULL,

    @Id INT = NULL,

    @PageNumber INT = 1,
    @PageSize INT = 100,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'UpdatedDate',
    @SortDirection NVARCHAR(4) = 'DESC'
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action NOT IN ('CREATE', 'LIST', 'LISTDETAIL')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE or LIST', 16, 1);
        RETURN;
    END

    -- CREATE operation
    IF @Action = 'CREATE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
        
            -- Insert into ActivityLog
            DECLARE @ActivityLogId BIGINT;
        
            INSERT INTO [SBSC].[CustomerActivityLog] 
                (IpAddress, [Action], EventType, ExecutedSpName, UpdatedDate, UpdatedBy, PageName, TableName, EditedByEmail, TargetEmail, Browser, Details)
            VALUES 
                (@IpAddress, @ActivityAction, @EventType, @ExecutedSpName, FORMAT(GETUTCDATE(), 'yyyy-MM-dd HH:mm:ss'), @UpdatedBy, 
                 @PageName, @TableName, @EditedByEmail, @TargetEmail, @Browser, @Details);
        
            SET @ActivityLogId = SCOPE_IDENTITY();
        
            -- Insert into ActivityLogDetail
            INSERT INTO [SBSC].[CustomerActivityLogDetail] (ActivityLogId, ColumnName, OldValue, NewValue)
            SELECT 
                @ActivityLogId,
                JSON_VALUE(value, '$.ColumnName'),
                JSON_VALUE(value, '$.OldValue'),
                JSON_VALUE(value, '$.NewValue')
            FROM OPENJSON(@ColumnDetails);
        
            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
        
            -- Re-throw the error
            THROW;
        END CATCH
    END

     IF @Action = 'LIST'
    BEGIN
        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('UpdatedBy', 'UpdatedDate')
            SET @SortColumn = 'UpdatedDate';

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
        SET @WhereClause = N' WHERE 1=1 '; -- Start with a true condition

        IF @SearchValue IS NOT NULL
        BEGIN
            SET @WhereClause += N'
                AND (UpdatedBy LIKE ''%'' + @SearchValue + ''%'' 
                OR TableName LIKE ''%'' + @SearchValue + ''%'' 
                OR EditedByEmail LIKE ''%'' + @SearchValue + ''%'' 
                OR TargetEmail LIKE ''%'' + @SearchValue + ''%'' 
                OR CONVERT(VARCHAR(19), UpdatedDate, 120) LIKE ''%'' + @SearchValue + ''%'')';
        END

        -- Add date range filter
        IF @StartDate IS NOT NULL AND @EndDate IS NOT NULL
        BEGIN
            SET @WhereClause += N' AND UpdatedDate >= @StartDate AND UpdatedDate <= @EndDate ';
        END

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(Id)
            FROM [SBSC].[CustomerActivityLog]
        ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @StartDate DATETIME, @EndDate DATETIME, @TotalRecords INT OUTPUT';

        EXEC sp_executesql @SQL, @ParamDefinition, 
                           @SearchValue = @SearchValue, 
                           @StartDate = @StartDate, 
                           @EndDate = @EndDate, 
                           @TotalRecords = @TotalRecords OUTPUT;

        -- Calculate total pages
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'
            SELECT Id, IpAddress, Action, EventType, ExecutedSpName, UpdatedDate, UpdatedBy, PageName, TableName, EditedByEmail, TargetEmail, Browser, Details
            FROM [SBSC].[CustomerActivityLog]
            ' + @WhereClause + '
            ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

        EXEC sp_executesql @SQL, @ParamDefinition, 
                           @SearchValue = @SearchValue, 
                           @StartDate = @StartDate, 
                           @EndDate = @EndDate, 
                           @TotalRecords = @TotalRecords OUTPUT;

        -- Return pagination details
        SELECT @TotalRecords AS TotalRecords, 
               @TotalPages AS TotalPages, 
               @PageNumber AS CurrentPage, 
               @PageSize AS PageSize,
               CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
               CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
    END



    ELSE IF @Action = 'LISTDETAIL'
    BEGIN
        IF @Id IS NULL
        BEGIN
            RAISERROR('Id field is required for LISTDETAIL action', 16, 1);
            RETURN;
        END
        
        SELECT *
        FROM [SBSC].[CustomerActivityLogDetail]
        WHERE [ActivityLogId] = @Id;
    END
END
GO