SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SBSC].[sp_Decision]
    @Action NVARCHAR(50),               
    @Id INT = NULL,
    @CustomerId INT = NULL,
	@CertificationId INT = NULL,
	@DecisionId INT = 4,
	@AuditorId INT = NULL,
	@DecisionRemarks NVARCHAR(MAX) = NULL,
	@CreatedDate DATETIME = NULL,

	@CustomerCertificationDetailsId INT = NULL,
	@AssignmentId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

	-- returns customer response by requirementId and customerId 
	IF @Action = 'GET_DECISION' 
	BEGIN 
		-- Get CustomerCertificationDetailsId from assignment
		DECLARE @CustomerCertificationDetailsGetIds TABLE ( 
			CustomerCertificationDetailsId INT, 
			CustomerCertificationId INT, 
			CertificateId INT 
		); 
    
		INSERT INTO @CustomerCertificationDetailsGetIds (CustomerCertificationDetailsId, CustomerCertificationId, CertificateId) 
		SELECT DISTINCT  
			acc.CustomerCertificationDetailsId, 
			ccd.CustomerCertificationId, 
			cc.CertificateId 
		FROM SBSC.AssignmentCustomerCertification acc 
		INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id 
		INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId 
		WHERE acc.AssignmentId = @AssignmentId;

		-- Main query to fetch certification details with decision remarks 
		SELECT  
			c.CustomerCertificationId AS Id, 
			c.CustomerId, 
			c.CertificateId AS CertificationId, 
			ccd_details.Status AS DecisionId, 
			c.CertificateNumber AS CertificateNumber, 
			c.Recertification,
			cert.CertificateCode, 
			cert.Published, 
			CASE	
				WHEN dr.Recertification = c.Recertification THEN dr.Remarks
				ELSE NULL
			END AS DecisionRemarks,
			dr.AuditorId, 
			ccd.CustomerCertificationDetailsId, 
			c.IssueDate, 
			c.ExpiryDate, 
			-- Total Deviation using CustomerCertificationDetailsId
			(SELECT COUNT(IsApproved) 
			 FROM SBSC.AuditorCustomerResponses 
			 WHERE CustomerResponseId IN (
				 SELECT Id 
				 FROM SBSC.CustomerResponse 
				 WHERE CustomerCertificationDetailsId = ccd.CustomerCertificationDetailsId
				 AND RequirementId IN (
					 SELECT rc.RequirementId 
					 FROM SBSC.RequirementChapters rc
					 INNER JOIN SBSC.Chapter ch ON rc.ChapterId = ch.Id
					 WHERE ch.CertificationId = c.CertificateId
				 )
			 )
			 AND IsApproved != 1) AS TotalDeviation,
			-- Response Status JSON using CustomerCertificationDetailsId
			JSON_QUERY(
				(
					SELECT 
						ars.ResponseStatusId AS Id, 
						COALESCE(COUNT(acr.ResponseStatusId), 0) AS [Count]
					FROM 
						(VALUES (1), (2), (3)) AS ars(ResponseStatusId)
					LEFT JOIN 
						SBSC.AuditorCustomerResponses acr
						ON acr.ResponseStatusId = ars.ResponseStatusId
						AND acr.CustomerResponseId IN (
							SELECT Id 
							FROM SBSC.CustomerResponse 
							WHERE CustomerCertificationDetailsId = ccd.CustomerCertificationDetailsId
							AND RequirementId IN (
								SELECT rc.RequirementId 
								FROM SBSC.RequirementChapters rc
								INNER JOIN SBSC.Chapter ch ON rc.ChapterId = ch.Id
								WHERE ch.CertificationId = c.CertificateId
							)
						)
						AND acr.ResponseStatusId < 4
					GROUP BY 
						ars.ResponseStatusId
					ORDER BY 
						ars.ResponseStatusId
					FOR JSON PATH
				)
			) AS ResponseStatusJson 
		FROM  
			@CustomerCertificationDetailsGetIds ccd
		INNER JOIN SBSC.Customer_Certifications c ON c.CustomerCertificationId = ccd.CustomerCertificationId
		INNER JOIN SBSC.Certification cert ON cert.Id = c.CertificateId 
		INNER JOIN SBSC.CustomerCertificationDetails ccd_details ON ccd_details.Id = ccd.CustomerCertificationDetailsId
		LEFT JOIN  
			( 
				SELECT  
					CustomerCertificationDetailsId, 
					Remarks, 
					AuditorId, 
					ROW_NUMBER() OVER (PARTITION BY CustomerCertificationDetailsId ORDER BY CreatedDate DESC) AS RowNum,
					Recertification
				FROM SBSC.DecisionRemarks 
			) dr ON dr.CustomerCertificationDetailsId = ccd.CustomerCertificationDetailsId AND dr.RowNum = 1 
	END

	ELSE IF @Action = 'SUBMIT_CERTIFICATE_DECISION'
	BEGIN
		IF @CustomerCertificationDetailsId IS NULL OR NOT EXISTS (SELECT 1 FROM SBSC.CustomerCertificationDetails WHERE ID = @CustomerCertificationDetailsId) 
		BEGIN
			RAISERROR('Invalid CustomerCertificationDetailsId', 16, 1);
			RETURN;
		END
		-- Update the certification record
		IF @DecisionId IN (4, 6)
		BEGIN
			-- Get the validity period from the certification
			DECLARE @ValidityPeriod INT;
			
			SELECT @ValidityPeriod = cc.Validity
			FROM SBSC.Customer_Certifications cc
			INNER JOIN SBSC.CustomerCertificationDetails ccd ON cc.CustomerCertificationId = ccd.CustomerCertificationId
			WHERE ccd.Id = @CustomerCertificationDetailsId;
		
			-- Update with issue date and expiry date
			UPDATE SBSC.CustomerCertificationDetails
			SET 
				Status = @DecisionId,
				IssueDate = GETUTCDATE(),
				ExpiryDate = DATEADD(YEAR, @ValidityPeriod, GETUTCDATE())
			WHERE 
				Id = @CustomerCertificationDetailsId;
		END
		ELSE
		BEGIN
			-- Regular update without dates
			UPDATE SBSC.CustomerCertificationDetails
			SET 
				Status = @DecisionId
			WHERE 
				Id = @CustomerCertificationDetailsId;
		END


		UPDATE SBSC.AssignmentOccasions
			SET LastUpdatedDate = GETUTCDATE()
			WHERE Id = (SELECT AssignmentId FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)

		-- Check if all CustomerCertificationDetails have the same status for the given CustomerCertificationId
		-- and update Customer_Certifications.SubmissionStatus accordingly
		DECLARE @CustomerCertificationId INT;
		DECLARE @AllSameStatus BIT = 0;
		DECLARE @CommonStatus INT;
		
		-- Get the CustomerCertificationId for the current record
		SELECT @CustomerCertificationId = CustomerCertificationId 
		FROM SBSC.CustomerCertificationDetails 
		WHERE Id = @CustomerCertificationDetailsId;
		
		-- Check if all records have the same status
		IF EXISTS (
			SELECT 1
			FROM SBSC.CustomerCertificationDetails
			WHERE CustomerCertificationId = @CustomerCertificationId
			HAVING COUNT(DISTINCT Status) = 1
		)
		BEGIN
			SET @AllSameStatus = 1;
			-- Get the common status
			SELECT TOP 1 @CommonStatus = Status
			FROM SBSC.CustomerCertificationDetails
			WHERE CustomerCertificationId = @CustomerCertificationId;
			
			-- Update Customer_Certifications.SubmissionStatus
			UPDATE SBSC.Customer_Certifications
			SET SubmissionStatus = @CommonStatus
			WHERE CustomerCertificationId = @CustomerCertificationId;
		END
	
		-- Handle Decision Remarks
		-- Check the latest recertification for decision remarks
		IF EXISTS (SELECT 1 FROM SBSC.DecisionRemarks WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId)
		BEGIN
			UPDATE SBSC.DecisionRemarks
				SET 
					Remarks = @DecisionRemarks,
					AuditorId = @AuditorId,
					ModifiedDate = GETUTCDATE()
				WHERE 
					CustomerCertificationDetailsId = @CustomerCertificationDetailsId;
		END
		ELSE
		BEGIN
			-- Insert new decision remarks
			INSERT INTO SBSC.DecisionRemarks (
				CustomerCertificationId, 
				Remarks, 
				AuditorId, 
				CreatedDate, 
				ModifiedDate,
				Recertification,
				CustomerCertificationDetailsId
			)
			VALUES (
				(SELECT CustomerCertificationId FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId),
				@DecisionRemarks,
				@AuditorId,
				ISNULL(@CreatedDate, GETUTCDATE()),
				ISNULL(@CreatedDate, GETUTCDATE()),
				(SELECT Recertification FROM SBSC.CustomerCertificationDetails WHERE ID = @CustomerCertificationDetailsId),
				@CustomerCertificationDetailsId
			);
		END
	
		-- Handle Assignment Status Update (if AssignmentId is provided)
		IF @AssignmentId IS NOT NULL
		BEGIN
			DECLARE @AssignmentStatus INT;
			DECLARE @ConditionMet BIT = 0;
		
			-- Check the condition based on DecisionId using CustomerCertificationDetails
			IF @DecisionId = 6
			BEGIN
				-- For DecisionId = 6, all CustomerCertificationDetails can have Status in (4,6)
				IF NOT EXISTS (
					SELECT 1 
					FROM SBSC.CustomerCertificationDetails ccd
					INNER JOIN SBSC.AssignmentCustomerCertification acc ON ccd.Id = acc.CustomerCertificationDetailsId
					WHERE acc.AssignmentId = @AssignmentId 
					AND ccd.Status IN (4, 6)
				)
				BEGIN
					SET @ConditionMet = 1;
				END
			END
			ELSE
			BEGIN
				-- For other DecisionIds, all CustomerCertificationDetails must have Status = 4
				IF NOT EXISTS (
					SELECT 1 
					FROM SBSC.CustomerCertificationDetails ccd
					INNER JOIN SBSC.AssignmentCustomerCertification acc ON ccd.Id = acc.CustomerCertificationDetailsId
					WHERE acc.AssignmentId = @AssignmentId 
					AND ccd.Status != 4
				)
				BEGIN
					SET @ConditionMet = 1;
				END
			END
		
			-- Determine the assignment status based on condition
			IF @ConditionMet = 1
			BEGIN
				-- Condition is met, set assignment status to DecisionId
				SET @AssignmentStatus = @DecisionId;
			END
			ELSE
			BEGIN
				-- Condition is not met, set assignment status to 9
				SET @AssignmentStatus = 9;
			END
		
			-- Update the assignment occasion status
			UPDATE SBSC.AssignmentOccasions
			SET Status = @AssignmentStatus
			WHERE Id = @AssignmentId;
		END
	
		-- Return success
		SELECT ccd.*, ccd.Id AS CustomerCertificationDetailsId, cc.CustomerId, cc.CertificateId, cc.CertificateNumber, cc.Validity, cc.AuditYears FROM SBSC.CustomerCertificationDetails ccd 
		INNER JOIN SBSC.Customer_Certifications cc ON cc.CustomerCertificationId = ccd.CustomerCertificationId
		WHERE Id = @CustomerCertificationDetailsId;
	END

	ELSE IF @Action = 'RESCHEDULE_CERTIFICATION_FOR_AUDIT'
	BEGIN
		IF @CustomerCertificationDetailsId IS NULL
		BEGIN
			RAISERROR('CustomerCertificationDetailsId must be provided', 16, 1);
			RETURN;
		END

		DECLARE @Recertification SMALLINT = NULL;
		DECLARE @NewCustomerCertificationDetailsId INT = NULL;
		DECLARE @NewAssignmentOccasionId INT = NULL;
		DECLARE @CurrentCustomerCertificationId INT = NULL;
		DECLARE @CurrentCertificationId INT = NULL;
		DECLARE @NewCertificationStatus INT = 7;
		DECLARE @FinalCertificationId INT = NULL; -- ID to use (original or latest version)
		DECLARE @FinalCustomerCertificationId INT = NULL; -- Customer cert ID to use
    
		-- Get current certification details
		SELECT 
			@Recertification = (Recertification + 1),
			@CurrentCustomerCertificationId = CustomerCertificationId
		FROM SBSC.CustomerCertificationDetails 
		WHERE Id = @CustomerCertificationDetailsId;
    
		-- Get the CertificationId for later use
		SELECT @CurrentCertificationId = CertificateId 
		FROM SBSC.Customer_Certifications 
		WHERE CustomerCertificationId = @CurrentCustomerCertificationId;
    
		-- Set initial values
		SET @FinalCertificationId = @CurrentCertificationId;
		SET @FinalCustomerCertificationId = @CurrentCustomerCertificationId;

		-- Check if this is auditor initiated
		IF ((SELECT IsAuditorInitiated FROM SBSC.Certification WHERE Id = @CurrentCertificationId) = 1)
		BEGIN
			SET @NewCertificationStatus = 11;
		END

		-- Check for newer certification versions
		DECLARE @LatestVersionId INT = @CurrentCertificationId;
		DECLARE @CurrentParentId INT = @CurrentCertificationId;
		DECLARE @LoopCounter INT = 0;
		DECLARE @MaxDepth INT = 10; -- Prevent infinite loops

		-- Find the latest version in the certification chain
		WHILE @LoopCounter < @MaxDepth
		BEGIN
			DECLARE @ChildId INT = NULL;
        
			SELECT @ChildId = Id
			FROM SBSC.Certification
			WHERE ParentCertificationId = @CurrentParentId;

			IF @ChildId IS NULL
				BREAK;
        
			SET @LatestVersionId = @ChildId;
			SET @CurrentParentId = @ChildId;
			SET @LoopCounter = @LoopCounter + 1;
		END

		-- If we found a newer version, handle the version upgrade
		IF @LatestVersionId != @CurrentCertificationId
		BEGIN
			-- Check if customer already has the latest version
			DECLARE @ExistingVersionedCustomerCertId INT;
        
			SELECT @ExistingVersionedCustomerCertId = CustomerCertificationId 
			FROM SBSC.Customer_Certifications cc 
			WHERE cc.CustomerId = @CustomerId AND cc.CertificateId = @LatestVersionId;
        
			IF @ExistingVersionedCustomerCertId IS NULL
			BEGIN
				-- Get version data for comparison
				DECLARE @NewVersionValidity INT, @NewVersionAuditYears NVARCHAR(MAX);
				DECLARE @OldSubmissionStatus INT, @OldIssueDate DATETIME, @OldExpiryDate DATETIME;
				DECLARE @ShouldRunAdditionalFunctions BIT = 1;
				DECLARE @FinalValidityToUse INT, @FinalAuditYearsToUse NVARCHAR(MAX), @FinalExpiryDateToUse DATETIME;
            
				-- Get new and old version data
				SELECT @NewVersionValidity = c.Validity, @NewVersionAuditYears = c.AuditYears
				FROM SBSC.Certification c WHERE Id = @LatestVersionId;
            
				SELECT @FinalValidityToUse = c.Validity, @FinalAuditYearsToUse = c.AuditYears
				FROM SBSC.Certification c WHERE Id = @CurrentCertificationId;

				SELECT @OldSubmissionStatus = cc.SubmissionStatus, @OldIssueDate = cc.IssueDate, @OldExpiryDate = cc.ExpiryDate
				FROM SBSC.Customer_Certifications cc WHERE cc.CustomerCertificationId = @CurrentCustomerCertificationId;
            
				SET @FinalExpiryDateToUse = @OldExpiryDate;
            
				-- Handle audit years changes
				IF @NewVersionAuditYears != @FinalAuditYearsToUse
				BEGIN
					SET @FinalAuditYearsToUse = @NewVersionAuditYears;
                
					-- Check if audit years count is sufficient
					DECLARE @NewAuditYearsCount INT = LEN(@NewVersionAuditYears) - LEN(REPLACE(@NewVersionAuditYears, ',', '')) + 1;
					IF @NewAuditYearsCount < @Recertification
					BEGIN
						SET @ShouldRunAdditionalFunctions = 0;
						SET @NewCertificationStatus = @OldSubmissionStatus;
					END
				END
            
				-- Handle validity changes
				IF @NewVersionValidity != @FinalValidityToUse
				BEGIN
					SET @Recertification = @Recertification -1;
					SET @FinalValidityToUse = @NewVersionValidity;
					SET @FinalExpiryDateToUse = DATEADD(YEAR, @NewVersionValidity, DATEFROMPARTS(YEAR(@OldIssueDate), 1, 1));
				END
            
				-- Insert new customer certification
				INSERT INTO SBSC.Customer_Certifications (
					CustomerId, CertificateId, CertificateNumber, Validity, AuditYears, 
					IssueDate, ExpiryDate, CreatedDate, SubmissionStatus, DeviationEndDate, Recertification
				)
				SELECT CustomerId, @LatestVersionId, CertificateNumber, @FinalValidityToUse, @FinalAuditYearsToUse,
					   IssueDate, @FinalExpiryDateToUse, GETUTCDATE(), @NewCertificationStatus, DeviationEndDate, @Recertification
				FROM SBSC.Customer_Certifications WHERE CustomerCertificationId = @CurrentCustomerCertificationId;

				SET @FinalCustomerCertificationId = SCOPE_IDENTITY();
            
				-- Insert certification details and return early if insufficient audit years
				INSERT INTO SBSC.CustomerCertificationDetails (
					CustomerCertificationId, AddressId, DepartmentId, Recertification, Status, 
					DeviationEndDate, CreatedDate, IssueDate, ExpiryDate
				)
				SELECT @FinalCustomerCertificationId, AddressId, DepartmentId, @Recertification, @NewCertificationStatus,
					   DeviationEndDate, GETUTCDATE(), IssueDate, @FinalExpiryDateToUse
				FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId;
            
				SET @NewCustomerCertificationDetailsId = SCOPE_IDENTITY();
            
				-- End the script early without creating any occasions
				IF @ShouldRunAdditionalFunctions = 0
				BEGIN
					SELECT * FROM SBSC.Customer_Certifications WHERE CustomerCertificationId = @FinalCustomerCertificationId;
					RETURN;
				END
			END
			ELSE
			BEGIN
				-- Update existing versioned certification
				UPDATE SBSC.Customer_Certifications
				SET 
					SubmissionStatus = @NewCertificationStatus,
					Recertification = @Recertification
				WHERE CustomerCertificationId = @ExistingVersionedCustomerCertId;
            
				SET @FinalCustomerCertificationId = @ExistingVersionedCustomerCertId;
			END
        
			SET @FinalCertificationId = @LatestVersionId;
		END
		ELSE
		BEGIN
			-- No new version, update existing certification
			UPDATE SBSC.Customer_Certifications
			SET 
				SubmissionStatus = @NewCertificationStatus,
				Recertification = @Recertification
			WHERE CustomerCertificationId = @CurrentCustomerCertificationId;
		END

		-- Handle assignment creation for non-auditor initiated certifications
		IF (SELECT IsAuditorInitiated FROM SBSC.Certification WHERE Id = @FinalCertificationId) = 0
		BEGIN
			-- Create assignment occasion
			INSERT INTO SBSC.AssignmentOccasions (FromDate, ToDate, AssignedTime, CustomerId, Status, LastUpdatedDate)
			VALUES (CONVERT(DATE, GETUTCDATE()), NULL, GETUTCDATE(), @CustomerId, 0, GETUTCDATE());
			SET @NewAssignmentOccasionId = SCOPE_IDENTITY();
        
			-- Check for default auditor (use final certification ID)
			INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			SELECT DISTINCT
				@NewAssignmentOccasionId,
				AuditorId,
				0 AS IsLeadAuditor
			FROM (
				-- Get customer-specific auditors
				SELECT ca.AuditorId
				FROM SBSC.Customer_Auditors ca
				WHERE ca.CustomerId = @CustomerId
        
				UNION
        
				-- Get certification-specific auditors
				SELECT ac.AuditorId
				FROM SBSC.Auditor_Certifications ac
				WHERE ac.CertificationId = @FinalCertificationId
			) AS CombinedAuditors;
        
			-- Create assignment-certification link
			INSERT INTO SBSC.AssignmentCustomerCertification (
				AssignmentId,
				CustomerCertificationDetailsId,
				CustomerCertificationId,
				Recertification
			)
			VALUES (
				@NewAssignmentOccasionId,
				@NewCustomerCertificationDetailsId,
				@FinalCustomerCertificationId,
				@Recertification
			);
		END

		-- Return success (return the final certification being used)
		SELECT * FROM SBSC.Customer_Certifications
		WHERE CustomerCertificationId = @FinalCustomerCertificationId;
	END
	
	-- ??! Unsure about logic for this, simply returns success for all cases.
	ELSE IF @Action = 'UPDATE_CERTIFICATION_VALIDITY'
	BEGIN
		
		IF @CustomerId IS NULL OR @CertificationId IS NULL
		BEGIN
			RAISERROR('Customer ID and Certificate ID must be provided', 16, 1);
			RETURN;
		END
		
		---- Regular update without dates
		--UPDATE SBSC.Customer_Certifications
		--SET 
		--	SubmissionStatus = 8,
		--	Recertification = 0
		--WHERE 
		--	CustomerId = @CustomerId AND CertificateId = @CertificationId;

		
		-- Return success
		SELECT * FROM SBSC.Customer_Certifications
		WHERE CustomerId = @CustomerId AND CertificateId = @CertificationId;
	END


	ELSE
    BEGIN
        -- Invalid action
         RAISERROR('Invalid @Action parameter.', 16, 1);
         RETURN;
    END
END;
GO