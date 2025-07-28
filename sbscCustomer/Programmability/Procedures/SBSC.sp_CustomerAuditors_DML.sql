SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
-- In sbscCustomer database
CREATE PROCEDURE [SBSC].[sp_CustomerAuditors_DML]
(
	@Action NVARCHAR(20) = NULL,
    @AuditorId INT = NULL,
    @AssignedCustomers NVARCHAR(MAX) = NULL -- JSON array of CustomerIds
)
AS
BEGIN
	SET NOCOUNT ON;
	IF @Action NOT IN ('CREATE','UPDATE', 'DELETE', 'ASSIGN_AUDITOR')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, UPDATE, DELETE or ASSIGN_AUDITOR', 16, 1);
        RETURN;
    END

	 -- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		-- Parse the JSON array into a table
		DECLARE @AssignedCustomersTable TABLE (CustomerId INT);

		INSERT INTO @AssignedCustomersTable (CustomerId)
		SELECT CAST(Value AS INT)
		FROM OPENJSON(@AssignedCustomers)
		WHERE Value IS NOT NULL;

		-- Insert into Customer_Auditors
		INSERT INTO [SBSC].[Customer_Auditors] (AuditorId, CustomerId, CertificateCode, [Version], AddressId, IsLeadAuditor)
		SELECT @AuditorId, CustomerId, NULL, NULL, 0, 0 -- Default values for other columns
		FROM @AssignedCustomersTable;
	END

	-- Update operation
	ELSE IF @Action = 'UPDATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;

			-- Clear existing assigned customers not in the new list
			DECLARE @AssignedCustomersTableUpdate TABLE (CustomerId INT);
			INSERT INTO @AssignedCustomersTableUpdate (CustomerId)
			SELECT CAST(Value AS INT)
			FROM OPENJSON(@AssignedCustomers);

			-- Delete customers not included in the update list
			DELETE FROM SBSC.Customer_Auditors
			WHERE AuditorId = @AuditorId
			  AND CustomerId NOT IN (SELECT CustomerId FROM @AssignedCustomersTableUpdate);

			-- Insert only new assigned customers
			INSERT INTO SBSC.Customer_Auditors (AuditorId, CustomerId, CertificateCode, [Version], AddressId, IsLeadAuditor)
			SELECT @AuditorId, CustomerId, NULL, NULL, 0, 0
			FROM @AssignedCustomersTableUpdate
			WHERE CustomerId NOT IN (
				SELECT CustomerId
				FROM SBSC.Customer_Auditors
				WHERE AuditorId = @AuditorId
			);

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			DECLARE @UpdateErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @UpdateErrorSeverity INT = ERROR_SEVERITY();
			DECLARE @UpdateErrorState INT = ERROR_STATE();

			RAISERROR(@UpdateErrorMessage, @UpdateErrorSeverity, @UpdateErrorState);
		END CATCH
	END

	-- Update operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;

			-- Delete related Customer_Auditors records
			DELETE FROM SBSC.Customer_Auditors WHERE AuditorId = @AuditorId;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			DECLARE @DeleteErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @DeleteErrorSeverity INT = ERROR_SEVERITY();
			DECLARE @DeleteErrorState INT = ERROR_STATE();

			RAISERROR(@DeleteErrorMessage, @DeleteErrorSeverity, @DeleteErrorState);
		END CATCH
	END

	ELSE IF @Action = 'ASSIGN_AUDITOR'
	BEGIN
		IF (@AuditorId IS NULL)
		BEGIN
			RAISERROR('@AuditorId is required.', 16, 1);
			RETURN;
		END

		BEGIN TRANSACTION;
    
		BEGIN TRY
        
			IF (EXISTS (SELECT 1 FROM SBSC.Customer_Auditors WHERE AuditorId = @AuditorId)) AND (EXISTS (SELECT 1 FROM SBSC.Auditor_Certifications ac WHERE AuditorId = @AuditorId))
			BEGIN
				-- CREATE temp table for AuditorCustomerCertificationDetails
				DECLARE @AuditorCustoCertDetailsTable TABLE (
					ID INT,
					CustomerCertificationId INT,
					Recertification BIT
				);
				DECLARE @NewAssignmentOccasionId INT = NULL;

				-- Insert the customerCertificationDetails data into the temp table
				INSERT INTO @AuditorCustoCertDetailsTable (ID, CustomerCertificationId, Recertification)
				SELECT ccd.Id, ccd.CustomerCertificationId, ccd.Recertification 
				FROM sbsc.CustomerCertificationDetails ccd    
				INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId
				INNER JOIN SBSC.Certification c ON cc.CertificateId = c.Id
				WHERE c.IsAuditorInitiated = 0 
					AND cc.CustomerId IN (SELECT CustomerId FROM SBSC.Customer_Auditors ca WHERE ca.AuditorId = @AuditorId)
					AND cc.CertificateId IN (SELECT ac.CertificationId FROM sbsc.Auditor_Certifications ac WHERE ac.AuditorId = @AuditorId);

				-- Create cursor to loop over each detailsId
				DECLARE assignment_cursor CURSOR FOR
				SELECT ID, CustomerCertificationId, Recertification FROM @AuditorCustoCertDetailsTable;

				DECLARE @CurrentDetailsId INT, @CurrentCertificationId INT, @CurrentRecertification BIT;
				DECLARE @ExistingAssignmentId INT;

				OPEN assignment_cursor;
				FETCH NEXT FROM assignment_cursor INTO @CurrentDetailsId, @CurrentCertificationId, @CurrentRecertification;

				WHILE @@FETCH_STATUS = 0
				BEGIN
					-- Check if assignment already exists for this CustomerCertificationDetailsId
					SELECT @ExistingAssignmentId = acc.AssignmentId 
					FROM SBSC.AssignmentCustomerCertification acc
					WHERE acc.CustomerCertificationDetailsId = @CurrentDetailsId;

					IF @ExistingAssignmentId IS NOT NULL
					BEGIN
						-- Assignment exists, check if auditor is already assigned
						IF NOT EXISTS (SELECT 1 FROM SBSC.AssignmentAuditor WHERE AssignmentId = @ExistingAssignmentId AND AuditorId = @AuditorId)
						BEGIN
							-- Insert new auditor assignment
							INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
							VALUES(@ExistingAssignmentId, @AuditorId, 0);
						END
					END
					ELSE
					BEGIN
						-- No assignment exists, create new assignment
                    
						-- Get CustomerId for this certification
						DECLARE @CurrentCustomerId INT;
						SELECT @CurrentCustomerId = cc.CustomerId 
						FROM SBSC.Customer_Certifications cc 
						WHERE cc.CustomerCertificationId = @CurrentCertificationId;

						-- Create assignment occasion
						INSERT INTO SBSC.AssignmentOccasions (FromDate, ToDate, AssignedTime, CustomerId, Status, LastUpdatedDate)
						VALUES (CONVERT(DATE, GETUTCDATE()), NULL, GETUTCDATE(), @CurrentCustomerId, 0, GETUTCDATE());
						SET @NewAssignmentOccasionId = SCOPE_IDENTITY();
            
						-- Create assignment-certification link
						INSERT INTO SBSC.AssignmentCustomerCertification (
							AssignmentId,
							CustomerCertificationDetailsId,
							CustomerCertificationId,
							Recertification
						)
						VALUES (
							@NewAssignmentOccasionId,
							@CurrentDetailsId,
							@CurrentCertificationId,
							@CurrentRecertification
						);

						-- Assign auditor to this assignment
						INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
						VALUES(@NewAssignmentOccasionId, @AuditorId, 1);
					END

					FETCH NEXT FROM assignment_cursor INTO @CurrentDetailsId, @CurrentCertificationId, @CurrentRecertification;
				END

				CLOSE assignment_cursor;
				DEALLOCATE assignment_cursor;

				-- Clean up any previous assignments for this auditor that are no longer valid
				DELETE aa FROM SBSC.AssignmentAuditor aa
				INNER JOIN SBSC.AssignmentCustomerCertification acc ON aa.AssignmentId = acc.AssignmentId
				INNER JOIN SBSC.AssignmentOccasions ao ON aa.AssignmentId = ao.Id
				WHERE aa.AuditorId = @AuditorId 
				AND acc.CustomerCertificationDetailsId NOT IN (SELECT ID FROM @AuditorCustoCertDetailsTable)
				AND ao.Status NOT IN (4,5,6);
            
			END
			ELSE IF EXISTS (SELECT 1 FROM SBSC.Auditor_Certifications WHERE AuditorId = @AuditorId)
			BEGIN
				-- Auditor has certifications but no customer assignments
				-- Handle all customer certifications that match auditor's certifications
            
				DECLARE @GlobalCertDetailsTable TABLE (
					ID INT,
					CustomerCertificationId INT,
					Recertification BIT,
					CustomerId INT
				);

				-- Insert all customer certification details for certifications this auditor can handle
				INSERT INTO @GlobalCertDetailsTable (ID, CustomerCertificationId, Recertification, CustomerId)
				SELECT ccd.Id, ccd.CustomerCertificationId, ccd.Recertification, cc.CustomerId
				FROM sbsc.CustomerCertificationDetails ccd    
				INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId
				INNER JOIN SBSC.Certification c ON cc.CertificateId = c.Id
				WHERE c.IsAuditorInitiated = 0 
				AND cc.CertificateId IN (SELECT ac.CertificationId FROM sbsc.Auditor_Certifications ac WHERE ac.AuditorId = @AuditorId);

				-- Create cursor for global certifications
				DECLARE global_assignment_cursor CURSOR FOR
				SELECT ID, CustomerCertificationId, Recertification, CustomerId FROM @GlobalCertDetailsTable;

				DECLARE @GlobalDetailsId INT, @GlobalCertificationId INT, @GlobalRecertification BIT, @GlobalCustomerId INT;
				DECLARE @GlobalExistingAssignmentId INT;

				OPEN global_assignment_cursor;
				FETCH NEXT FROM global_assignment_cursor INTO @GlobalDetailsId, @GlobalCertificationId, @GlobalRecertification, @GlobalCustomerId;

				WHILE @@FETCH_STATUS = 0
				BEGIN
					-- Check if assignment already exists
					SELECT @GlobalExistingAssignmentId = acc.AssignmentId 
					FROM SBSC.AssignmentCustomerCertification acc
					WHERE acc.CustomerCertificationDetailsId = @GlobalDetailsId;

					IF @GlobalExistingAssignmentId IS NOT NULL
					BEGIN
						-- Assignment exists, add auditor if not already assigned
						IF NOT EXISTS (SELECT 1 FROM SBSC.AssignmentAuditor WHERE AssignmentId = @GlobalExistingAssignmentId AND AuditorId = @AuditorId)
						BEGIN
							INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
							VALUES(@GlobalExistingAssignmentId, @AuditorId, 0);
						END
					END
					ELSE
					BEGIN
						-- Create new assignment
						INSERT INTO SBSC.AssignmentOccasions (FromDate, ToDate, AssignedTime, CustomerId, Status, LastUpdatedDate)
						VALUES (CONVERT(DATE, GETUTCDATE()), NULL, GETUTCDATE(), @GlobalCustomerId, 0, GETUTCDATE());
						SET @NewAssignmentOccasionId = SCOPE_IDENTITY();

						-- Create assignment-certification link
						INSERT INTO SBSC.AssignmentCustomerCertification (
							AssignmentId,
							CustomerCertificationDetailsId,
							CustomerCertificationId,
							Recertification
						)
						VALUES (
							@NewAssignmentOccasionId,
							@GlobalDetailsId,
							@GlobalCertificationId,
							@GlobalRecertification
						);

						-- Assign auditor
						INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
						VALUES(@NewAssignmentOccasionId, @AuditorId, 0);
					END

					FETCH NEXT FROM global_assignment_cursor INTO @GlobalDetailsId, @GlobalCertificationId, @GlobalRecertification, @GlobalCustomerId;
				END

				CLOSE global_assignment_cursor;
				DEALLOCATE global_assignment_cursor;
			END
			ELSE
			BEGIN
				-- Auditor has no specific customer or certification assignments
				-- Only delete existing assignments for this auditor
				DELETE aa FROM SBSC.AssignmentAuditor aa
				INNER JOIN SBSC.AssignmentOccasions ao ON aa.AssignmentId = ao.Id
				WHERE AuditorId = @AuditorId
				AND ao.Status NOT IN (4,5,6);;
			END

			-- Commit transaction if all operations succeed
			COMMIT TRANSACTION;
			PRINT 'ASSIGN_AUDITOR completed successfully for AuditorId: ' + CAST(@AuditorId AS VARCHAR(10));

		END TRY
		BEGIN CATCH
			-- Rollback transaction on any error
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
				PRINT 'Transaction rolled back due to error.';
			END

			-- Clean up cursor if still open
			IF CURSOR_STATUS('local', 'assignment_cursor') >= 0
			BEGIN
				CLOSE assignment_cursor;
				DEALLOCATE assignment_cursor;
				PRINT 'Assignment cursor cleaned up after error.';
			END

			IF CURSOR_STATUS('local', 'global_assignment_cursor') >= 0
			BEGIN
				CLOSE global_assignment_cursor;
				DEALLOCATE global_assignment_cursor;
				PRINT 'Global assignment cursor cleaned up after error.';
			END

			-- Capture error details
			DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
			DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
			DECLARE @ErrorState INT = ERROR_STATE();
			DECLARE @ErrorNumber INT = ERROR_NUMBER();
			DECLARE @ErrorProcedure NVARCHAR(128) = ISNULL(ERROR_PROCEDURE(), 'N/A');
			DECLARE @ErrorLine INT = ERROR_LINE();

			-- Use RAISERROR instead of THROW for compatibility
			DECLARE @CustomErrorMessage NVARCHAR(4000) = 
				'ASSIGN_AUDITOR failed for AuditorId: ' + CAST(@AuditorId AS VARCHAR(10)) + 
				'. Original Error: ' + @ErrorMessage;
            
			RAISERROR(@CustomErrorMessage, 16, 1);
			RETURN;
		END CATCH
	END
END;
GO