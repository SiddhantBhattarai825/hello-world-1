SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_AdminUser_Crud]
    @Action NVARCHAR(20),
    @Id INT = NULL,
    @Email NVARCHAR(500) = NULL,
    @Password NVARCHAR(500) = NULL,
    @IsActive BIT = NULL,
    @IsPasswordChanged BIT = NULL,
    @PasswordChangedDate DATETIME = NULL,
	@MfaStatus INT = NULL,
	@DefaultLangId INT = NULL,

    @FullName NVARCHAR(500) = NULL,
    @DateOfBirth NVARCHAR(500) = NULL,
    @AddedBy INT = NULL,
    @ModifiedBy INT = NULL,

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
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATE_COLUMN', 'UPDATE_USER_LANG', 'UPDATE_MFA')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, UPDATE_COLUMN, UPDATE_MFA or UPDATE_USER_LANG', 16, 1);
        RETURN;
    END

    -- CREATE operation
    IF @Action = 'CREATE'
    BEGIN
		SET @Email = LTRIM(RTRIM(LOWER(@Email)))

        -- Check if the email already exists in UserCredentials before inserting anything else
        IF EXISTS (
			SELECT 1 FROM SBSC.AdminUser WHERE Email = @Email
			UNION
			SELECT 1 FROM SBSC.UserCredentials WHERE Email = @Email
		)
		BEGIN
			RAISERROR('Email already exists.', 16, 1)
			RETURN
		END

        BEGIN TRY
            BEGIN TRANSACTION

			IF(@DefaultLangId IS NULL)
			BEGIN
				SET @DefaultLangId = (SELECT Id FROM SBSC.Languages WHERE IsDefault = 1)
			END

            -- Insert into AdminUser table with default handling for IsActive, IsPasswordChanged, and null values
            INSERT INTO AdminUser (Email, [Password], IsActive, IsPasswordChanged, MfaStatus, DefaultLangId)
            VALUES (@Email, 
                    @Password, 
                    ISNULL(@IsActive, 0), -- Default to 0 if null
                    ISNULL(@IsPasswordChanged, 0),
					ISNULL(@MfaStatus, 0),
					@DefaultLangId
					); 
         
            -- Capture the newly inserted AdminUser ID
            DECLARE @NewAdminUserId INT
            SET @NewAdminUserId = SCOPE_IDENTITY()

            -- Insert into AdminUserDetail table with default handling for nullable fields
            INSERT INTO AdminUserDetail (AdminUserId, FullName, DateOfBirth, AddedDate, AddedBy)
            VALUES (@NewAdminUserId, 
                    @FullName, 
                    CASE WHEN @DateOfBirth IS NOT NULL THEN @DateOfBirth ELSE NULL END, -- Handle nullable DateOfBirth
                    GETDATE(), -- AddedDate is current date
                    ISNULL(@AddedBy, @NewAdminUserId)); -- Default to newly created AdminUserId if null

            -- Commit the transaction
            COMMIT TRANSACTION

            -- Return the new AdminUser ID	
            SELECT @NewAdminUserId AS Id, @Email AS Email, @FullName AS FullName
        END TRY
        BEGIN CATCH
            -- Rollback transaction if there is any error
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            -- Re-throw the error
            DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @ErrorState INT = ERROR_STATE()

            RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
        END CATCH
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        SELECT * FROM SBSC.vw_AdminUserDetails
        WHERE (@Id IS NULL OR Id = @Id)
    END

	ELSE IF @Action = 'LIST'
	BEGIN
    -- Validate and sanitize the sort column
    IF @SortColumn NOT IN ('Id', 'Email', 'FullName')
        SET @SortColumn = 'FullName';

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

    -- Define the WHERE clause for search filtering
    SET @WhereClause = N'
        WHERE (@SearchValue IS NULL
        OR Id LIKE ''%'' + @SearchValue + ''%''
        OR Email LIKE ''%'' + @SearchValue + ''%''
        OR FullName LIKE ''%'' + @SearchValue + ''%'')';

    -- Count total records
    SET @SQL = N'
        SELECT @TotalRecords = COUNT(Id)
        FROM SBSC.vw_AdminUserDetails
    ' + @WhereClause;

    SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT'; 
    
    -- Execute the total count query and assign the result to @TotalRecords
    EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

    -- Calculate total pages based on @TotalRecords
    SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

    -- Retrieve paginated data
    SET @SQL = N'
        SELECT * FROM SBSC.vw_AdminUserDetails
        ' + @WhereClause + '
        ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
        OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
        FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

    -- Execute the paginated query
    EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

    -- Return pagination details
    SELECT @TotalRecords AS TotalRecords, 
           @TotalPages AS TotalPages, 
           @PageNumber AS CurrentPage, 
           @PageSize AS PageSize,
           CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
           CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
