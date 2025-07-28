SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_CertificationCategory_CRUD]
    @Action NVARCHAR(MAX),
    @Id INT = NULL,
    @Title NVARCHAR(500) = NULL,
    @IsActive BIT = NULL,
    @IsVisible BIT = NULL,
	@AddedBy INT = null,
	@ModifiedBy INT = NULL,
	@ModifiedDate DATE = NULL,
	@AddedDate DATE = NULL,
    @LangId INT = NULL,
    @CertificateCategoryId INT = NULL,
    @CertificateCategoryTitle NVARCHAR(500) = NULL,
	@DefaultLangId INT = NULL,
	@UserId INT = NULL,
	@UserRole INT = NULL,
	@CertificationCategoryIds [SBSC].[IntArrayType] READONLY,
	@CertificationIds [SBSC].[IntArrayType] READONLY,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC',

	@ColumnName NVARCHAR(500) = NULL,
	@NewValue NVARCHAR(500) = NULL,
	@CurrentUser INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATELANG', 'FILTER_CUSTOMER_FROM_CERTIFICATION')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, FILTER_CUSTOMER_FROM_CERTIFICATION or LIST.', 16, 1);
        RETURN;
    END

    -- CREATE operation
    IF @Action = 'CREATE'
	BEGIN
		BEGIN TRANSACTION;  -- Start the transaction

		INSERT INTO SBSC.CertificationCategory (Title, IsActive, IsVisible, AddedDate, AddedBy, ModifiedBy, ModifiedDate)
		VALUES (@Title, ISNULL(@IsActive, 1), ISNULL(@IsVisible, 0), ISNULL(@AddedDate, GETDATE()), @AddedBy, @ModifiedBy, @ModifiedDate);
    
		DECLARE @NewCertificationCategoryId INT = SCOPE_IDENTITY();
		--SELECT @NewCertificationCategoryId AS Id, @Title AS Title;

		-- Loop through all languages and insert into CertificationCategoryLanguage table
		DECLARE @CurrentLangId INT;

		-- Cursor to loop through all languages
		DECLARE LanguageCursor CURSOR FOR
		SELECT Id FROM [SBSC].[Languages];

		OPEN LanguageCursor;

		FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Check if the current LangId matches the provided @LangId
			IF @CurrentLangId = @LangId
			BEGIN
				-- Insert with the provided Title for the specified LangId
				INSERT INTO [SBSC].[CertificationCategoryLanguage] (
					[LanguageId], [CertificationCategoryId], [CertificationCategoryTitle]
				)
				VALUES (
					@CurrentLangId, 
					@NewCertificationCategoryId, 
					@CertificateCategoryTitle  -- Provided Title
				);
			END
			ELSE IF @CurrentLangId = @DefaultLangId
			BEGIN
				-- Insert with the provided Title for the specified LangId
				INSERT INTO [SBSC].[CertificationCategoryLanguage] (
					[LanguageId], [CertificationCategoryId], [CertificationCategoryTitle]
				)
				VALUES (
					@CurrentLangId, 
					@NewCertificationCategoryId, 
					@Title  -- Provided Title
				);
			END
			ELSE
			BEGIN
				-- Insert with NULL Title for other languages
				INSERT INTO [SBSC].[CertificationCategoryLanguage] (
					[LanguageId], [CertificationCategoryId], [CertificationCategoryTitle]
				)
				VALUES (
					@CurrentLangId, 
					@NewCertificationCategoryId, 
					NULL  -- NULL Title
				);
			END

			FETCH NEXT FROM LanguageCursor INTO @CurrentLangId;
		END

		-- Close and deallocate the cursor
		CLOSE LanguageCursor;
		DEALLOCATE LanguageCursor;

		-- Commit the transaction
		COMMIT TRANSACTION;

		-- Return success message
		SELECT 
			@NewCertificationCategoryId AS [Id], 
			@Title AS [Title], 
			ISNULL(@IsActive, 0) AS [IsActive],
			@LangId AS [LangId];
	END


    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        -- If LangId is not provided, get the first Id from Languages table
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLangId; -- Set LangId to the first language Id
        END

		IF @Id IS NULL
		BEGIN
			SELECT * FROM [SBSC].[vw_CertificationCategoryDetails]
		END
		ELSE
		BEGIN
			SELECT *
			FROM [SBSC].[vw_CertificationCategoryDetails]
			WHERE [CertificationCategoryId] = @Id and [LanguageId] = @LangId;
		END
    END

    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        UPDATE SBSC.CertificationCategory
        SET Title = @Title,
            IsActive = ISNULL(@IsActive, 1),
            IsVisible = ISNULL(@IsVisible, 0),
            ModifiedBy = @ModifiedBy,
			ModifiedDate = ISNULL(@ModifiedDate, GETDATE())
        WHERE Id = @Id

        --SELECT @@ROWCOUNT AS RowsAffected
		DECLARE  @UpdateCertificationCategoryId int = (SELECT SCOPE_IDENTITY() AS UpdateCertificationCategoryId);
			SELECT @UpdateCertificationCategoryId as Id,@Title as Title


		 IF @Id IS NULL AND @LangId IS NULL
            BEGIN
                RAISERROR('Certification Category Id and Language Id both must be provided for updating language.', 16, 1);
            END
         ELSE
            BEGIN TRY
				UPDATE [SBSC].[CertificationCategoryLanguage]
                SET 
					[CertificationCategoryTitle] = ISNULL(@Title, [CertificationCategoryTitle])
				WHERE [CertificationCategoryId] = @Id AND [LanguageId] = @DefaultLangId;

                UPDATE [SBSC].[CertificationCategoryLanguage]
                SET 
					[CertificationCategoryTitle] = ISNULL(@CertificateCategoryTitle, [CertificationCategoryTitle])
				WHERE [CertificationCategoryId] = @Id AND [LanguageId] = @LangId;

                -- SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected

				-- Return the updated values
				SELECT [LanguageId], [CertificationCategoryId], [CertificationCategoryTitle]
				FROM [SBSC].[CertificationCategoryLanguage] 
				WHERE [CertificationCategoryId] = @Id AND [LanguageId] = @LangId;
            END TRY
        BEGIN CATCH
            THROW; -- Re-throw the error
        END CATCH
    END


    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION

            -- Then delete from AdminUser table
            DELETE FROM SBSC.CertificationCategory WHERE Id = @Id;

            COMMIT TRANSACTION

            -- Return the deleted user ID
            SELECT @Id AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @DeleteErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @DeleteErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @DeleteErrorState INT = ERROR_STATE()

            RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState)
        END CATCH
    END

	ELSE IF @Action = 'FILTER_CUSTOMER_FROM_CERTIFICATION'
	BEGIN
		IF NOT EXISTS (SELECT 1 FROM @CertificationCategoryIds)
		BEGIN
			RAISERROR ('Must need CertificationTypeId.', 16, 1);
			RETURN;
		END

		DECLARE @DefaultLang INT;
		IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultLang = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLang; -- Set LangId to the first language Id
        END



		IF EXISTS (SELECT 1 FROM @CertificationIds)
		BEGIN	
			SELECT 
				(SELECT 
					CertificationCategoryId, 
					CertificationCategoryTitle 
				FROM SBSC.CertificationCategoryLanguage 
				WHERE CertificationCategoryId IN (
							SELECT Id
							FROM @CertificationCategoryIds)
					AND LanguageId = @LangId
				FOR JSON PATH) AS CertificateType,
				(SELECT
					Id AS CertificationId,
					CertificateCode
				FROM SBSC.Certification
				WHERE Id IN (
						SELECT Id 
						FROM @CertificationIds)
				FOR JSON PATH) AS Certificates,
				(SELECT 
					Id AS CustomerId,
					CompanyName
				FROM SBSC.Customers
				WHERE Id IN (
					SELECT CustomerId
					FROM SBSC.Customer_Certifications
					WHERE CertificateId IN (
						SELECT Id 
						FROM @CertificationIds))
				FOR JSON PATH) AS Customer	
			FROM @CertificationCategoryIds cci
			LEFT JOIN SBSC.Certification cert ON cert.CertificateTypeId = cci.Id
		END

		ELSE
		BEGIN
			SELECT 
				(SELECT 
					CertificationCategoryId, 
					CertificationCategoryTitle 
				FROM SBSC.CertificationCategoryLanguage 
				WHERE CertificationCategoryId IN (
					SELECT Id
					FROM @CertificationCategoryIds)
				AND LanguageId = @LangId
				FOR JSON PATH) AS CertificateType,
				(SELECT
					Id AS CertificationId,
						CertificateCode
					FROM SBSC.Certification
					WHERE Id IN (
							SELECT Id 
							FROM SBSC.Certification
							WHERE CertificateTypeId IN (
								SELECT Id
								FROM @CertificationCategoryIds
								)
							AND IsActive = 1
							)
				FOR JSON PATH) AS Certificates,
				(SELECT 
					Id AS CustomerId,
					CompanyName
				FROM SBSC.Customers
				WHERE Id IN (
					SELECT CustomerId
					FROM SBSC.Customer_Certifications
					WHERE CertificateId IN (
						SELECT Id 
						FROM SBSC.Certification 
						WHERE CertificateTypeId IN (
							SELECT Id
							FROM @CertificationCategoryIds)))
				FOR JSON PATH) AS Customer	
		END
	END
	
    -- LIST operation
    ELSE IF @Action = 'LIST'
	BEGIN
        DECLARE @DefaultLanguageId INT;
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultLanguageId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageId; -- Set LangId to the first language Id
        END

        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('CertificationCategoryTitle', 'LanguageId')
            SET @SortColumn = 'CertificationCategoryTitle';  -- Set default sort column to 'Title'

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

        -- Define the WHERE clause for filtering by CertificationCategoryTitle and LangId
        SET @WhereClause = N'
            WHERE LanguageId = @LangId
            AND (@SearchValue IS NULL
            OR CertificationCategoryTitle LIKE ''%'' + @SearchValue + ''%''
            OR CAST(LanguageId AS NVARCHAR) LIKE ''%'' + @SearchValue + ''%'')';

		IF (@UserRole = 2 AND ((SELECT IsSBSCAuditor FROM SBSC.Auditor WHERE Id = @UserId) != 1))
		BEGIN
		SET @WhereClause += N'
			AND CertificationCategoryId IN (SELECT DISTINCT CertificateTypeID FROM SBSC.Certification WHERE Id IN (SELECT CertificationId FROM SBSC.Auditor_Certifications WHERE AuditorId = @UserId))';
		END

        -- Count total records
        SET @SQL = N'
            SELECT @TotalRecords = COUNT(*)
            FROM [SBSC].[vw_CertificationCategoryDetails]
            ' + @WhereClause;

        SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @LangId INT, @UserId INT, @TotalRecords INT OUTPUT'; 
    
        -- Execute the total count query and assign the result to @TotalRecords
        EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @UserId, @TotalRecords OUTPUT;


        -- Calculate total pages based on @TotalRecords
        SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

        -- Retrieve paginated data
        SET @SQL = N'
            SELECT *
            FROM [SBSC].[vw_CertificationCategoryDetails]
            ' + @WhereClause + '
            ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
            OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
            FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

        -- Execute the paginated query
        EXEC sp_executesql @SQL, N'@SearchValue NVARCHAR(100), @LangId INT, @UserId INT', @SearchValue, @LangId, @UserId;

        -- Return pagination details
        SELECT @TotalRecords AS TotalRecords, 
               @TotalPages AS TotalPages, 
               @PageNumber AS CurrentPage, 
               @PageSize AS PageSize,
               CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
               CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
    END
END


--SELECT CertificationCategoryId FROM [SBSC].[vw_CertificationCategoryDetails] where CertificationCategoryId in (

--SELECT DISTINCT CertificateTypeId
--            FROM SBSC.Certification 
--            WHERE Id IN (
--                SELECT DISTINCT CertificationId 
--                FROM SBSC.Auditor_Certifications 
--                WHERE AuditorId = 5
--            )
--			)
GO