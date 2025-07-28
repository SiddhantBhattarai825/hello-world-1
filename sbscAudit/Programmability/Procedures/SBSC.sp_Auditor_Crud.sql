SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_Auditor_Crud]
    @Action NVARCHAR(50),
    @Id INT = NULL,
    @Name NVARCHAR(500) = NULL,
    @Email NVARCHAR(500) = NULL,
    @Password NVARCHAR(500) = NULL,
    @IsActive BIT = NULL,
    @IsPasswordChanged BIT = NULL,
    @PasswordChangedDate DATETIME = NULL,
    @DefaultLangId INT = NULL,
    @ColumnName NVARCHAR(500) = NULL,
    @NewValue NVARCHAR(500) = NULL,
    @IsSBSCAuditor BIT = NULL,
    
	@Certifications NVARCHAR(MAX) = NULL, -- JSON array of certifications
	@CertificationsId [SBSC].[CertificationIdList] READONLY,

	@CertificationTypesId [SBSC].[IntArrayType] READONLY,

    @AssignedCustomers NVARCHAR(MAX) = NULL, -- JSON array of customer names
    @Status BIT = NULL,
    @MFAStatus INT = NULL,
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATE_COLUMN', 'UPDATE_USER_LANG', 'TEST', 'UPDATE_MFA')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, UPDATE_COLUMN, UPDATE_MFA or UPDATE_USER_LANG', 16, 1);
        RETURN;
    END

    -- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;

			SET @Email = LTRIM(RTRIM(LOWER(@Email)));

			-- Check if the email already exists in UserCredentials before inserting anything else
			IF EXISTS (
				SELECT 1 FROM SBSC.AdminUser WHERE Email = @Email
				UNION
				SELECT 1 FROM SBSC.UserCredentials WHERE Email = @Email
			)
			BEGIN
				RAISERROR('The email %s is already associated with another user. Please use a unique email address.', 16, 1, @Email);
				ROLLBACK TRANSACTION;
				RETURN;
			END

			IF(@DefaultLangId IS NULL)
			BEGIN
				SET @DefaultLangId = (SELECT Id FROM SBSC.Languages WHERE IsDefault = 1)
			END

			-- Insert into Auditor table
			INSERT INTO SBSC.Auditor ([Name], IsSBSCAuditor, [Status])
			VALUES (@Name, ISNULL(@IsSBSCAuditor, 0), ISNULL(@Status, 0));

			DECLARE @NewAuditorId INT = SCOPE_IDENTITY();

			-- Insert into AuditorCredentials table
			INSERT INTO SBSC.AuditorCredentials (Email, AuditorId, [Password], IsActive, IsPasswordChanged, MfaStatus, DefaultLangId)
			VALUES (@Email, @NewAuditorId, @Password, ISNULL(@IsActive, 0), ISNULL(@IsPasswordChanged, 0), ISNULL(@MFAStatus, 0), @DefaultLangId);

        
			-- Handle Certifications
			IF EXISTS (SELECT 1 FROM @CertificationsId)
			BEGIN
				-- Validate certification IDs
				IF EXISTS (
					SELECT 1 
					FROM @CertificationsId cid
					LEFT JOIN [SBSC].[Certification] c ON c.Id = cid.CertificationId
					WHERE c.Id IS NULL OR c.IsActive = 0
				)
				BEGIN
					RAISERROR('One or more certification IDs are invalid or inactive.', 16, 1);
					ROLLBACK TRANSACTION;
					RETURN;
				END
				-- Insert into Customer_Certifications
				INSERT INTO SBSC.Auditor_Certifications (
					AuditorId,
					CertificationId,
					IsDefault
				)
				SELECT 
					@NewAuditorId, 
					cid.CertificationId,
					0
				FROM @CertificationsId cid
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId;
			END
			ELSE IF EXISTS (SELECT 1 FROM @CertificationTypesId)  -- Fixed: Changed from @CertificationsId to @CertificationTypesId
			BEGIN
				-- Validate certification type IDs
				IF EXISTS (
					SELECT 1 
					FROM @CertificationTypesId ctid
					LEFT JOIN [SBSC].[CertificationCategory] certc ON certc.Id = ctid.Id
					WHERE certc.Id IS NULL OR certc.IsActive = 0
				)
				BEGIN
					RAISERROR('One or more certification type IDs are invalid or inactive.', 16, 1);
					ROLLBACK TRANSACTION;
					RETURN;
				END
    
				-- Insert into Auditor_Certifications - Insert all certifications from specified certification types
				INSERT INTO SBSC.Auditor_Certifications (
					AuditorId,
					CertificationId,
					IsDefault
				)
				SELECT 
					@NewAuditorId, 
					c.Id,  
					0
				FROM @CertificationTypesId ctid
				INNER JOIN SBSC.CertificationCategory cc ON cc.Id = ctid.Id
				INNER JOIN SBSC.Certification c ON c.CertificateTypeId = cc.Id  -- all certifications of this type
				WHERE c.IsActive = 1;  -- Only insert active certifications
			END

		

			-- Handle Assigned Customers if provided
			IF @AssignedCustomers IS NOT NULL AND JSON_QUERY(@AssignedCustomers) <> '[]'
			BEGIN
				EXEC sp_execute_remote
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_CustomerAuditors_DML] @Action, @AuditorId, @AssignedCustomers',
					@params = N'@Action NVARCHAR(20), @AuditorId INT, @AssignedCustomers NVARCHAR(MAX)',
					@Action = 'CREATE',
					@AuditorId = @NewAuditorId,
					@AssignedCustomers = @AssignedCustomers;
			END

			EXEC sp_execute_remote
				@data_source_name = N'SbscCustomerDataSource',
				@stmt = N'EXEC [SBSC].[sp_CustomerAuditors_DML] @Action, @AuditorId',
				@params = N'@Action NVARCHAR(20), @AuditorId INT',
				@Action = 'ASSIGN_AUDITOR',
				@AuditorId = @NewAuditorId;

			-- Insert Into UserCredentials after all other inserts
			INSERT INTO SBSC.UserCredentials (Email, Password, UserType, AuditorId, MfaStatus)
			VALUES (@Email, @Password, 'Auditor', @NewAuditorId, ISNULL(@MFAStatus, 0));

			COMMIT TRANSACTION;

			-- Convert CertificationIds back to JSON for response
			DECLARE @CertificationsJson NVARCHAR(MAX);
			SELECT @CertificationsJson = (
				SELECT CertificateCode
				FROM @CertificationsId cid
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId
				FOR JSON PATH
			);

			-- Return the new Auditor details
			SELECT @NewAuditorId AS Id, @Email AS Email, @Name AS [Name], @CertificationsJson AS Certifications, @AssignedCustomers AS AssignedCustomers;
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

		-- Validate input parameters
		IF @Id IS NULL OR @Id <= 0
		BEGIN
			RAISERROR('Invalid Auditor Id provided.', 16, 1);
			RETURN;
		END

		SELECT * FROM SBSC.vw_AuditorDetails
		WHERE Id = @Id;
	END


	-- LIST operation
	ELSE IF @Action = 'LIST'
	BEGIN
		IF @SortColumn NOT IN ('Id', 'Email', 'Name', 'IsSBSCAuditor', 'Status', 'MFAStatus', 'CreatedDate')
			SET @SortColumn = 'CreatedDate';

		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC';

		DECLARE @ListSQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ListParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- WHERE clause for search filtering
		SET @WhereClause = N'
			WHERE (@SearchValue IS NULL
			OR Id LIKE ''%'' + @SearchValue + ''%'' 
			OR Email LIKE ''%'' + @SearchValue + ''%'' 
			OR Name LIKE ''%'' + @SearchValue + ''%'')';

		-- Count total records
		SET @ListSQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM SBSC.vw_AuditorDetails
			' + @WhereClause;

		SET @ListParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT';

		EXEC sp_executesql @ListSQL, @ListParamDefinition, @SearchValue, @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Retrieve paginated data with Certifications and CertificationTypes
		SET @ListSQL = N'
		SELECT *
		FROM SBSC.vw_AuditorDetails 
		' + @WhereClause + '
		ORDER BY ' + @SortColumn + ' ' + @SortDirection + '
		OFFSET @Offset ROWS 
		FETCH NEXT @PageSize ROWS ONLY';

		SET @ListParamDefinition = N'@SearchValue NVARCHAR(100), @Offset INT, @PageSize INT';

		EXEC sp_executesql @ListSQL, @ListParamDefinition, @SearchValue, @Offset, @PageSize;

		SELECT @TotalRecords AS TotalRecords, @TotalPages AS TotalPages;
	END

	-- UPDATE operation
    IF @Action = 'UPDATE_USER_LANG'
    BEGIN
        -- Check if the email already exists for another user
        IF @Id IS NULL
        BEGIN
            RAISERROR('Enter a valid User Id.', 16, 1)
            RETURN
        END

        BEGIN TRY
            -- Update AdminUser table
            UPDATE SBSC.AuditorCredentials
            SET DefaultLangId = ISNULL(@DefaultLangID, DefaultLangId)
            WHERE AuditorId = @Id;

            -- Return the updated user details
            SELECT 1;
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
            UPDATE SBSC.AuditorCredentials
			SET MfaStatus = @MFAStatus
			WHERE Id = @Id;

             -- Return the updated user details
            SELECT 1;
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


    -- Update operation
	-- Update operation
	IF @Action = 'UPDATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
			-- Update the Auditor table
				UPDATE SBSC.Auditor
				SET 
					[Name] = @Name,
					IsSBSCAuditor = ISNULL(@IsSBSCAuditor, IsSBSCAuditor),
					[Status] = ISNULL(@Status, [Status])
				WHERE Id = @Id;

			-- Update the AuditorCredentials table
				UPDATE SBSC.AuditorCredentials
				SET 
					Email = @Email,
					IsActive = ISNULL(@IsActive, IsActive),
					IsPasswordChanged = ISNULL(@IsPasswordChanged, IsPasswordChanged),
					PasswordChangedDate = ISNULL(@PasswordChangedDate, PasswordChangedDate),
					MfaStatus = ISNULL(@MFAStatus, MfaStatus),
					DefaultLangId = ISNULL(@DefaultLangId, DefaultLangId)
				WHERE AuditorId = @Id;

			-- Handle Certifications if provided
				IF EXISTS (SELECT 1 FROM @CertificationsId)
				BEGIN
					-- Validate certification IDs
					IF EXISTS (
						SELECT 1 
						FROM @CertificationsId cid
						LEFT JOIN [SBSC].[Certification] c ON c.Id = cid.CertificationId
						WHERE c.Id IS NULL OR c.IsActive = 0
					)
					BEGIN
						RAISERROR('One or more certification IDs are invalid or inactive.', 16, 1);
						ROLLBACK TRANSACTION;
						RETURN;
					END

					-- Delete existing certifications not in the new list
					IF EXISTS (SELECT 1 FROM SBSC.Auditor_Certifications
									WHERE AuditorId = @Id
									AND CertificationId NOT IN (SELECT CertificationId FROM @CertificationsId)
									AND IsDefault = 1)
					BEGIN
						RAISERROR('Auditor set as default cannot be deleted.', 16, 1);
						ROLLBACK TRANSACTION;
						RETURN;
					END
					ELSE
					BEGIN
						DELETE FROM SBSC.Auditor_Certifications
						WHERE AuditorId = @Id
						AND CertificationId NOT IN (SELECT CertificationId FROM @CertificationsId)
						AND IsDefault = 0;
					END

					-- Insert only new certifications
					INSERT INTO SBSC.Auditor_Certifications (AuditorId, CertificationId, IsDefault)
					SELECT @Id, cid.CertificationId, 0
					FROM @CertificationsId cid
					WHERE NOT EXISTS (
						SELECT 1 
						FROM SBSC.Auditor_Certifications ac 
						WHERE ac.AuditorId = @Id 
						AND ac.CertificationId = cid.CertificationId
					);
				END
				ELSE IF EXISTS (SELECT 1 FROM @CertificationTypesId)  -- Handle certification types
				BEGIN
					-- Validate certification type IDs
					IF EXISTS (
						SELECT 1 
						FROM @CertificationTypesId ctid
						LEFT JOIN [SBSC].[CertificationCategory] certc ON certc.Id = ctid.Id
						WHERE certc.Id IS NULL OR certc.IsActive = 0
					)
					BEGIN
						RAISERROR('One or more certification type IDs are invalid or inactive.', 16, 1);
						ROLLBACK TRANSACTION;
						RETURN;
					END
    
					-- Get all certification IDs from the specified certification types
					DECLARE @AllCertificationsFromTypes TABLE (CertificationId INT);
					INSERT INTO @AllCertificationsFromTypes (CertificationId)
					SELECT c.Id
					FROM @CertificationTypesId ctid
					INNER JOIN SBSC.CertificationCategory cc ON cc.Id = ctid.Id
					INNER JOIN SBSC.Certification c ON c.CertificateTypeId = cc.Id
					WHERE c.IsActive = 1;
    
					-- Delete existing certifications not in the certification types list
					IF EXISTS (SELECT 1 FROM SBSC.Auditor_Certifications ac
								WHERE ac.AuditorId = @Id
								AND ac.CertificationId NOT IN (SELECT CertificationId FROM @AllCertificationsFromTypes)
								AND ac.IsDefault = 1)
					BEGIN
						RAISERROR('Auditor set as default cannot be deleted.', 16, 1);
						ROLLBACK TRANSACTION;
						RETURN;
					END
					ELSE
					BEGIN
						DELETE FROM SBSC.Auditor_Certifications
						WHERE AuditorId = @Id
						AND CertificationId NOT IN (SELECT CertificationId FROM @AllCertificationsFromTypes)
						AND IsDefault = 0;
					END
    
					-- Insert only new certifications from the certification types
					INSERT INTO SBSC.Auditor_Certifications (AuditorId, CertificationId, IsDefault)
					SELECT @Id, acft.CertificationId, 0
					FROM @AllCertificationsFromTypes acft
					WHERE NOT EXISTS (
						SELECT 1 
						FROM SBSC.Auditor_Certifications ac 
						WHERE ac.AuditorId = @Id 
						AND ac.CertificationId = acft.CertificationId
					);
				END
				ELSE  
				BEGIN
					-- Check if there are any default certifications that cannot be deleted
					IF EXISTS (SELECT 1 FROM SBSC.Auditor_Certifications
								WHERE AuditorId = @Id
								AND IsDefault = 1)
					BEGIN
						RAISERROR('Auditor has default certifications that cannot be deleted.', 16, 1);
						ROLLBACK TRANSACTION;
						RETURN;
					END
					ELSE
					BEGIN
						-- Remove all auditor-certification assignments (only non-default ones)
						DELETE FROM SBSC.Auditor_Certifications
						WHERE AuditorId = @Id
						AND IsDefault = 0;
					END
				END

			-- Handle Assigned Customers if provided and is valid JSON
				IF @AssignedCustomers IS NOT NULL AND ISJSON(@AssignedCustomers) = 1
				BEGIN
					EXEC sp_execute_remote
						@data_source_name = N'SbscCustomerDataSource',
						@stmt = N'EXEC [SBSC].[sp_CustomerAuditors_DML] @Action, @AuditorId, @AssignedCustomers',
						@params = N'@Action NVARCHAR(20), @AuditorId INT, @AssignedCustomers NVARCHAR(MAX)',
						@Action = 'UPDATE',
						@AuditorId = @Id,
						@AssignedCustomers = @AssignedCustomers;
				END

				EXEC sp_execute_remote
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_CustomerAuditors_DML] @Action, @AuditorId',
					@params = N'@Action NVARCHAR(20), @AuditorId INT',
					@Action = 'ASSIGN_AUDITOR',
					@AuditorId = @Id;
        
			-- Update the UserCredentials table for MFA and email settings
				UPDATE SBSC.UserCredentials
				SET 
					Email = @Email,
					MfaStatus = @MFAStatus,
					IsPasswordChanged = ISNULL(@IsPasswordChanged, IsPasswordChanged),
					PasswordChangedDate = ISNULL(@PasswordChangedDate, PasswordChangedDate),
					DefaultLangId = ISNULL(@DefaultLangId, DefaultLangId)
				WHERE AuditorId = @Id;
        
			COMMIT TRANSACTION;

			-- Convert CertificationIds back to JSON for response
			DECLARE @CertificationsUpdateJson NVARCHAR(MAX);
			SELECT @CertificationsUpdateJson = (
				SELECT CertificateCode
				FROM @CertificationsId cid
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId
				FOR JSON PATH
			);

			-- Return updated values
			SELECT 
				@Id AS Id, 
				@Email AS Email, 
				@Name AS [Name], 
				@CertificationsUpdateJson AS Certifications, 
				@AssignedCustomers AS AssignedCustomers;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
			DECLARE @CatchErrorMessageUpdate NVARCHAR(4000);
			DECLARE @CatchErrorSeverityUpdate INT;
			DECLARE @CatchErrorStateUpdate INT;
			SET @CatchErrorMessageUpdate = ERROR_MESSAGE();
			SET @CatchErrorSeverityUpdate = ERROR_SEVERITY();
			SET @CatchErrorStateUpdate = ERROR_STATE();
			RAISERROR(@CatchErrorMessageUpdate, @CatchErrorSeverityUpdate, @CatchErrorStateUpdate);
		END CATCH;
	END

	


    -- UPDATE_COLUMN operation
    ELSE IF @Action = 'UPDATE_COLUMN'
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM SBSC.Auditor 
            WHERE Id = @Id
        )
        BEGIN
            DECLARE @SQL NVARCHAR(MAX) = 'UPDATE SBSC.AuditorCredentials SET ' + QUOTENAME(@ColumnName) + ' = @NewValue WHERE Id = @Id';
            EXEC sp_executesql @SQL, N'@Id INT, @NewValue NVARCHAR(500)', @Id, @NewValue;

            SELECT 'Column updated successfully.' AS Message;
        END
        ELSE
        BEGIN
            RAISERROR('Auditor with Id %d does not exist.', 16, 1, @Id);
        END
    END

    -- DELETE operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
        
			-- Check if the auditor exists
			DECLARE @Exists INT;
			SELECT @Exists = COUNT(*)
			FROM SBSC.Auditor
			WHERE Id = @Id;

			IF @Exists = 0
			BEGIN
				RAISERROR('Auditor with Id %d does not exist.', 16, 1, @Id);
				ROLLBACK TRANSACTION; -- Rollback in case of non-existence
				RETURN; -- Exit the procedure if the auditor does not exist
			END

			-- Delete related records in the following order:
        
			-- Step 1: Delete from Auditor_Certifications
			IF EXISTS (SELECT 1 FROM SBSC.Auditor_Certifications
							WHERE AuditorId = @Id
							AND IsDefault = 1)
			BEGIN
				RAISERROR('Auditor set as default cannot be deleted.', 16, 1);
                ROLLBACK TRANSACTION;
                RETURN;
			END
			ELSE
			BEGIN
				DELETE FROM SBSC.Auditor_Certifications WHERE AuditorId = @Id;
			END

			-- Step 2: Delete from Customer_Auditors using remote execution
			EXEC sp_execute_remote
				@data_source_name = N'SbscCustomerDataSource',
				@stmt = N'EXEC [SBSC].[sp_CustomerAuditors_DML] @Action, @AuditorId',
				@params = N'@Action NVARCHAR(20), @AuditorId INT',
				@Action = 'DELETE',
				@AuditorId = @Id;


			-- Step 4: Delete from AuditorCredentials
			DELETE FROM SBSC.AuditorCredentials WHERE AuditorId = @Id;

			-- Step 5: Finally, delete from Auditor
			DELETE FROM SBSC.Auditor WHERE Id = @Id;

			COMMIT TRANSACTION;
			SELECT @Id AS Id; -- Return the deleted Auditor Id as confirmation
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			DECLARE @CatchErrorMessageDelete NVARCHAR(4000);
			DECLARE @CatchErrorSeverityDelete INT;
			DECLARE @CatchErrorStateDelete INT;

			SET @CatchErrorMessageDelete = ERROR_MESSAGE();
			SET @CatchErrorSeverityDelete = ERROR_SEVERITY();
			SET @CatchErrorStateDelete = ERROR_STATE();

			RAISERROR(@CatchErrorMessageDelete, @CatchErrorSeverityDelete, @CatchErrorStateDelete);
		END CATCH;
	END
END
GO