END
	
    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Check if the email already exists for another user
        IF EXISTS (SELECT 1 FROM AdminUser WHERE Email = @Email AND Id <> @Id)
        BEGIN
            RAISERROR('Email already exists for another user.', 16, 1)
            RETURN
        END

        BEGIN TRY
            BEGIN TRANSACTION

            -- Update AdminUser table
            UPDATE AdminUser
            SET Email = ISNULL(@Email, Email),
                Password = ISNULL(@Password, Password),
                IsActive = ISNULL(@IsActive, IsActive),
                IsPasswordChanged = ISNULL(@IsPasswordChanged, IsPasswordChanged),
                PasswordChangedDate = ISNULL(@PasswordChangedDate, PasswordChangedDate),
				MfaStatus = ISNULL(@MfaStatus, MfaStatus),
				DefaultLangID = ISNULL(@DefaultLangID, DefaultLangId)
            WHERE Id = @Id;

            -- Update AdminUserDetail table
            UPDATE AdminUserDetail
            SET FullName = ISNULL(@FullName, FullName),
                DateOfBirth = ISNULL(@DateOfBirth, DateOfBirth),
                ModifiedBy = CASE 
								WHEN ModifiedBy IS NULL AND @ModifiedBy IS NULL THEN @Id 
								ELSE ISNULL(@ModifiedBy, ModifiedBy)
							END,
                ModifiedDate = GETDATE()
            WHERE AdminUserId = @Id;

            COMMIT TRANSACTION

            -- Return the updated user details
            SELECT Id, Email, FullName, MfaStatus
            FROM SBSC.vw_AdminUserDetails
            WHERE Id = @Id
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @UpdateErrorState INT = ERROR_STATE()

            RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState)
        END CATCH
    END

	-- UPDATE operation
    ELSE IF @Action = 'UPDATE_USER_LANG'
    BEGIN
        -- Check if the email already exists for another user
        IF @Id IS NULL
        BEGIN
            RAISERROR('Enter a valid User Id.', 16, 1)
            RETURN
        END

        BEGIN TRY
            -- Update AdminUser table
            UPDATE AdminUser
            SET DefaultLangID = ISNULL(@DefaultLangID, DefaultLangId)
            WHERE Id = @Id;

            -- Return the updated user details
            SELECT Id, Email, FullName, MfaStatus, DefaultLangId
            FROM SBSC.vw_AdminUserDetails
            WHERE Id = @Id
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @UpdateLangErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @UpdateLangErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @UpdateLangErrorState INT = ERROR_STATE()

            RAISERROR(@UpdateLangErrorMessage, @UpdateLangErrorSeverity, @UpdateLangErrorState)
        END CATCH
    END


	ELSE IF @Action = 'UPDATE_MFA'
    BEGIN
        -- Check if the email already exists for another user
        IF @Id IS NULL
        BEGIN
            RAISERROR('Enter a valid User Id.', 16, 1)
            RETURN
        END

        BEGIN TRY
            -- Update AdminUser table
            UPDATE AdminUser
			SET MfaStatus = @MfaStatus
			WHERE Id = @Id;

            -- Return the updated user details
            SELECT Id, Email, FullName, MfaStatus, DefaultLangId
            FROM SBSC.vw_AdminUserDetails
            WHERE Id = @Id
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION
            
            DECLARE @UpdatLangErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
            DECLARE @UpdatLangErrorSeverity INT = ERROR_SEVERITY()
            DECLARE @UpdatLangErrorState INT = ERROR_STATE()

            RAISERROR(@UpdatLangErrorMessage, @UpdatLangErrorSeverity, @UpdatLangErrorState)
        END CATCH
    END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
		IF EXISTS(SELECT 1 FROM SBSC.AdminUser WHERE Id = @Id)
        BEGIN TRY

            -- Then delete from AdminUser table
            DELETE FROM AdminUser WHERE Id = @Id;

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

	-- UPDATE specific column entry
	ELSE IF @Action = 'UPDATE_COLUMN'
	BEGIN 
		-- Validate @ColumnName to prevent SQL injection
		IF @ColumnName NOT IN ('Password', 'Email')
		BEGIN 
			RAISERROR('Invalid column name.', 16, 1);
			RETURN;
		END

		BEGIN TRY
			BEGIN TRANSACTION;

			DECLARE @UpdateSQL NVARCHAR(MAX);
        
			IF @ColumnName = 'Password'
			BEGIN
				SET @UpdateSQL = N'
					UPDATE SBSC.AdminUser 
					SET Password = @NewValue,
						IsPasswordChanged = 1,
						PasswordChangedDate = GETDATE()
					WHERE Id = @Id';
			END
			ELSE
			BEGIN
				SET @UpdateSQL = N'
					UPDATE SBSC.AdminUser 
					SET ' + QUOTENAME(@ColumnName) + ' = @NewValue 
					WHERE Id = @Id';
			END
        
			EXEC sp_executesql @UpdateSQL, 
				N'@NewValue NVARCHAR(500), @Id INT',
				@NewValue, @Id;
        
			DECLARE @RowsAffected INT = @@ROWCOUNT;
        
			IF @RowsAffected = 0
			BEGIN
				ROLLBACK;
				RAISERROR('No records were updated in AdminUser. Please check the UserID and ensure it exists.', 16, 1);
				RETURN;
			END

			-- Update AdminUserDetail
			UPDATE SBSC.AdminUserDetail
			SET ModifiedBy = @CurrentUser,
				ModifiedDate = GETDATE()
			WHERE AdminUserId = @Id;

			IF @@ROWCOUNT = 0
			BEGIN
				ROLLBACK;
				RAISERROR('Failed to update AdminUserDetail. The AdminUserId may not exist in AdminUserDetail table.', 16, 1);
				RETURN;
			END

			COMMIT;

			SELECT @RowsAffected AS RowsAffected;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK;
        
			DECLARE @UpdateColumnErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @UpdateColumnErrorSeverity INT = ERROR_SEVERITY();
			DECLARE @UpdateColumnErrorState INT = ERROR_STATE();

			RAISERROR (@UpdateColumnErrorMessage, @UpdateColumnErrorSeverity, @UpdateColumnErrorState);
		END CATCH
	END
END
GO