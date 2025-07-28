SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_AssignmentOccasions]
    @Action NVARCHAR(100),
	@CustomerId INT = NULL,
	@DepartmentId INT = NULL,
	@DepartmentName NVARCHAR(100) = NULL,
	@FromDate DATE = NULL,
	@ToDate DATE = NULL,
	@Status SMALLINT = NULL, -- 11 status for default upcomming certifications
	@CertificationId INT = NULL,
	@AuditorId INT = NULL,
	@SortColumn NVARCHAR(MAX) = 'CustomerId',
	@SortDirection NVARCHAR(5) = 'ASC',
	@IsDecided BIT = NULL,
	@IsOnlineCertification BIT = 0,

	@AssignmentId INT = NULL,
	--auditor assignment for offline, tilfalle
	@AssignmentsCertificationList [SBSC].[AssignCertificationList_V2] READONLY,
	@AssignmentsAuditors [SBSC].[AssignAuditorList_V2] READONLY
AS
BEGIN
    SET NOCOUNT ON;

	DECLARE @CatchErrorMessage NVARCHAR(MAX) = NULL;
    DECLARE @CatchErrorSeverity NVARCHAR(MAX) = NULL;
    DECLARE @CatchErrorState NVARCHAR(MAX) = NULL;

    -- Validate the Action parameter
    IF @Action NOT IN ('ASSIGN_AUDITOR', 'ASSIGN_AUDITOR_V2', 'ASSIGN_DEFAULT_AUDITOR', 'READ_ASSIGNED_AUDITORS_V2', 'READ_ASSIGNED_AUDITORS_LIST', 'UPDATE_AUDITOR', 'UPDATE_AUDITOR_V2', 'DELETE_ASSIGNED_AUDITORS_V2', 'GET_ASSIGN_AUDITORS_META_DATA_V2', 'VALIDATE_VALID_ASSIGNMENTS', 'GET_CERTIFICATIONS', 'READ_ALL_CERTIFICATIONS')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use ASSIGN_AUDITOR, ASSIGN_AUDITOR_V2, ASSIGN_DEFAULT_AUDITOR, READ_ASSIGNED_AUDITORS_V2, UPDATE_AUDITOR_V2, DELETE_ASSIGNED_AUDITORS_V2, GET_ASSIGN_AUDITORS_META_DATA_V2, VALIDATE_VALID_ASSIGNMENTS, GET_CERTIFICATIONS, READ_ALL_CERTIFICATIONS', 16, 1);
        RETURN;
    END

	DECLARE @NewAssignmentId INT = NULL;

	IF @Action = 'ASSIGN_AUDITOR_V2'
	BEGIN
		BEGIN TRANSACTION;
		BEGIN TRY
			DECLARE @NewAssignmentOccasionId INT;
			DECLARE @NewCustomerCertificationAssignmentId INT;
			DECLARE @NewAddressId INT;
			DECLARE @NewDepartmentId INT;
			DECLARE @NewCustomerCertificationDetailsId INT;
			
			IF @Status IS NULL
			BEGIN
				SET @Status = 11;
			END
				
			-- Handle Department creation if needed
			IF @DepartmentName IS NOT NULL
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)))
				BEGIN
					INSERT INTO SBSC.Customer_Department(CustomerId, DepartmentName)
					VALUES(@CustomerId, @DepartmentName);
					SELECT @NewDepartmentId = SCOPE_IDENTITY();
				END
				ELSE
				BEGIN
					SET @NewDepartmentId = (SELECT Id FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)));
				END
			END

			IF @DepartmentId IS NOT NULL
			BEGIN
				SET @NewDepartmentId = @DepartmentId;
			END

			-- Step 1: Create new Assignment Occasion (Remove Status column as per schema update)
			INSERT INTO SBSC.AssignmentOccasions (FromDate, ToDate, AssignedTime, CustomerId, Status, LastUpdatedDate)
			VALUES (@FromDate, @ToDate, GETUTCDATE(), @CustomerId, @Status, GETUTCDATE());
			SET @NewAssignmentOccasionId = SCOPE_IDENTITY();

			-- Step 2: Insert Auditors with reference to Assignment Occasion
			INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			SELECT 
				@NewAssignmentOccasionId,
				AuditorId,
				IsLeadAuditor
			FROM @AssignmentsAuditors;

			-- Step 3: Process each certification in the list
			DECLARE @CustomerCertificationId INT;
			DECLARE @AddressName NVARCHAR(MAX);
			DECLARE @AddressId INT;
			DECLARE @Recertification INT;

			DECLARE cert_cursor CURSOR FOR
			SELECT CertificationId, Address, AddressId, Recertification
			FROM @AssignmentsCertificationList;

			OPEN cert_cursor;
			FETCH NEXT FROM cert_cursor INTO @CertificationId, @AddressName, @AddressId, @Recertification;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Handle Address creation/selection
				SET @NewAddressId = NULL;
            
				IF @AddressId IS NOT NULL AND @AddressId > 0
				BEGIN
					-- Verify the AddressId exists for this customer
					IF EXISTS (SELECT 1 FROM SBSC.Customer_Address WHERE Id = @AddressId AND CustomerId = @CustomerId)
					BEGIN
						SET @NewAddressId = @AddressId;
					END
				END

				-- If no valid AddressId, create new address using Address name
				IF @NewAddressId IS NULL AND @AddressName IS NOT NULL AND TRIM(@AddressName) != ''
				BEGIN
					-- Check if address already exists for this customer
					SELECT @NewAddressId = Id
					FROM SBSC.Customer_Address
					WHERE CustomerId = @CustomerId AND TRIM(LOWER(City)) = TRIM(LOWER(@AddressName));

					-- If address doesn't exist, create it
					IF @NewAddressId IS NULL
					BEGIN
						INSERT INTO SBSC.Customer_Address (CustomerId, City)
						VALUES (@CustomerId, @AddressName);
						SET @NewAddressId = SCOPE_IDENTITY();
					END
				END

				-- Step 4: Get the CustomerCertificationId
				SELECT @CustomerCertificationId = CustomerCertificationId 
				FROM SBSC.Customer_Certifications 
				WHERE CustomerId = @CustomerId AND CertificateId = @CertificationId;

				IF @CustomerCertificationId IS NULL
				BEGIN
				    RAISERROR('Invalid certification Id for Customer %d and Certificate %d', 16, 1, @CustomerId, @CertificationId);
					ROLLBACK TRANSACTION;
					RETURN;
				END

				-- Step 5: Check if CustomerCertificationDetails already exists for this combination
				SET @NewCustomerCertificationDetailsId = NULL;
				
				SELECT @NewCustomerCertificationDetailsId = Id
				FROM SBSC.CustomerCertificationDetails
				WHERE CustomerCertificationId = @CustomerCertificationId
					AND (@NewDepartmentId IS NULL OR DepartmentId = @NewDepartmentId)
					AND (@NewAddressId IS NULL OR AddressId = @NewAddressId)
					AND Recertification = ISNULL(@Recertification, 0);

				-- If combination already exists, throw error
				IF @NewCustomerCertificationDetailsId IS NULL
				BEGIN
					-- Step 6: Create new CustomerCertificationDetails record
					INSERT INTO SBSC.CustomerCertificationDetails (
						CustomerCertificationId,
						AddressId,
						DepartmentId,
						Recertification,
						Status,
						CreatedDate
					)
					VALUES(
						@CustomerCertificationId,
						@NewAddressId,
						@NewDepartmentId,
						ISNULL(@Recertification, 0),
						@Status,
						GETDATE()
					);
					SET @NewCustomerCertificationDetailsId = SCOPE_IDENTITY();
				END

				-- Step 7: Update the status of customer_certifications 
				UPDATE SBSC.Customer_Certifications
				SET SubmissionStatus = @Status
				WHERE CustomerCertificationId = @CustomerCertificationId;

				-- Step 8: Insert into AssignmentCustomerCertification 
				INSERT INTO SBSC.AssignmentCustomerCertification (
					AssignmentId,
					CustomerCertificationDetailsId,
					CustomerCertificationId,
					Recertification
				)
				VALUES (
					@NewAssignmentOccasionId,
					@NewCustomerCertificationDetailsId,
					@CustomerCertificationId,
					@Recertification
				);

				SET @NewCustomerCertificationAssignmentId = SCOPE_IDENTITY();

				FETCH NEXT FROM cert_cursor INTO @CertificationId, @AddressName, @AddressId, @Recertification;
			END

			CLOSE cert_cursor;
			DEALLOCATE cert_cursor;

			COMMIT TRANSACTION;

			-- Return structured JSON response (Updated to reflect new schema)
			DECLARE @JsonResponse NVARCHAR(MAX);
				
			SELECT @JsonResponse = (
				SELECT 
					ao.Id AS AssignmentId,
					ao.CustomerId,
					@Status AS Status,
					CONVERT(DATE, ao.FromDate) AS FromDate,
					CONVERT(DATE, ao.ToDate) AS ToDate,
					CONVERT(DATETIME, ao.AssignedTime) AS AssignedTime,
					-- Auditors array
					(SELECT aa.AuditorId, a.Name
						FROM SBSC.AssignmentAuditor aa
						INNER JOIN SBSC.Auditor a ON a.Id = aa.AuditorId
						WHERE aa.AssignmentId = ao.Id 
						FOR JSON PATH) AS Auditors,
					-- Assignments array (Updated to use CustomerCertificationDetails)
					(SELECT 
						cc.CertificateId AS CertificationId,
						ccd.CustomerCertificationId AS CustomerCertificationId,
						acc.CustomerCertificationDetailsId,
						ct.CertificateCode AS CertificationCode,
						ccd.Status AS Status,
						ISNULL(ca.City, ca.Placename) AS Address,
						ccd.AddressId,
						ccd.DepartmentId,
						ccd.Recertification
						FROM SBSC.AssignmentCustomerCertification acc
						INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
						INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId
						LEFT JOIN SBSC.Certification ct ON cc.CertificateId = ct.Id
						LEFT JOIN SBSC.Customer_Address ca ON ccd.AddressId = ca.Id
						WHERE acc.AssignmentId = ao.Id
						FOR JSON PATH) AS Assignments
				FROM SBSC.AssignmentOccasions ao
				WHERE ao.Id = @NewAssignmentOccasionId
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			);

			-- Return the JSON response
			SELECT @JsonResponse AS AuditorOccasionAssignments;

		END TRY
		BEGIN CATCH
			-- Error handling
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END

			-- Return error information
			SELECT 
				ERROR_NUMBER() AS ErrorNumber,
				ERROR_SEVERITY() AS ErrorSeverity,
				ERROR_STATE() AS ErrorState,
				ERROR_MESSAGE() AS ErrorMessage,
				'FAILED' AS Status;

			-- Optionally re-throw the error
			THROW;
		END CATCH
	END


	ELSE IF @Action = 'UPDATE_AUDITOR_V2'
	BEGIN
		BEGIN TRANSACTION;
		BEGIN TRY
			DECLARE @NewDepartmentIdUpdate INT;
			DECLARE @NewAddressIdUpdate INT;
			DECLARE @NewCustomerCertificationDetailsIdUpdate INT;
			
			-- Step 1: Update AssignmentOccasions basic info (Removed Status and DepartmentId columns)
			UPDATE SBSC.AssignmentOccasions 
			SET FromDate = @FromDate,
				ToDate = @ToDate,
				AssignedTime = GETUTCDATE(),
				Status = @Status,
				LastUpdatedDate = GETUTCDATE()
			WHERE Id = @AssignmentId;

			-- Handle Department creation if needed
			IF @DepartmentName IS NOT NULL
			BEGIN
				IF NOT EXISTS (SELECT 1 FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)))
				BEGIN
					INSERT INTO SBSC.Customer_Department(CustomerId, DepartmentName)
					VALUES(@CustomerId, @DepartmentName);
					SELECT @NewDepartmentIdUpdate = SCOPE_IDENTITY();
				END
				ELSE
				BEGIN
					SET @NewDepartmentIdUpdate = (SELECT Id FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)));
				END
			END

			IF @DepartmentId IS NOT NULL
			BEGIN
				SET @NewDepartmentIdUpdate = @DepartmentId;
			END

			-- Step 2: Delete existing related records (Only delete AssignmentCustomerCertification)
			
			-- Delete only the assignment relationships, not the certification details themselves
			DELETE FROM SBSC.AssignmentCustomerCertification 
			WHERE AssignmentId = @AssignmentId;

			-- Delete AssignmentAuditor records
			DELETE FROM SBSC.AssignmentAuditor 
			WHERE AssignmentId = @AssignmentId;

			-- Step 3: Insert new Auditors with reference to Assignment Occasion
			INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			SELECT 
				@AssignmentId,
				AuditorId,
				IsLeadAuditor
			FROM @AssignmentsAuditors;

			-- Step 4: Process each certification in the list
			DECLARE @CertificationIdUpdate INT;
			DECLARE @CustomerCertificationIdUpdate INT;
			DECLARE @AddressNameUpdate NVARCHAR(MAX);
			DECLARE @AddressIdUpdate INT;
			DECLARE @RecertificationUpdate INT;

			DECLARE cert_cursor CURSOR FOR
			SELECT CertificationId, Address, AddressId, Recertification
			FROM @AssignmentsCertificationList;

			OPEN cert_cursor;
			FETCH NEXT FROM cert_cursor INTO @CertificationIdUpdate, @AddressNameUpdate, @AddressIdUpdate, @RecertificationUpdate;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				-- Handle Address creation/selection
				SET @NewAddressIdUpdate = NULL;
            
				IF @AddressIdUpdate IS NOT NULL AND @AddressIdUpdate > 0
				BEGIN
					-- Verify the AddressId exists for this customer
					IF EXISTS (SELECT 1 FROM SBSC.Customer_Address WHERE Id = @AddressIdUpdate AND CustomerId = @CustomerId)
					BEGIN
						SET @NewAddressIdUpdate = @AddressIdUpdate;
					END
				END

				-- If no valid AddressId, create new address using Address name
				IF @NewAddressIdUpdate IS NULL AND @AddressNameUpdate IS NOT NULL AND TRIM(@AddressNameUpdate) != ''
				BEGIN
					-- Check if address already exists for this customer
					SELECT @NewAddressIdUpdate = Id
					FROM SBSC.Customer_Address
					WHERE CustomerId = @CustomerId AND TRIM(LOWER(City)) = TRIM(LOWER(@AddressNameUpdate));

					-- If address doesn't exist, create it
					IF @NewAddressIdUpdate IS NULL
					BEGIN
						INSERT INTO SBSC.Customer_Address (CustomerId, City)
						VALUES (@CustomerId, @AddressNameUpdate);
						SET @NewAddressIdUpdate = SCOPE_IDENTITY();
					END
				END

				-- Step 5: Get the CustomerCertificationId
				SELECT @CustomerCertificationIdUpdate = CustomerCertificationId 
				FROM SBSC.Customer_Certifications 
				WHERE CustomerId = @CustomerId AND CertificateId = @CertificationIdUpdate;

				IF @CustomerCertificationIdUpdate IS NULL
				BEGIN
				    RAISERROR('Invalid certification Id for Customer %d and Certificate %d', 16, 1, @CustomerId, @CertificationIdUpdate);
					ROLLBACK TRANSACTION;
					RETURN;
				END

				-- Step 6: Check if CustomerCertificationDetails already exists for this combination
				SET @NewCustomerCertificationDetailsIdUpdate = NULL;
				
				SELECT @NewCustomerCertificationDetailsIdUpdate = Id
				FROM SBSC.CustomerCertificationDetails
				WHERE CustomerCertificationId = @CustomerCertificationIdUpdate
					AND (@NewDepartmentIdUpdate IS NULL OR DepartmentId = @NewDepartmentIdUpdate)
					AND (@NewAddressIdUpdate IS NULL OR AddressId = @NewAddressIdUpdate)
					AND Recertification = ISNULL(@RecertificationUpdate, 0);

				-- If combination doesn't exist, create new CustomerCertificationDetails record
				IF @NewCustomerCertificationDetailsIdUpdate IS NULL
				BEGIN
					INSERT INTO SBSC.CustomerCertificationDetails (
						CustomerCertificationId,
						AddressId,
						DepartmentId,
						Recertification,
						Status,
						CreatedDate
					)
					VALUES(
						@CustomerCertificationIdUpdate,
						@NewAddressIdUpdate,
						@NewDepartmentIdUpdate,
						ISNULL(@RecertificationUpdate, 0),
						@Status,
						GETDATE()
					);
					SET @NewCustomerCertificationDetailsIdUpdate = SCOPE_IDENTITY();
				END
				ELSE
				BEGIN
					-- Update existing CustomerCertificationDetails record if needed
					UPDATE SBSC.CustomerCertificationDetails
					SET Status = @Status,
						AddressId = @NewAddressIdUpdate,
						DepartmentId = @NewDepartmentIdUpdate
					WHERE Id = @NewCustomerCertificationDetailsIdUpdate;
				END

				-- Step 7: Update the status of customer_certifications
				UPDATE SBSC.Customer_Certifications
				SET SubmissionStatus = @Status
				WHERE CustomerCertificationId = @CustomerCertificationIdUpdate;

				-- Step 8: Insert into AssignmentCustomerCertification (Updated structure)
				INSERT INTO SBSC.AssignmentCustomerCertification (
					AssignmentId,
					CustomerCertificationDetailsId,
					CustomerCertificationId,
					Recertification
				)
				VALUES (
					@AssignmentId,
					@NewCustomerCertificationDetailsIdUpdate,
					@CustomerCertificationIdUpdate,
					@RecertificationUpdate
				);

				
				FETCH NEXT FROM cert_cursor INTO @CertificationIdUpdate, @AddressNameUpdate, @AddressIdUpdate, @RecertificationUpdate;
			END

			CLOSE cert_cursor;
			DEALLOCATE cert_cursor;

			COMMIT TRANSACTION;

			-- Return structured JSON response (Updated to reflect new schema)
			DECLARE @JsonResponseUpdate NVARCHAR(MAX);
				
			SELECT @JsonResponseUpdate = (
				SELECT 
					ao.Id AS AssignmentId,
					ao.CustomerId,
					@Status AS Status,
					CONVERT(DATE, ao.FromDate) AS FromDate,
					CONVERT(DATE, ao.ToDate) AS ToDate,
					CONVERT(DATETIME, ao.AssignedTime) AS AssignedTime,
					-- Auditors array
					(SELECT aa.AuditorId, a.Name
						FROM SBSC.AssignmentAuditor aa
						INNER JOIN SBSC.Auditor a ON a.Id = aa.AuditorId
						WHERE aa.AssignmentId = ao.Id 
						FOR JSON PATH) AS Auditors,
					-- Assignments array (Updated to use CustomerCertificationDetails)
					(SELECT 
						cc.CertificateId AS CertificationId,
						ccd.CustomerCertificationId,
						acc.CustomerCertificationDetailsId,
						ct.CertificateCode AS CertificationCode,
						ccd.Status AS Status,
						ISNULL(ca.City, ca.Placename) AS Address,
						ccd.AddressId,
						ccd.DepartmentId,
						ccd.Recertification
						FROM SBSC.AssignmentCustomerCertification acc
						INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
						INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId
						LEFT JOIN SBSC.Certification ct ON cc.CertificateId = ct.Id
						LEFT JOIN SBSC.Customer_Address ca ON ccd.AddressId = ca.Id
						WHERE acc.AssignmentId = ao.Id
						FOR JSON PATH) AS Assignments
				FROM SBSC.AssignmentOccasions ao
				WHERE ao.Id = @AssignmentId
				FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
			);

			-- Return the JSON response
			SELECT @JsonResponseUpdate AS AuditorOccasionAssignments;

		END TRY
		BEGIN CATCH
			-- Error handling
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END

			-- Return error information
			SELECT 
				ERROR_NUMBER() AS ErrorNumber,
				ERROR_SEVERITY() AS ErrorSeverity,
				ERROR_STATE() AS ErrorState,
				ERROR_MESSAGE() AS ErrorMessage,
				'FAILED' AS Status;

			-- Optionally re-throw the error
			THROW;
		END CATCH
	END

	ELSE IF @Action = 'READ_ASSIGNED_AUDITORS_V2'
	BEGIN
		-- Validate that either CustomerId or AuditorId is provided
		IF @CustomerId IS NULL AND @AuditorId IS NULL AND @AssignmentId IS NULL
		BEGIN
			RAISERROR ('Error: Either CustomerId or AuditorId or AssignmentId is required for READ_ASSIGNED_AUDITORS action.', 16, 1);
			RETURN;
		END

		IF @AuditorId IS NOT NULL
		BEGIN
			DECLARE @IsSBSCAuditor BIT = 0;
			SET @IsSBSCAuditor = (SELECT IsSBSCAuditor FROM SBSC.Auditor WHERE Id = @AuditorId);
		END

		-- Generate JSON response as a list of GetAssignedAuditor_V2 objects
		DECLARE @ReadJsonResponse NVARCHAR(MAX);
			
		SELECT @ReadJsonResponse = (
			SELECT DISTINCT
				ao.Id AS AssignmentId,
				ao.CustomerId,
				c.CustomerName,
				c.CompanyName,
				c.CaseId,
				c.CaseNumber,
				ao.Status,
				ccd.DepartmentId,
				cd.DepartmentName,
				CONVERT(DATE, ao.FromDate) AS FromDate,
				CONVERT(DATE, ao.ToDate) AS ToDate,
				CONVERT(DATETIME, ao.AssignedTime) AS AssignedTime,
				ao.LastUpdatedDate,
				CAST(CASE 
					WHEN EXISTS (SELECT 1 FROM SBSC.CustomerCertificationDetails 
								WHERE UpdatedByAuditor = 1 
								AND Id IN (SELECT CustomerCertificationDetailsId 
											FROM SBSC.AssignmentCustomerCertification
											WHERE AssignmentId = ao.Id))
					THEN 1
					ELSE 0
				END AS BIT)AS UpdatedByAuditor,
				CAST(CASE 
					WHEN EXISTS (SELECT 1 FROM SBSC.CustomerCertificationDetails 
								WHERE UpdatedByCustomer = 1 
								AND Id IN (SELECT CustomerCertificationDetailsId 
											FROM SBSC.AssignmentCustomerCertification
											WHERE AssignmentId = ao.Id))
					THEN 1
					ELSE 0
				END AS BIT)AS UpdatedByCustomer,
				-- Auditors array for this assignment
					(SELECT aa.AuditorId, a.Name, CAST(aa.IsLeadAuditor AS bit) AS IsLeadAuditor, ac.Email, ac.DefaultLangId
						FROM SBSC.AssignmentAuditor aa
						INNER JOIN SBSC.Auditor a ON a.Id = aa.AuditorId
						INNER JOIN SBSC.AuditorCredentials ac ON ac.AuditorId = aa.AuditorId 
						WHERE aa.AssignmentId = ao.Id 
						FOR JSON PATH) AS Auditors,
				-- Assignments array for this assignment occasion (Updated to use CustomerCertificationDetails)
				(SELECT 
					cc_inner.CertificateId AS CertificationId,
					ccd_inner.CustomerCertificationId,
					acc_inner.CustomerCertificationDetailsId,
					ct.CertificateCode AS CertificationCode,
					ccd_inner.Status AS Status,
					ISNULL(ca.City, ca.Placename) AS Address,
					ccd_inner.AddressId,
					ccd_inner.DepartmentId,
					ccd_inner.Recertification,
					cc_inner.AuditYears,
					ct.IsAuditorInitiated,
					YEAR(cc_inner.CreatedDate) AS BaseYear,
					ISNULL(ccd_inner.UpdatedByAuditor, 0) AS UpdatedByAuditor,
					ISNULL(ccd_inner.UpdatedByCustomer, 0) AS UpdatedByCustomer,
					(SELECT COUNT(DISTINCT Id) 
					FROM SBSC.CustomerResponse 
					WHERE CustomerId = cc_inner.CustomerId 
					AND RequirementId IN (
							SELECT RequirementId 
							FROM SBSC.RequirementChapters 
							WHERE ChapterId IN (
									SELECT Id 
									FROM SBSC.Chapter 
									WHERE CertificationId = cc_inner.CertificateId)))  AS ResponseCount,
					(SELECT COUNT(DISTINCT Id) 
					FROM SBSC.Requirement 
					WHERE Id IN (
							SELECT RequirementId 
							FROM SBSC.RequirementChapters 
							WHERE ChapterId IN (
									SELECT Id 
									FROM SBSC.Chapter 
									WHERE CertificationId = cc_inner.CertificateId)))  AS RequirementCount
					FROM SBSC.AssignmentCustomerCertification acc_inner
					INNER JOIN SBSC.CustomerCertificationDetails ccd_inner ON acc_inner.CustomerCertificationDetailsId = ccd_inner.Id
					INNER JOIN SBSC.Customer_Certifications cc_inner ON ccd_inner.CustomerCertificationId = cc_inner.CustomerCertificationId
					LEFT JOIN SBSC.Certification ct ON cc_inner.CertificateId = ct.Id
					LEFT JOIN SBSC.Customer_Address ca ON ccd_inner.AddressId = ca.Id
					WHERE acc_inner.AssignmentId = ao.Id
					AND (@CertificationId IS NULL OR cc_inner.CertificateId = @CertificationId)
					AND (@Status IS NULL OR ccd_inner.Status = @Status)
					FOR JSON PATH) AS Assignments
			FROM SBSC.AssignmentOccasions ao
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON acc.AssignmentId = ao.Id
			INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
			LEFT JOIN SBSC.Customer_Department cd ON ccd.DepartmentId = cd.Id
			INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId
			LEFT JOIN SBSC.AssignmentAuditor aa_filter ON aa_filter.AssignmentId = ao.Id -- Add JOIN for AuditorId filtering
			INNER JOIN SBSC.Customers c ON ao.CustomerId = c.Id
			WHERE (@AssignmentId IS NULL OR ao.Id = @AssignmentId)
				-- Filter by CustomerId or auditorId if provided
				AND (@CustomerId IS NULL OR ao.CustomerId = @CustomerId)
				AND (@AuditorId IS NULL OR aa_filter.AuditorId = @AuditorId OR @IsSBSCAuditor = 1)
				AND (@CertificationId IS NULL OR cc.CertificateId = @CertificationId) -- Additional filters
				AND (@Status IS NULL OR ccd.Status = @Status)
				AND (
					(@IsDecided IS NULL OR @IsDecided = 1  
					OR (@IsDecided = 0 AND ao.Status NOT IN (4, 5, 6, 11))
				))
			GROUP BY ao.Id, ao.CustomerId, ao.FromDate, ao.ToDate, ao.AssignedTime, ao.LastUpdatedDate, ao.Status, ccd.DepartmentId, c.CustomerName, c.CompanyName, c.CaseId, c.CaseNumber, cd.DepartmentName
			ORDER BY ao.LastUpdatedDate DESC
			FOR JSON PATH
		);
		
		-- Handle empty result
		IF @ReadJsonResponse IS NULL
		BEGIN
			SET @ReadJsonResponse = '[]';
		END

		-- Return the JSON response
		SELECT @ReadJsonResponse AS AuditorOccasionAssignments;

		--second result: total deviation (Updated to use CustomerCertificationDetails)
		SELECT Count(acr.IsApproved) AS TotalDeviation
		FROM SBSC.AuditorCustomerResponses acr
		JOIN SBSC.CustomerResponse cr ON cr.Id = acr.CustomerResponseId
		JOIN SBSC.RequirementChapters rc ON rc.RequirementId = cr.RequirementId
		JOIN SBSC.Chapter c ON c.Id = rc.ChapterId
		JOIN SBSC.Customer_Certifications cc ON cc.CertificateId = c.CertificationId
		JOIN SBSC.AssignmentCustomerCertification acc ON acc.CustomerCertificationId = cc.CustomerCertificationId
		JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
		WHERE cr.CustomerId = @CustomerId
		AND acc.AssignmentId = @AssignmentId
		AND acr.IsApproved != 1
		AND cr.Recertification = ccd.Recertification

	END

	ELSE IF @Action = 'DELETE_ASSIGNED_AUDITORS_V2'
	BEGIN
	    BEGIN TRY
	        BEGIN TRANSACTION;
        
	        -- Validate CustomerCertificationId
	        IF @AssignmentId IS NULL OR @AssignmentId <= 0
	        BEGIN
	            RAISERROR('Invalid or missing assignmentId.', 16, 1);
	            RETURN;
	        END

			DELETE FROM SBSC.AssignmentOccasions
	        WHERE Id = @AssignmentId

	        COMMIT TRANSACTION;

	        -- Return success message
	        SELECT @AssignmentId AS DeletedCustomerCertificationId;
	    END TRY
	    BEGIN CATCH
	        -- Rollback transaction in case of error
	        IF @@TRANCOUNT > 0
	            ROLLBACK TRANSACTION;

	        SET @CatchErrorMessage = ERROR_MESSAGE();
	        SET @CatchErrorSeverity = ERROR_SEVERITY();
	        SET @CatchErrorState = ERROR_STATE();

	        RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState);
	    END CATCH;
	END

	ELSE IF @Action = 'GET_ASSIGN_AUDITORS_META_DATA_V2'
	BEGIN
		IF @CustomerId IS NULL
		BEGIN
			RAISERROR ('Error: CustomerId is required to get assign auditor meta data.', 16, 1);
			RETURN;
		END
		DECLARE @ReadMetaDataJsonResponse NVARCHAR(MAX);
			
		SELECT @ReadMetaDataJsonResponse = (
			SELECT 
				-- customers array
				(SELECT 
								c.Id AS CustomerId,
								c.CustomerName
				FROM SBSC.Customers c
				WHERE c.Id = @CustomerId
				FOR JSON PATH) AS Customers,
				-- Departments array
				(SELECT 
					cd.Id AS DepartmentId,
					cd.DepartmentName
				FROM SBSC.Customer_Department cd
				WHERE cd.CustomerId = @CustomerId
				FOR JSON PATH) AS Departments,
				
				-- Auditors array (combining Customer_Auditors, Auditor_Certifications, and AssignmentAuditor)
				(SELECT DISTINCT
					a.Id AS AuditorId,
					a.Name
				FROM (
					-- Get auditors directly assigned to customer
					SELECT DISTINCT ca.AuditorId
					FROM SBSC.Customer_Auditors ca
					WHERE ca.CustomerId = @CustomerId
					
					UNION
					
					-- Get auditors certified for customer's certifications
					SELECT DISTINCT ac.AuditorId
					FROM SBSC.Auditor_Certifications ac
					INNER JOIN SBSC.Customer_Certifications cc ON ac.CertificationId = cc.CertificateId
					WHERE cc.CustomerId = @CustomerId 
					--AND ac.IsDefault = 1
					
					UNION
					
					-- Get auditors already assigned to customer through assignments
					SELECT DISTINCT aa.AuditorId
					FROM SBSC.AssignmentAuditor aa 
					INNER JOIN SBSC.AssignmentOccasions ao ON aa.AssignmentId = ao.Id
					WHERE ao.CustomerId = @CustomerId
				) auditor_ids
				INNER JOIN SBSC.Auditor a ON auditor_ids.AuditorId = a.Id
				FOR JSON PATH) AS Auditors,
				
				-- Certifications array
				(SELECT 
					cc.CertificateId AS CertificationId,
					c.CertificateCode AS CertificationCode,
					cc.Recertification,
					ISNULL(cc.AuditYears, c.AuditYears) AS AuditYears,
					ISNULL(cc.IssueDate, cc.CreatedDate) AS CertificationStartDate,
					(SELECT DISTINCT
						ccd.Id AS CustomerCertificationDetailsId,
						ccd.AddressId,
						ISNULL(ca.City, ca.PlaceName) AS AddressCity,
						ccd.DepartmentId,
						cd.DepartmentName,
						ccd.Recertification
					FROM SBSC.CustomerCertificationDetails ccd
					INNER JOIN SBSC.Customer_Address ca ON ccd.AddressId = ca.Id
					INNER JOIN SBSC.Customer_Department cd ON ccd.DepartmentId = cd.Id
					INNER JOIN (
						SELECT 
							AddressId,
							DepartmentId,
							MAX(Recertification) AS MaxRecertification
						FROM SBSC.CustomerCertificationDetails
						WHERE CustomerCertificationId = cc.CustomerCertificationId
						GROUP BY AddressId, DepartmentId
					) max_combo ON ccd.AddressId = max_combo.AddressId 
								AND ccd.DepartmentId = max_combo.DepartmentId 
								AND ccd.Recertification = max_combo.MaxRecertification
					WHERE ccd.CustomerCertificationId = cc.CustomerCertificationId
					FOR JSON PATH) AS CustomerCertificationDetailsPastData
				FROM SBSC.Customer_Certifications cc
				INNER JOIN SBSC.Certification c ON c.Id = cc.CertificateId
				WHERE cc.CustomerId = @CustomerId
				AND c.IsAuditorInitiated = CASE 
					WHEN @IsOnlineCertification = 0 THEN 1 
					WHEN @IsOnlineCertification = 1 THEN 0 
					ELSE c.IsAuditorInitiated 
				END
				FOR JSON PATH) AS Certifications,

				-- Addresses array
				(SELECT 
					ca.Id AS AddressId,
					ISNULL(ca.City, ca.Placename) AS Address
				FROM SBSC.Customer_Address ca
				WHERE ca.CustomerId = @CustomerId
				FOR JSON PATH) AS Addresses
			FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
		);
		
		IF @ReadMetaDataJsonResponse IS NULL
		BEGIN
			SET @ReadMetaDataJsonResponse = '{"Customers":[],"Departments":[],"Auditors":[],"Certifications":[],"Addresses":[]}';
		END
		
		-- Return the JSON response
		SELECT @ReadMetaDataJsonResponse AS AssignAuditorsMetaData;
	END

	ELSE IF @Action = 'VALIDATE_VALID_ASSIGNMENTS'
	BEGIN
		IF @CustomerId IS NULL
		BEGIN
			RAISERROR ('Error: CustomerId is required to get assign auditor meta data.', 16, 1);
			RETURN;
		END
            
		-- Handle Department creation if needed
		IF @DepartmentName IS NOT NULL AND @DepartmentId IS NULL
		BEGIN
			BEGIN
				SET @DepartmentId = (SELECT Id FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)));
			END
		END

		DECLARE @CursorAddressName NVARCHAR(255); -- Separate variable for cursor
    
		DECLARE cert_cursor CURSOR FOR
		SELECT CertificationId, Address, AddressId, Recertification
		FROM @AssignmentsCertificationList;

		OPEN cert_cursor;
		FETCH NEXT FROM cert_cursor INTO @CertificationId, @CursorAddressName, @AddressId, @Recertification;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Handle Address creation/selection
			SET @NewAddressId = NULL;
        
			IF @AddressId IS NOT NULL AND @AddressId > 0
			BEGIN
				-- Verify the AddressId exists for this customer
				IF EXISTS (SELECT 1 FROM SBSC.Customer_Address WHERE Id = @AddressId AND CustomerId = @CustomerId)
				BEGIN
					SET @NewAddressId = @AddressId;
				END
			END

			-- If no valid AddressId, select from using Address name
			IF @NewAddressId IS NULL AND @CursorAddressName IS NOT NULL AND TRIM(@CursorAddressName) != ''
			BEGIN
				SELECT @NewAddressId = Id
				FROM SBSC.Customer_Address
				WHERE CustomerId = @CustomerId AND TRIM(LOWER(City)) = TRIM(LOWER(@CursorAddressName));
			END

			-- VALIDATION LOGIC HERE 
			DECLARE @ExistingAssignmentId INT;
			DECLARE @ExistingFromDate DATETIME;
			DECLARE @ExistingToDate DATETIME;
			DECLARE @ValidationErrors NVARCHAR(MAX) = '';

			-- Get the address name for error message (separate variable)
			DECLARE @CurrentAddressName NVARCHAR(255);
			SELECT @CurrentAddressName = City 
			FROM SBSC.Customer_Address 
			WHERE Id = @NewAddressId AND CustomerId = @CustomerId;

			-- Check for existing assignment with same combination AND date overlap
			SELECT TOP 1 
				@ExistingAssignmentId = ao.Id,
				@ExistingFromDate = ao.FromDate,
				@ExistingToDate = ao.ToDate
			FROM SBSC.AssignmentOccasions ao
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON acc.AssignmentId = ao.Id
			INNER JOIN SBSC.CustomerCertificationDetails ccd ON ccd.Id = acc.CustomerCertificationDetailsId
			INNER JOIN SBSC.Customer_Certifications cc ON cc.CustomerCertificationId = ccd.CustomerCertificationId
			WHERE ao.CustomerId = @CustomerId 
				AND ccd.DepartmentId = @DepartmentId
				AND cc.CertificateId = @CertificationId
				AND ccd.Recertification = @Recertification
				AND ccd.AddressId = @NewAddressId
				AND (@AssignmentId IS NULL OR ao.Id != @AssignmentId);

			-- If combination exists with date overlap, accumulate error
			IF @ExistingAssignmentId IS NOT NULL
			BEGIN
				SET @ValidationErrors = @ValidationErrors + 
					'Occasion has already been created for ' + ISNULL(@CurrentAddressName, 'this location') + 
					' from ' + FORMAT(@ExistingFromDate, 'yyyy-MM-dd') + 
					' to ' + FORMAT(@ExistingToDate, 'yyyy-MM-dd') + '; ';
			END

			-- If there are validation errors, raise them
			IF @ValidationErrors != ''
			BEGIN
				RAISERROR (@ValidationErrors, 16, 1);
				RETURN;
			END

			FETCH NEXT FROM cert_cursor INTO @CertificationId, @CursorAddressName, @AddressId, @Recertification;
		END

		CLOSE cert_cursor;
		DEALLOCATE cert_cursor;
	END

	IF @Action = 'GET_CERTIFICATIONS'
	BEGIN
		SELECT DISTINCT CertificateId FROM SBSC.Customer_Certifications WHERE CustomerCertificationId IN ( SELECT CustomerCertificationId FROM SBSC.AssignmentCustomerCertification WHERE AssignmentId = @AssignmentId)
	END

	IF @Action = 'READ_ALL_CERTIFICATIONS'
	BEGIN
		DECLARE @sql NVARCHAR(MAX);

		SET @SortColumn = 'LastUpdatedDate';
		SET @SortDirection = 'DESC'
    
		SET @sql = N'
		SELECT DISTINCT
			ao.Id AS AssignmentId,
			c.Id AS CustomerId,
			c.CompanyName,
			cert.Id AS CertificationId,
			cc.CertificateNumber,
			cert.CertificateCode,
			cert.IsAuditorInitiated,
			YEAR(cc.CreatedDate) AS BaseYear,
			cc.CustomerCertificationId,
			ccd.Id AS CustomerCertificationDetailsId,
			ccd.AddressId,
			ccd.DepartmentId,
			CAST(CASE WHEN ccd.Recertification IS NULL THEN cc.Recertification
			ELSE ccd.Recertification END AS SMALLINT) AS Recertification,
			cad.City AS Location,
			cd.DepartmentName,
			CASE WHEN ccd.Status IS NULL THEN cc.SubmissionStatus
			ELSE ccd.Status END AS Status,
			CASE WHEN cc.SubmissionStatus = 11 THEN NULL ELSE ao.AssignedTime END AS AssignedTime,
			CASE WHEN cc.SubmissionStatus = 11 THEN NULL ELSE ao.FromDate END AS FromDate,
			CASE WHEN cc.SubmissionStatus = 11 THEN NULL ELSE ao.ToDate END AS ToDate,
			(SELECT Id FROM SBSC.Auditor WHERE Id IN (SELECT AuditorId FROM SBSC.AssignmentAuditor WHERE IsLeadAuditor = 1 AND AssignmentId = ao.Id)) AS AuditorId,
			(SELECT Name FROM SBSC.Auditor WHERE Id IN (SELECT AuditorId FROM SBSC.AssignmentAuditor WHERE IsLeadAuditor = 1 AND AssignmentId = ao.Id)) AS LeadAuditor,
			ccd.UpdatedByCustomer,
			ccd.UpdatedByAuditor,
			ao.LastUpdatedDate
		FROM SBSC.Customer_Certifications cc
		LEFT JOIN SBSC.CustomerCertificationDetails ccd ON cc.CustomerCertificationId = ccd.CustomerCertificationId
		LEFT JOIN SBSC.CustomerCredentials cce ON cc.CustomerId = cce.CustomerId
		LEFT JOIN SBSC.Customers c ON cc.CustomerId = c.Id
		LEFT JOIN SBSC.Certification cert ON cert.Id = cc.CertificateId
		LEFT JOIN SBSC.Auditor_Certifications ac ON (ac.CertificationId = cc.CertificateId)
		LEFT JOIN SBSC.Customer_Auditors ca ON ca.CustomerId = cc.CustomerId
		LEFT JOIN SBSC.AssignmentCustomerCertification acc ON acc.CustomerCertificationDetailsId = ccd.Id
		LEFT JOIN SBSC.AssignmentOccasions ao ON ao.Id = acc.AssignmentId
		LEFT JOIN SBSC.AssignmentAuditor aaud ON aaud.AssignmentId = ao.Id
		LEFT JOIN SBSC.Auditor a ON a.Id = aaud.AuditorId
		LEFT JOIN SBSC.Customer_Address cad ON cad.Id = ccd.AddressId
		LEFT JOIN SBSC.Customer_Department cd ON cd.Id = ccd.DepartmentId
		WHERE 
			c.IsAnonymizes != 1
			AND (@CustomerId IS NULL OR c.Id = @CustomerId)
			AND (@AuditorId IS NULL OR 
				-- First check: If auditor is SBSC auditor, show all data
				(SELECT IsSBSCAuditor FROM SBSC.Auditor WHERE Id = @AuditorId) = 1
				OR
				-- Second check: Show records where auditor is in assignment auditor table
				aaud.AuditorId = @AuditorId
				OR
				-- Third check: Show records where auditor is customer-specific auditor
				ca.AuditorId = @AuditorId
				OR
				-- Fourth check: Only if no customer-auditor relationship exists, check certification auditor
				(NOT EXISTS (SELECT 1 FROM SBSC.Customer_Auditors WHERE AuditorId = @AuditorId) 
				 AND ac.AuditorId = @AuditorId)
			)
			AND (@Status IS NULL OR ccd.Status = @Status)
		ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + ';';
    
		EXEC sp_executesql @sql,
			N'@CustomerId INT, @AuditorId INT, @Status VARCHAR(50)',
			@CustomerId, @AuditorId, @Status;
	END
END
GO