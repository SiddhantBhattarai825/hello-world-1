SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_EmailTemplateLanguage_CRUD]
    @Action NVARCHAR(20),
    @Id INT = NULL, 
    @LangId INT = NULL,
	@EmailTemplateId INT = NULL,
    @EmailSubject NVARCHAR(500) = NULL,
	@EmailBody NVARCHAR(MAX) = NULL,
	@EmailCode NVARCHAR(500) = NULL,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC',

	@Translations [SBSC].[EmailTemplateLanguageType] READONLY
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATELANG')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST or UPDATELANG', 16, 1);
        RETURN;
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
			-- Declare a variable to hold the first LangId 
		DECLARE @DefaultLangId INT; 
    
		-- If LangId is not provided, get the first Id from Languages table 
		IF @LangId IS NULL 
		BEGIN 
			SELECT TOP 1 @DefaultLangId = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLangId; -- Set LangId to the first language Id 
		END 

	    IF @EmailCode IS NULL
		BEGIN
			SELECT * FROM [SBSC].[vw_EmailTemplateDetails]
			WHERE [LanguageId] = @LangId;
		END
		ELSE
		BEGIN
			-- Return filtered results by EmailCode and LangId
			SELECT *
			FROM [SBSC].[vw_EmailTemplateDetails]
			WHERE EmailCode = @EmailCode AND [LanguageId] = @LangId;
		END
    END

    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Check if any records were provided
        IF NOT EXISTS (SELECT 1 FROM @Translations)
        BEGIN
            RAISERROR('No records provided for UPDATE operation', 16, 1);
            RETURN;
        END

        BEGIN TRY
            -- Update operation
            UPDATE ETL
            SET 
                ETL.EmailSubject = T.EmailSubject,
                ETL.EmailBody = T.EmailBody
            FROM [SBSC].[EmailTemplateLanguage] ETL
            INNER JOIN @Translations T ON ETL.EmailTemplateId = T.EmailTemplateId AND ETL.LangId = T.LangId;

            SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
        END TRY
        BEGIN CATCH
            THROW; -- Re-throw the error
        END CATCH
    END

	ELSE IF @Action = 'UPDATELANG'
	    BEGIN
		DECLARE @DefaultUpdateLangId INT;
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultUpdateLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
            SET @LangId = @DefaultUpdateLangId;
        END

		IF @EmailTemplateId IS NULL
			BEGIN
				RAISERROR('Email Template Id must be provided for updating language.', 16, 1);
			END
		ELSE
			BEGIN TRY
				UPDATE [SBSC].[EmailTemplateLanguage]
				SET EmailSubject = ISNULL(@EmailSubject, EmailSubject),
					EmailBody = ISNULL(@EmailBody, EmailBody)
				WHERE EmailTemplateId = @EmailTemplateId and [LangId] = @LangId

				SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
			END TRY
        BEGIN CATCH
            THROW; -- Re-throw the error
        END CATCH
    END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        DELETE FROM [SBSC].[EmailTemplateLanguage]
        WHERE [Id] = @Id;

		SELECT @@ROWCOUNT AS RowsAffected;
    END

	-- LIST operation
	ELSE IF @Action = 'LIST'
	BEGIN
		-- Declare a variable to hold the first LangId 
		DECLARE @DefaultLanguageId INT; 
    
		-- If LangId is not provided, get the first Id from Languages table 
		IF @LangId IS NULL 
		BEGIN 
			SELECT TOP 1 @DefaultLanguageId = [Id] 
			FROM [SBSC].[Languages] 
			WHERE IsDefault = 1; 
			SET @LangId = @DefaultLanguageId; -- Set LangId to the first language Id 
		END 

		-- Validate and sanitize the sort column
		IF @SortColumn NOT IN ('EmailCode', 'EmailSubject', 'LanguageId')
			SET @SortColumn = 'EmailCode';  -- Set default sort column to 'EmailCode'

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

		-- Define the WHERE clause for filtering by EmailCode and LangId
		SET @WhereClause = N'
			WHERE LanguageId = @LangId
			AND (@SearchValue IS NULL
			OR EmailCode LIKE ''%'' + @SearchValue + ''%''
			OR EmailSubject LIKE ''%'' + @SearchValue + ''%''
			OR CAST(LanguageId AS NVARCHAR) LIKE ''%'' + @SearchValue + ''%'')';

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(*)
			FROM [SBSC].[vw_EmailTemplateDetails]
			' + @WhereClause;

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @LangId INT, @TotalRecords INT OUTPUT'; 
    
		-- Execute the total count query and assign the result to @TotalRecords
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @TotalRecords OUTPUT;

		-- Calculate total pages based on @TotalRecords
		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Retrieve paginated data
		SET @SQL = N'
			SELECT *
			FROM [SBSC].[vw_EmailTemplateDetails]
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