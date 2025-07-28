SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_Customers_CRUD]
    @Action NVARCHAR(100),
	@DefaultAuditor NVARCHAR(100) = NULL, 
    @Id INT = NULL,
    @CompanyName NVARCHAR(200) = NULL,
    @Email NVARCHAR(500) = NULL,
    @CustomerName NVARCHAR(500) = NULL,
    @CaseId BIGINT = NULL,
    @OrgNo NVARCHAR(50) = NULL,
    @CreatedDate DATETIME = NULL,
	@DepartmentName NVARCHAR(MAX) = NULL,
	@LeadAuditorId INT = NULL,
	@AssignmentId INT = NULL,
	@Recertification INT = NULL,
	@LocationNames NVARCHAR(MAX) = NULL,

	@CustomerType SMALLINT = NULL, --for multiuser, 0 OR NULL = primary, 1 = secondary ....
	@SecondaryUserId INT = NULL, --CustomerCredential table Id

    @Certifications NVARCHAR(MAX) = NULL,
	@CertificationId INT = NULL,
    @CertificationsId [SBSC].[CertificationsIdTable] READONLY,
	--@CertificationList [SBSC].[CertificationListType] READONLY,
	@CertificationStatus NVARCHAR(MAX) = NULL,
	
	@AssignedAuditors NVARCHAR(MAX) = NULL,
    @MFAStatus INT = NULL,
    @Password NVARCHAR(500) = NULL,
    @IsPasswordChanged BIT = NULL,
    @PasswordChangedDate DATETIME = NULL,
    @DefaultLangId INT = NULL,
    @ColumnName NVARCHAR(500) = NULL,
    @NewValue NVARCHAR(500) = NULL,
    @OrderIndex INT = NULL,
    @PageNumber INT = 1	,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = NULL,
    @SortDirection NVARCHAR(4) = NULL,
	@certificateCode NVARCHAR(100) = NULL, 
	@CustomerId INT = NULL, 
	@AuditorId INT = NULL, 
	@AuditorIds NVARCHAR(MAX) = NULL, 
	@CaseNumber NVARCHAR(MAX) = NULL,
	@VATNo NVARCHAR(MAX) = NULL,
	@ContactNumber NVARCHAR(100) = NULL,
	@ContactCellPhone NVARCHAR(100) = NULL,
	@AddressId INT = NULL,
	@AddressIds NVARCHAR(MAX) = NULL,
	@DepartmentId INT = NULL,
	@DepartmentIds NVARCHAR(MAX) = NULL,
	@DefaultAuditorId INT = NULL,
	@CertificateId INT = NULL,
	@CustomerCertificationId INT = NULL,
	@Validity INT = NULL,
	@Version DECIMAL = NULL,
	@AuditorAssignments NVARCHAR(MAX) = NULL,
	@FromDate DATE = NULL,
	@ToDate DATE = NULL,
	@Date DateTime = NULL,
	@AuditYears NVARCHAR(100) = NULL,
	@Auditors NVARCHAR(100) = NULL,
	@AuditorDatePairs NVARCHAR(MAX) = NULL, 
	@CertificateNumber INT = NULL,
	@IsActive BIT = NULL,
	@IsExclusive BIT = NULL,

	@Status SMALLINT = NULL,
	@AuditTime NVARCHAR(50) = NULL,
	
    @ListSQL NVARCHAR(MAX) = NULL,
    @WhereClause NVARCHAR(MAX) = NULL,
    @ListParamDefinition NVARCHAR(MAX) = NULL,
    @Offset INT = NULL,
    @TotalRecords INT = NULL,
    @TotalPages INT = NULL,
    @TotalRecordsOUT INT = NULL

AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'CREATE_SECONDARY', 'READ', 'UPDATE', 'UPDATE_SECONDARY', 'DELETE', 'DELETE_SECONDARY', 'LIST', 'UPDATE_COLUMN', 'ANONYMIZE', 'READ_AUDITORS', 'READ_CUSTOMERS', 'ASSIGN_AUDITOR', 'ASSIGN_AUDITOR_V2', 'ASSIGN_DEFAULT_AUDITOR', 'READ_ASSIGNED_AUDITORS', 'READ_ASSIGNED_AUDITORS_LIST', 'UPDATE_AUDITOR', 'UPDATE_AUDITOR_V2', 'UPDATE_VALIDITY_AND_AUDIT_YEAR', 'FILTER', 'DELETE_ASSIGNED_AUDITORS', 'GET_CERTIFICATE_AUDITYEARS', 'READ_ASSIGNED_CUSTOMER_FROM_AUDITORS', 'READ_ASSIGNED_CUSTOMER_FROM_AUDITORS_LIST', 'UPDATE_USER_LANG', 'DELETE_SBSC_CUSTOMER', 'UPDATE_MFA')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, CREATE_SECONDARY, READ, UPDATE, UPDATE_SECONDARY, DELETE, DELETE_SECONDARY, LIST, READ_AUDITORS, READ_CUSTOMERS, ASSIGN_AUDITOR, ASSIGN_AUDITOR_V2, UPDATE_AUDITOR_V2, FILTER, UPDATE_VALIDITY_AND_AUDIT_YEAR, READ_ASSIGNED_AUDITORS, UPDATE_COLUMN, UPDATE_MFA or UPDATE_USER_LANG', 16, 1);
        RETURN;
    END

	DECLARE @NewAssignmentId INT = NULL;

    -- CREATE action
	IF @Action = 'CREATE'
	BEGIN
		-- Check for missing required parameters
		IF @CompanyName IS NULL OR @OrgNo IS NULL OR @Email IS NULL OR @CustomerName IS NULL
		BEGIN
			RAISERROR('Missing required parameters for CREATE operation.', 16, 1);
			RETURN;
		END

		IF EXISTS (
			SELECT 1 FROM SBSC.CustomerCredentials WHERE Email = @Email
		)
		BEGIN
			RAISERROR('Customer already exists with email=%s', 16, 1, @Email)
			RETURN
		END

		IF EXISTS (SELECT 1 FROM SBSC.AuditorCredentials WHERE Email = @Email)
		BEGIN
			RAISERROR('Already registered as auditor with email=%s', 16, 1, @Email)
			RETURN
		END

		-- Convert email to lower case and trim spaces
		SET @Email = LTRIM(RTRIM(LOWER(@Email)))
		-- Start transaction
		BEGIN TRY
			BEGIN TRANSACTION;

			IF (@DefaultLangId IS NULL)
			BEGIN
				SET @DefaultLangId = (SELECT Id FROM SBSC.Languages WHERE IsDefault = 1)
			END

			-- Insert into Customers table
			INSERT INTO SBSC.Customers (CompanyName, CustomerName, CaseId, OrgNo, CreatedDate, CaseNumber, VATNo, ContactNumber, ContactCellPhone)
			VALUES (@CompanyName, @CustomerName, @CaseId, @OrgNo, GETUTCDATE(), @CaseNumber, @VATNo, @ContactNumber, @ContactCellPhone);
			SET @CustomerId = SCOPE_IDENTITY();
        
			-- Insert into CustomerCredentials
			INSERT INTO SBSC.CustomerCredentials (Email, CustomerId, [Password], IsPasswordChanged, MfaStatus, DefaultLangId, IsActive, UserName, CustomerType)
			VALUES (@Email, @CustomerId, @Password, ISNULL(@IsPasswordChanged, 0), ISNULL(@MFAStatus, 0), @DefaultLangId, 0, @CustomerName, NULL);
			SET @SecondaryUserId = SCOPE_IDENTITY();    

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

				-- Temporary table to capture inserted Ids and CertificationIds
				DECLARE @InsertedCerts TABLE (Id INT, CertificationId INT, SubmissionStatus SMALLINT);
				
				-- Insert ALL records into Customer_Certifications and capture them in temp table
				INSERT INTO SBSC.Customer_Certifications (
					CustomerId, 
					CertificateId, 
					Validity, 
					AuditYears, 
					CreatedDate,
					SubmissionStatus,
					DeviationEndDate
				)
				OUTPUT 
					INSERTED.CustomerCertificationId,
					INSERTED.CertificateId,
					INSERTED.SubmissionStatus
				INTO @InsertedCerts (Id, CertificationId, SubmissionStatus)
				SELECT 
					@CustomerId, 
					cid.CertificationId, 
					c.Validity,
					c.AuditYears,
					GETUTCDATE(),
					CASE WHEN c.IsAuditorInitiated = 1 THEN 11 ELSE 0 END,
					NULL
				FROM @CertificationsId cid
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId;

				-- Generate CertificateNumber for ALL newly inserted certifications
				UPDATE cc
				SET CertificateNumber = RIGHT(CAST(YEAR(GETDATE()) AS NVARCHAR(4)), 2) + '-' + CAST(ic.Id AS NVARCHAR(20))
				FROM SBSC.Customer_Certifications cc
				INNER JOIN @InsertedCerts ic ON cc.CustomerCertificationId = ic.Id
				WHERE cc.CustomerId = @CustomerId;
            
				-- Create individual assignment occasions and assignments for each NON-auditor-initiated certification
				DECLARE @CertCursor CURSOR;
				DECLARE @CurrentCertId INT, @CurrentCustomerCertId INT, @CurrentSubmissionStatus SMALLINT, @NewAssignmentOccasionId INT, @CurrentCustomerCertificationDetailId INT;
            
				SET @CertCursor = CURSOR FOR
				SELECT ic.Id, ic.CertificationId, ic.SubmissionStatus 
				FROM @InsertedCerts ic
				INNER JOIN SBSC.Certification c ON c.Id = ic.CertificationId
				WHERE c.IsAuditorInitiated = 0;  -- Only process non-auditor-initiated certifications
            
				OPEN @CertCursor;
				FETCH NEXT FROM @CertCursor INTO @CurrentCustomerCertId, @CurrentCertId, @CurrentSubmissionStatus;
            
				WHILE @@FETCH_STATUS = 0
				BEGIN
					INSERT INTO SBSC.CustomerCertificationDetails (CustomerCertificationId, Recertification, Status, CreatedDate)
					VALUES (@CurrentCustomerCertId, 0, 0, GETUTCDATE());
					SET @CurrentCustomerCertificationDetailId = SCOPE_IDENTITY();

					-- Create assignment occasion for this certification
					INSERT INTO SBSC.AssignmentOccasions (FromDate, ToDate, AssignedTime, CustomerId, [Status], LastUpdatedDate)
					VALUES (CONVERT(DATE, GETUTCDATE()), NULL, GETUTCDATE(), @CustomerId, 0, GETUTCDATE());
					SET @NewAssignmentOccasionId = SCOPE_IDENTITY();

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
						WHERE ac.CertificationId = @CurrentCertId
					) AS CombinedAuditors;

					-- Create assignment-certification link
					INSERT INTO SBSC.AssignmentCustomerCertification (
						AssignmentId,
						CustomerCertificationId,
						CustomerCertificationDetailsId,
						Recertification
					)
					VALUES (
						@NewAssignmentOccasionId,
						@CurrentCustomerCertId,
						@CurrentCustomerCertificationDetailId,
						ISNULL(@Recertification, 0)
					);

					FETCH NEXT FROM @CertCursor INTO @CurrentCustomerCertId, @CurrentCertId, @CurrentSubmissionStatus;
				END
            
				CLOSE @CertCursor;
				DEALLOCATE @CertCursor;

			END

			-- Commit transaction
			COMMIT TRANSACTION;

			-- Convert CertificationIds back to JSON for response
			DECLARE @CertificationsJson NVARCHAR(MAX);
			SELECT @CertificationsJson = (
				SELECT CertificateCode
				FROM @CertificationsId cid
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId
				FOR JSON PATH
			);

			-- Return the created customer details
			SELECT 
				@CustomerId AS Id, 
				@CompanyName AS CompanyName, 
				@Email AS Email, 
				@CustomerName AS CustomerName, 
				@CaseId AS CaseId, 
				@CaseNumber AS CaseNumber,
				@VATNo AS VATNo,
				@ContactNumber AS ContactNumber,
				@OrgNo AS OrgNo, 
				ISNULL(@CreatedDate, GETDATE()) AS CreatedDate, 
				@MFAStatus AS MfaStatus,
				ISNULL(@CertificationsJson, '[]') AS Certifications,
				@DefaultLangId AS LangId,
				@SecondaryUserId AS SecondaryUserId;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
			DECLARE @ErrorMessage NVARCHAR(4000), @ErrorSeverity INT, @ErrorState INT;
			SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
		END CATCH;
	END;

	ELSE IF @Action = 'CREATE_SECONDARY'
	BEGIN
		IF EXISTS (
			SELECT 1 FROM SBSC.CustomerCredentials WHERE Email = @Email
		)
		BEGIN
			RAISERROR('Customer already exists with email=%s', 16, 1, @Email)
			RETURN
		END

		IF EXISTS (SELECT 1 FROM SBSC.AuditorCredentials WHERE Email = @Email)
		BEGIN
			RAISERROR('Already registered as auditor with email=%s', 16, 1, @Email)
			RETURN
		END

		-- Convert email to lower case and trim spaces
		SET @Email = LTRIM(RTRIM(LOWER(@Email)))
		-- Start transaction
		BEGIN TRY
			BEGIN TRANSACTION;
			IF (@DefaultLangId IS NULL)
			BEGIN
				SET @DefaultLangId = (SELECT Id FROM SBSC.Languages WHERE IsDefault = 1)
			END

			-- Insert into CustomerCredentials
			INSERT INTO SBSC.CustomerCredentials (Email, CustomerId, [Password], IsPasswordChanged, MfaStatus, DefaultLangId, IsActive, Username, CustomerType)
			VALUES (@Email, @CustomerId, @Password, ISNULL(@IsPasswordChanged, 0), ISNULL(@MFAStatus, 0), @DefaultLangId, 0, @CustomerName, ISNULL(@CustomerType, 1));
			
			SET @SecondaryUserId = SCOPE_IDENTITY();
        

			COMMIT TRANSACTION;
			-- Return the created customer details
			SELECT 
				@CustomerId AS Id, 
				CompanyName, 
				@Email AS Email, 
				@CustomerName AS CustomerName, 
				CaseId, 
				CaseNumber,
				VATNo,
				ContactNumber,
				OrgNo, 
				ISNULL(@CreatedDate, GETDATE()) AS CreatedDate, 
				@MFAStatus AS MfaStatus,
				'[]' AS Certifications,
				@DefaultLangId AS LangId,
				@SecondaryUserId AS SecondaryUserId
			FROM SBSC.Customers WHERE Id = @CustomerId;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
			DECLARE @ErrorMessageSecondary NVARCHAR(4000), @ErrorSeveritySecondary INT, @ErrorStateSecondary INT;
			SELECT @ErrorMessageSecondary = ERROR_MESSAGE(), @ErrorSeveritySecondary = ERROR_SEVERITY(), @ErrorStateSecondary = ERROR_STATE();
			RAISERROR(@ErrorMessageSecondary, @ErrorSeveritySecondary, @ErrorStateSecondary);
		END CATCH;
	END;


	--IF @Action = 'ASSIGN_DEFAULT_AUDITOR'
	--BEGIN
	--	-- Check if an assignment already exists for this CustomerCertificationId and AuditorId
	--	IF NOT EXISTS (
	--		--SELECT 1 
	--		--FROM SBSC.Certification_Assignment 
	--		--WHERE CustomerCertificationId = @CustomerCertificationId 
	--		--  AND AuditorId = @AuditorId
	--		SELECT 1 
	--		FROM SBSC.AssignmentCustomerCertification acc
	--		JOIN SBSC.AssignmentAuditor aa ON acc.AssignmentId = aa.AssignmentId
	--		WHERE acc.CustomerCertificationId = @CustomerCertificationId
	--		AND aa.AuditorId = @AuditorId
	--	)
	--	BEGIN
	--		-- If no existing assignment, then insert the new assignment
	--		--INSERT INTO SBSC.Certification_Assignment (
	--		--	CustomerCertificationId,
	--		--	AuditorId,
	--		--	IsLeadAuditor,
	--		--	FromDate,
	--		--	ToDate,
	--		--	AssignedTime
	--		--)
	--		--VALUES (
	--		--	@CustomerCertificationId,
	--		--	@AuditorId,
	--		--	1, 
	--		--	CONVERT(DATE, GETUTCDATE()),
	--		--	CONVERT(DATE, GETUTCDATE()), -- ToDate
	--		--	CONVERT(TIME(0), GETUTCDATE()) -- AssignedTime
	--		--)

	--		INSERT INTO SBSC.AssignmentCustomerCertification(CustomerCertificationId, FromDate, ToDate, AssignedTime)
	--		VALUES (@CustomerCertificationId, CONVERT(DATE, GETUTCDATE()), CONVERT(DATE, GETUTCDATE()), GETUTCDATE());

	--		SET @NewAssignmentId = SCOPE_IDENTITY();

	--		INSERT INTO SBSC.AssignmentAuditor(AssignmentId, AuditorId, IsLeadAuditor)
	--		VALUES (@NewAssignmentId, @AuditorId, 1);
	--	END
	--END
	IF @Action IN ('ASSIGN_AUDITOR', 'UPDATE_AUDITOR', 'ASSIGN_AUDITOR_V2', 'UPDATE_AUDITOR_V2')
	BEGIN
		-- Validate input parameters
		IF @CustomerCertificationId IS NULL OR @CustomerCertificationId <= 0
		BEGIN
			RAISERROR('Invalid CustomerCertificationId provided.', 16, 1);
			RETURN;
		END


		IF NOT EXISTS (SELECT 1 FROM SBSC.Customer_Certifications WHERE CustomerCertificationId = @CustomerCertificationId)
		BEGIN
			RAISERROR('CustomerCertificationId not found.', 16, 1);
			RETURN;
		END

		-- Validate JSON format of AuditorAssignments
		--IF ISJSON(@AuditorAssignments) = 0
		--BEGIN
		--    RAISERROR('Invalid JSON format in AuditorAssignments.', 16, 1);
		--    RETURN;
		--END

			-- Declare a table to hold assignment details
	  --      DECLARE @AuditorTable TABLE (
	  --          AuditorId INT,
	  --          AddressId INT NULL,
	  --          DepartmentId INT NULL,
	  --          IsLeadAuditor BIT NULL,
	  --          CertificateId INT,
	  --          CertificateNumber BIGINT,
	  --          FromDate DATE NULL,
	  --          ToDate DATE NULL
	  --      );

	  --      -- Deserialize JSON into the table variable
	  --      INSERT INTO @AuditorAssignmentTable (
	  --          AuditorId, 
	  --          AddressId, 
	  --          DepartmentId, 
	  --          IsLeadAuditor,
	  --          CertificateId,
	  --          CertificateNumber,
	  --          FromDate,
	  --          ToDate
	  --      )
	  --      SELECT 
	  --          CAST(auditor.value AS INT) AS AuditorId,
	  --          CASE 
	  --              WHEN NULLIF(TRIM(addr.value), '') IS NULL THEN NULL 
	  --              ELSE TRY_CAST(addr.value AS INT)
	  --          END AS AddressId,
	  --          CASE 
	  --              WHEN NULLIF(TRIM(dept.value), '') IS NULL THEN NULL 
	  --              ELSE TRY_CAST(dept.value AS INT)
	  --          END AS DepartmentId,
	  --          CASE 
	  --              WHEN ISNULL(source.leadAuditorId, 0) = CAST(auditor.value AS INT) THEN 1
	  --              ELSE 0
	  --          END AS IsLeadAuditor,
	  --          source.CertificateId,
	  --          source.CertificateNumber,
	  --          CASE 
	  --              WHEN NULLIF(TRIM(source.fromDate), '') IS NULL THEN NULL 
	  --              ELSE TRY_CAST(source.fromDate AS DATE)
	  --          END AS FromDate,
	  --          CASE 
	  --              WHEN NULLIF(TRIM(source.toDate), '') IS NULL THEN NULL 
	  --              ELSE TRY_CAST(source.toDate AS DATE)
	  --          END AS ToDate
	  --      FROM OPENJSON(@AuditorAssignments, '$.auditorAssignments') 
	  --      WITH (
	  --          auditorId NVARCHAR(MAX) '$.auditorId',
	  --          addressId NVARCHAR(MAX) '$.addressId',
	  --          departmentId NVARCHAR(MAX) '$.departmentId',
	  --          leadAuditorId NVARCHAR(MAX) '$.leadAuditorId',
	  --          certificateId INT '$.certificateId',
	  --          certificateNumber BIGINT '$.certificateNumber',
	  --          fromDate NVARCHAR(10) '$.fromDate',
	  --          toDate NVARCHAR(10) '$.toDate'
	  --      ) AS source
	  --      CROSS APPLY STRING_SPLIT(source.auditorId, ',') AS auditor
	  --      CROSS APPLY (SELECT value FROM STRING_SPLIT(ISNULL(NULLIF(source.addressId, ''), 'NULL'), ',')) AS addr
	  --      CROSS APPLY (SELECT value FROM STRING_SPLIT(ISNULL(NULLIF(source.departmentId, ''), 'NULL'), ',')) AS dept;

	  --      -- Retrieve CertificateId and IsAuditorInitiated for validation
			DECLARE @CertificateIdAssignAuditor INT;
			DECLARE @IsAuditorInitiated BIT;
			DECLARE @NewDepartmentId INT;
			DECLARE @NewAddressId INT;

			SELECT 
				@CertificateIdAssignAuditor = cucer.CertificateId,
				@IsAuditorInitiated = cert.IsAuditorInitiated
			FROM 
				SBSC.Customer_Certifications cucer
			INNER JOIN 
				SBSC.Certification cert ON cucer.CertificateId = cert.Id
			WHERE 
				cucer.CustomerCertificationId = @CustomerCertificationId;


			SELECT @CustomerId = CustomerId,
				@CertificateId = CertificateId 
			FROM SBSC.Customer_Certifications 
			WHERE CustomerCertificationId = @CustomerCertificationId

			-- Check if certificate is not auditor initiated and has existing assignments for ASSIGN_AUDITOR
			IF (((@Action = 'ASSIGN_AUDITOR') OR (@Action = 'ASSIGN_AUDITOR_V2')) AND @IsAuditorInitiated = 0)
			BEGIN
				--IF EXISTS (SELECT 1 FROM SBSC.Certification_Assignment WHERE CustomerCertificationId = @CustomerCertificationId)
				IF EXISTS (SELECT 1 FROM SBSC.AssignmentCustomerCertification WHERE CustomerCertificationId = @CustomerCertificationId)
				BEGIN
					RAISERROR('Additional audits cannot be assigned as the certificate is not auditor initiated and existing assignments are present.', 16, 1);
					RETURN;
				END
			END

			--UPDATE SBSC.Customer_Certifications
			--SET SubmissionStatus = @Status
			--WHERE CustomerCertificationId = @CustomerCertificationId;

			-- Handle INSERT or UPDATE based on the action
			--IF @Action = 'ASSIGN_AUDITOR'
			--BEGIN
			--    -- Insert new auditor assignments into Certification_Assignment table
			--    INSERT INTO SBSC.Certification_Assignment (
			--        CustomerCertificationId, 
			--        AuditorId, 
			--        AddressId, 
			--        DepartmentId, 
			--        IsLeadAuditor,
			--        FromDate,
			--        ToDate,
			--        AssignedTime
			--    )
			--    SELECT 
			--        @CustomerCertificationId,
			--        source.AuditorId,
			--        source.AddressId,
			--        source.DepartmentId,
			--        source.IsLeadAuditor,
			--        source.FromDate,
			--        source.ToDate,
			--        CONVERT(TIME(0), GETDATE())
			--    FROM 
			--        @AuditorAssignmentTable AS source;
			--END


			--IF @Action = 'ASSIGN_AUDITOR'
	  --      BEGIN
			

			--	INSERT INTO SBSC.AssignmentCustomerCertification (CustomerCertificationId, FromDate, ToDate, AssignedTime, Recertification)
			--	VALUES (@CustomerCertificationId,
			--			@FromDate,
			--			@ToDate,
			--			GETUTCDATE(),
			--			(SELECT Recertification FROM SBSC.Customer_Certifications WHERE CustomerCertificationId = @CustomerCertificationId));

			--	SET @NewAssignmentId = SCOPE_IDENTITY();


			--	IF @AuditorIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			--		SELECT @NewAssignmentId,
			--				CAST(TRIM(value) AS INT),
			--				CASE 
			--					WHEN CAST(TRIM(value) AS INT) = @LeadAuditorId
			--					THEN 1
			--					ELSE 0
			--				END
			--		FROM STRING_SPLIT(@AuditorIds, ',');
			--	END


			--	IF @AddressIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentAddress (AssignmentId, AddressId)
			--		SELECT @NewAssignmentId,
			--				CAST(TRIM(value) AS INT)
			--		FROM STRING_SPLIT(@AddressIds, ',');
			--	END


			--	IF @DepartmentIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentDepartment (AssignmentId, DepartmentId)
			--		SELECT @NewAssignmentId,
			--				CAST(TRIM(value) AS INT)
			--		FROM STRING_SPLIT(@DepartmentIds, ',');
			--	END
			--END

			--ELSE IF @Action = 'ASSIGN_AUDITOR_V2'
	  --      BEGIN
			--	IF @DepartmentName IS NOT NULL
			--	BEGIN
			--		IF NOT EXISTS (SELECT 1 FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)))
			--		BEGIN
			--			INSERT INTO SBSC.Customer_Department(CustomerId, DepartmentName)
			--			VALUES(@CustomerId, @DepartmentName);

			--			SELECT @NewDepartmentId = SCOPE_IDENTITY();
			--		END
			--		ELSE
			--		BEGIN
			--			SET @NewDepartmentId = (SELECT Id FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName))= TRIM(LOWER(@DepartmentName)))
			--		END
			--	END

	  --           -- Insert new auditor assignments into Certification_Assignment table
	  --          INSERT INTO SBSC.AssignmentCustomerCertification (
	  --              CustomerCertificationId, 
	  --              FromDate,
	  --              ToDate,
	  --              AssignedTime,
			--		Recertification
	  --          )
			--	VALUES (
			--		@CustomerCertificationId,
			--		@FromDate,
			--		@ToDate,
			--		GETUTCDATE(),
			--		@Recertification)


			--	SET @NewAssignmentId = SCOPE_IDENTITY();


			--	INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			--	SELECT 
			--		@NewAssignmentId,
			--		TRY_CAST(TRIM(value) AS INT),
			--		CASE 
			--			WHEN TRY_CAST(TRIM(value) AS INT) = @LeadAuditorId THEN 1
			--			ELSE 0
			--		END
			--	FROM STRING_SPLIT(@AuditorIds, ',')
			--	WHERE TRY_CAST(TRIM(value) AS INT) IS NOT NULL;



			--	INSERT INTO SBSC.AssignmentDepartment (AssignmentId, DepartmentId)
			--	VALUES (@NewAssignmentId, @NewDepartmentId);



			--	DECLARE @LocationName NVARCHAR(255);

			--	DECLARE @TempNames TABLE (LocationName NVARCHAR(MAX));

			--	INSERT INTO @TempNames (LocationName)
			--	SELECT TRIM(value) FROM string_split(@LocationNames, ',');

			--	-- Create a working cursor over the certification list
			--	DECLARE cert_cursor CURSOR FOR
			--	SELECT LocationName FROM @TempNames;

			--	OPEN cert_cursor;
			--	FETCH NEXT FROM cert_cursor INTO @LocationName;

			--	WHILE @@FETCH_STATUS = 0
			--	BEGIN
			--		-- Try to get the address ID
			--		SELECT @NewAddressId = Id
			--		FROM SBSC.Customer_Address
			--		WHERE CustomerId = @CustomerId AND TRIM(LOWER(City)) = TRIM(LOWER(@LocationName));

			--		-- If not exists, insert new address
			--		IF @NewAddressId IS NULL
			--		BEGIN
			--			INSERT INTO SBSC.Customer_Address (CustomerId, City)
			--			VALUES (@CustomerId, @LocationName);

			--			SET @NewAddressId = SCOPE_IDENTITY();
			--		END

			--		-- Insert into AssignmentAddress
			--		INSERT INTO SBSC.AssignmentAddress (AssignmentId, AddressId)
			--		VALUES (@NewAssignmentId, @NewAddressId);

			--		-- Reset for next loop
			--		SET @NewAddressId = NULL;

			--		FETCH NEXT FROM cert_cursor INTO @LocationName;
			--	END

			--	CLOSE cert_cursor;
			--	DEALLOCATE cert_cursor;


	  --      END
	  --      ELSE IF @Action = 'UPDATE_AUDITOR'
	  --      BEGIN
	  --          -- Update existing auditor assignments in Certification_Assignment table
	  --          --UPDATE ca
	  --          --SET 
	  --          --    ca.AuditorId = source.AuditorId,
	  --          --    ca.AddressId = source.AddressId,
	  --          --    ca.DepartmentId = source.DepartmentId,
	  --          --    ca.IsLeadAuditor = source.IsLeadAuditor,
	  --          --    ca.FromDate = source.FromDate,
	  --          --    ca.ToDate = source.ToDate
	  --          --FROM 
	  --          --    SBSC.Certification_Assignment ca
	  --          --INNER JOIN 
	  --          --    @AuditorAssignmentTable source
	  --          --    ON ca.CustomerCertificationId = @CustomerCertificationId
	  --          --    AND ca.AuditorId = source.AuditorId
	  --          --    AND ca.FromDate = source.FromDate


			--	DELETE FROM SBSC.AssignmentAuditor WHERE AssignmentId = @AssignmentId;
			--	DELETE FROM SBSC.AssignmentAddress WHERE AssignmentId = @AssignmentId;
			--	DELETE FROM SBSC.AssignmentDepartment WHERE AssignmentId = @AssignmentId;


			--	IF @AuditorIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			--		SELECT @AssignmentId,
			--				CAST(TRIM(value) AS INT),
			--				CASE 
			--					WHEN CAST(TRIM(value) AS INT) = @LeadAuditorId
			--					THEN 1
			--					ELSE 0
			--				END
			--		FROM STRING_SPLIT(@AuditorIds, ',');
			--	END


			--	IF @AddressIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentAddress (AssignmentId, AddressId)
			--		SELECT @AssignmentId,
			--				CAST(TRIM(value) AS INT)
			--		FROM STRING_SPLIT(@AddressIds, ',');
			--	END


			--	IF @DepartmentIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentDepartment (AssignmentId, DepartmentId)
			--		SELECT @AssignmentId,
			--				CAST(TRIM(value) AS INT)
			--		FROM STRING_SPLIT(@DepartmentIds, ',');
			--	END

	  --      END

			--ELSE IF @Action = 'UPDATE_AUDITOR_V2'
	  --      BEGIN

			--	UPDATE SBSC.AssignmentCustomerCertification
			--	SET FromDate = @FromDate,
			--		ToDate = @ToDate

			--	DELETE FROM SBSC.AssignmentAuditor WHERE AssignmentId = @AssignmentId;
			--	DELETE FROM SBSC.AssignmentAddress WHERE AssignmentId = @AssignmentId;
			--	DELETE FROM SBSC.AssignmentDepartment WHERE AssignmentId = @AssignmentId;


			--	IF @AuditorIds IS NOT NULL
			--	BEGIN
			--		INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
			--		SELECT @AssignmentId,
			--				CAST(TRIM(value) AS INT),
			--				CASE 
			--					WHEN CAST(TRIM(value) AS INT) = @LeadAuditorId
			--					THEN 1
			--					ELSE 0
			--				END
			--		FROM STRING_SPLIT(@AuditorIds, ',');
			--	END

			--	IF @DepartmentName IS NOT NULL
			--	BEGIN
			--		IF NOT EXISTS (SELECT 1 FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName)) = TRIM(LOWER(@DepartmentName)))
			--		BEGIN
			--			INSERT INTO SBSC.Customer_Department(CustomerId, DepartmentName)
			--			VALUES(@CustomerId, @DepartmentName);

			--			SELECT @NewDepartmentId = SCOPE_IDENTITY();
			--		END
			--		ELSE
			--		BEGIN
			--			SET @NewDepartmentId = (SELECT Id FROM SBSC.Customer_Department WHERE CustomerId = @CustomerId AND TRIM(LOWER(DepartmentName))= TRIM(LOWER(@DepartmentName)))
			--		END

			--		INSERT INTO SBSC.AssignmentDepartment (AssignmentId, DepartmentId)
			--		VALUES (@AssignmentId, @NewDepartmentId);
			--	END


			--	IF @LocationNames IS NOT NULL
			--	BEGIN
			--		DECLARE @Location NVARCHAR(255);

			--		DECLARE @TempName TABLE (LocationName NVARCHAR(MAX));

			--		INSERT INTO @TempName (LocationName)
			--		SELECT TRIM(value) FROM string_split(@LocationNames, ',');

			--		-- Create a working cursor over the certification list
			--		DECLARE cert_cursor CURSOR FOR
			--		SELECT LocationName FROM @TempName;

			--		OPEN cert_cursor;
			--		FETCH NEXT FROM cert_cursor INTO @Location;

			--		WHILE @@FETCH_STATUS = 0
			--		BEGIN
			--			-- Try to get the address ID
			--			SELECT @NewAddressId = Id
			--			FROM SBSC.Customer_Address
			--			WHERE CustomerId = @CustomerId AND TRIM(LOWER(City)) = TRIM(LOWER(@Location));

			--			-- If not exists, insert new address
			--			IF @NewAddressId IS NULL
			--			BEGIN
			--				INSERT INTO SBSC.Customer_Address (CustomerId, City)
			--				VALUES (@CustomerId, @Location);

			--				SET @NewAddressId = SCOPE_IDENTITY();
			--			END

			--			-- Insert into AssignmentAddress
			--			INSERT INTO SBSC.AssignmentAddress (AssignmentId, AddressId)
			--			VALUES (@NewAssignmentId, @NewAddressId);

			--			-- Reset for next loop
			--			SET @NewAddressId = NULL;

			--			FETCH NEXT FROM cert_cursor INTO @Location;
			--		END

			--		CLOSE cert_cursor;
			--		DEALLOCATE cert_cursor;

			--	END


	  --      END

			-- Return grouped results in JSON format
			--SELECT 
			--    ca.CustomerCertificationId AS CustomerCertificationId,
			--    (
			--        SELECT 
			--            ca.AssignmentId,
			--            ca.AuditorId,
			--            ca.FromDate,
			--            ca.ToDate,
			--            ca.AddressId,
			--            ca.DepartmentId,
			--            ca.IsLeadAuditor,
			--            ca.AssignedTime,
			--            cert.CertificateCode,
			--            addr.PlaceName,
			--            addr.StreetAddress,
			--            addr.PostalCode,
			--            addr.City,
			--            dept.DepartmentName
			--        FROM 
			--            SBSC.Certification_Assignment AS ca
			--        INNER JOIN 
			--            SBSC.Customer_Certifications AS cucer ON ca.CustomerCertificationId = cucer.CustomerCertificationId
			--        INNER JOIN 
			--            SBSC.Certification AS cert ON cucer.CertificateId = cert.Id
			--        LEFT JOIN 
			--            SBSC.Customer_Address AS addr ON ca.AddressId = addr.Id
			--        LEFT JOIN 
			--            SBSC.Customer_Department AS dept ON ca.DepartmentId = dept.Id
			--        WHERE 
			--            ca.CustomerCertificationId = @CustomerCertificationId
			--        FOR JSON PATH
			--    ) AS AuditorAssignments
			--FROM 
			--    SBSC.Certification_Assignment AS ca
			--WHERE 
			--    ca.CustomerCertificationId = @CustomerCertificationId
			--GROUP BY 
			--    ca.CustomerCertificationId;


			--SELECT 
	  --          acc.CustomerCertificationId AS CustomerCertificationId,
	  --          (
	  --              SELECT 
	  --                  acc.AssignmentId,
	  --                  aa.AuditorId,
			--			cucer.CustomerId,
	  --                  acc.FromDate,
	  --                  acc.ToDate,
	  --                  aad.AddressId,
	  --                  ad.DepartmentId,
	  --                  aa.IsLeadAuditor,
	  --                  acc.AssignedTime,
	  --                  cert.CertificateCode,
	  --                  addr.PlaceName,
	  --                  addr.StreetAddress,
	  --                  addr.PostalCode,
	  --                  addr.City,
	  --                  dept.DepartmentName,
			--			acc.Recertification
	  --              FROM 
	  --                  SBSC.AssignmentCustomerCertification acc
			--			JOIN SBSC.AssignmentAddress aad ON acc.AssignmentId = aad.AssignmentId
			--			JOIN SBSC.AssignmentAuditor aa ON acc.AssignmentId = aa.AssignmentId
			--			JOIN SBSC.AssignmentDepartment ad ON acc.AssignmentId = ad.AssignmentId
	  --              INNER JOIN 
	  --                  SBSC.Customer_Certifications AS cucer ON acc.CustomerCertificationId = cucer.CustomerCertificationId
	  --              INNER JOIN 
	  --                  SBSC.Certification AS cert ON cucer.CertificateId = cert.Id
	  --              LEFT JOIN 
	  --                  SBSC.Customer_Address AS addr ON aad.AddressId = addr.Id
	  --              LEFT JOIN 
	  --                  SBSC.Customer_Department AS dept ON ad.DepartmentId = dept.Id
	  --              WHERE 
	  --                  acc.CustomerCertificationId = @CustomerCertificationId
	  --              FOR JSON PATH
	  --          ) AS AuditorAssignments
	  --      FROM 
	  --          SBSC.AssignmentCustomerCertification AS acc
	  --      WHERE 
	  --          acc.CustomerCertificationId = @CustomerCertificationId
	  --      GROUP BY 
	  --          acc.CustomerCertificationId;

	END

	IF @Action = 'FILTER'
	BEGIN
		DECLARE @FilterSQL NVARCHAR(MAX);
		DECLARE @WhereClauseFilter NVARCHAR(MAX);
		DECLARE @FilterParamDefinition NVARCHAR(MAX);
		DECLARE @RequirementCount INT;

		SET @RequirementCount = (select COUNT(rc.RequirementId) FROM SBSC.Certification c
			LEFT JOIN SBSC.Chapter ch ON ch.CertificationId = c.Id
			LEFT JOIN SBSC.RequirementChapters rc ON rc.ChapterId = ch.Id
			WHERE c.Id = @CertificationId)

		-- Base Query
		SET @FilterSQL = 
				N'
				SELECT 
				c.[Id],
				c.[CompanyName],
				c.[Email],
				c.[CustomerName],
				c.[CaseId],
				c.[CaseNumber],
				c.[OrgNo],
				c.[VATNo],
				c.[ContactNumber],
				c.[ContactCellPhone],
				c.[DefaultAuditor],
				c.[CreatedDate],
				c.[IsAnonymizes],
				c.[Certifications],
				c.[AssignedAuditors],
				c.[CertificateNumbers],
				c.[CustomerCertificationIds],
				c.[MfaStatus],
				c.[IsActive],
				CASE
					WHEN ccert.CertificateId = @CertificationId
					THEN
						CONCAT(ISNULL(cr_count.ResponseCount, 0), ''/'' + @RequirementCount) 
					ELSE ''-''
				END AS Answers,
				c.[IsPasswordChanged],
				c.[PasswordChangedDate],
				c.[DefaultLangId],
				c.[ChildUsers]
			FROM SBSC.vw_Customers c WITH (NOLOCK)
			LEFT JOIN SBSC.Customer_Certifications ccert 
			ON ccert.CustomerId = c.Id AND ccert.CertificateId = @CertificationId
					--ccert.CustomerCertificationId = TRY_CAST(LEFT(c.CustomerCertificationIds, 
						--									CHARINDEX('','', c.CustomerCertificationIds + '','') - 1) AS INT)
			LEFT JOIN (
				SELECT 
					CustomerId, 
					COUNT(*) AS ResponseCount
				FROM SBSC.CustomerResponse
				GROUP BY CustomerId
			) cr_count ON c.Id = cr_count.CustomerId';

			
	
		-- Dynamic WHERE Clause  
		SET @WhereClauseFilter = N'
			WHERE 1=1
			AND (@CompanyName IS NULL OR c.CompanyName = @CompanyName)
			AND (@CertificationId IS NULL OR c.Certifications LIKE ''%"id":'' + @CertificationId + '',%'')
			AND (@Auditors IS NULL OR c.AssignedAuditors = @Auditors)
			AND (@AuditorId IS NULL OR 
				((c.Id IN (
					SELECT DISTINCT CustomerId 
					FROM [SBSC].[Customer_Auditors] 
					WHERE AuditorID = @AuditorId
				)
				OR c.Id IN (
					SELECT DISTINCT CustomerId FROM SBSC.AssignmentOccasions ao
					INNER JOIN SBSC.AssignmentAuditor aa ON ao.Id = aa.AssignmentId
					WHERE AuditorId = @AuditorId
				))
				AND 
				Certifications IS NOT NULL)
			)';

	

		-- Combine SQL
		SET @FilterSQL += @WhereClauseFilter;

		-- Define Parameters for sp_executesql
		SET @FilterParamDefinition = N'@CompanyName NVARCHAR(100), 
									   @CertificationId INT, 
									   @Auditors NVARCHAR(100),
									   @AuditorId INT,
									   @RequirementCount INT';

		-- Execute Dynamic SQL
		EXEC sp_executesql @FilterSQL, @FilterParamDefinition,
			@CompanyName = @CompanyName, 
			@CertificationId = @CertificationId, 
			@Auditors = @Auditors,
			@AuditorId = @AuditorId,
			@RequirementCount = @RequirementCount;
	END;

	IF @Action = 'READ_ASSIGNED_AUDITORS'
	BEGIN
		-- Validate CustomerId
		IF @Id IS NULL
		BEGIN
			RAISERROR ('Error: CustomerId is required for READ_ASSIGNED_AUDITORS action.', 16, 1);
			RETURN;
		END
		SELECT vc.*,
			(SELECT COUNT(DISTINCT Id) 
				FROM SBSC.CustomerResponse 
				WHERE CustomerId = vc.CustomerId 
				AND RequirementId IN (
						SELECT RequirementId 
						FROM SBSC.RequirementChapters 
						WHERE ChapterId IN (
								SELECT Id 
								FROM SBSC.Chapter 
								WHERE CertificationId = vc.CertificateId)))  AS ResponseCount,
			(SELECT COUNT(DISTINCT Id) 
				FROM SBSC.Requirement 
				WHERE Id IN (
						SELECT RequirementId 
						FROM SBSC.RequirementChapters 
						WHERE ChapterId IN (
								SELECT Id 
								FROM SBSC.Chapter 
								WHERE CertificationId = vc.CertificateId)))  AS RequirementCount
		FROM SBSC.vw_CustomerCertificationDetails vc
		WHERE vc.CustomerId = @Id AND (@CertificationId IS NULL OR vc.CertificateId = @CertificationId)
		AND (@Status IS NULL  
			OR	(@Status = 4 AND vc.SubmissionStatus IN (4, 5, 6))
			OR	(@Status = 1 AND vc.SubmissionStatus IN (0, 1))
			OR vc.SubmissionStatus = @Status)
		ORDER BY vc.LastUpdatedDate DESC; 
	END

	
	IF @Action = 'READ_ASSIGNED_AUDITORS_LIST'
	BEGIN
		-- Validate CustomerId
		IF @Id IS NULL
		BEGIN
			RAISERROR ('Error: CustomerId is required for READ_ASSIGNED_AUDITORS action.', 16, 1);
			RETURN;
		END


		IF @SortColumn IS NULL OR @SortColumn NOT IN ('Id', 'CompanyName', 'CustomerName', 'LastUpdatedDate')
			SET @SortColumn = 'CompanyName'
		IF @SortDirection IS NULL OR @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC'

		SET @Offset = (@PageNumber - 1) * @PageSize;

		SET @WhereClause = N' WHERE 1=1 AND CustomerId = @Id
					AND (@CertificationId IS NULL OR CertificateId = @CertificationId)
					AND (@Status IS NULL  
						OR	(@Status = 4 AND SubmissionStatus IN (4, 5, 6))
						OR	(@Status = 1 AND SubmissionStatus IN (0, 1))
						OR SubmissionStatus = @Status)'

		SET @ListSQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM SBSC.vw_CustomerCertificationDetails
			' + @WhereClause;

		SET @ListParamDefinition = N'@Id INT, @CertificationId INT, @Status SMALLINT, @TotalRecords INT OUTPUT'

		EXEC sp_executesql @ListSQL, @ListParamDefinition, @Id, @CertificationId, @Status, @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		SET @ListSQL = N'
			SELECT * FROM SBSC.vw_CustomerCertificationDetails
			' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection  + '
				OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
				FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';


		EXEC sp_executesql @ListSQL, @ListParamDefinition, @Id, @CertificationId, @Status, @TotalRecords OUTPUT;

		SELECT @TotalRecords AS TotalRecords,
		@TotalPages AS TotalPages,
		@PageNumber AS CurrentPage,
		@PageSize AS PageSize,
		CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
		CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END

	IF @Action = 'READ_ASSIGNED_CUSTOMER_FROM_AUDITORS'
	BEGIN
		-- Validate AuditorId
		IF @AuditorId IS NULL
		BEGIN
			RAISERROR ('Error: AuditorId is required for READ_ASSIGNED_CUSTOMER_FROM_AUDITORS action.', 16, 1);
			RETURN;
		END

		DECLARE @IsSBSCAuditor BIT = 0;

		SET @IsSBSCAuditor = (SELECT IsSBSCAuditor FROM SBSC.Auditor WHERE Id = @AuditorId);
 
		IF (@IsSBSCAuditor = 0)
		BEGIN
			SELECT vc.*,  
			(SELECT COUNT(DISTINCT Id) 
				FROM SBSC.CustomerResponse 
				WHERE CustomerId = vc.CustomerId 
				AND RequirementId IN (
						SELECT RequirementId 
						FROM SBSC.RequirementChapters 
						WHERE ChapterId IN (
								SELECT Id 
								FROM SBSC.Chapter 
								WHERE CertificationId = vc.CertificateId)))  AS ResponseCount,
			(SELECT COUNT(DISTINCT Id) 
				FROM SBSC.Requirement 
				WHERE Id IN (
						SELECT RequirementId 
						FROM SBSC.RequirementChapters 
						WHERE ChapterId IN (
								SELECT Id 
								FROM SBSC.Chapter 
								WHERE CertificationId = vc.CertificateId)))  AS RequirementCount
			FROM SBSC.vw_CustomerCertificationDetails vc
			WHERE 
			(
				vc.CertificateId IN (SELECT CertificationId FROM SBSC.Auditor_Certifications WHERE AuditorId = @AuditorId)
				AND 
				(
					-- If auditor has customer assignments, filter by those customers
					(
						(SELECT COUNT(*) FROM SBSC.Customer_Auditors WHERE AuditorId = @AuditorId) > 0 
						AND vc.CustomerId IN (SELECT CustomerId FROM SBSC.Customer_Auditors WHERE AuditorId = @AuditorId)
					)
					-- OR if the auditor is assigned to this specific certification (present in Auditors JSON)
					OR (
						ISJSON(vc.Auditors) = 1  -- Ensure the Auditors column contains valid JSON
						AND EXISTS (
							SELECT 1
							FROM OPENJSON(vc.Auditors)
							WITH (
								id INT '$.id'
							)
							WHERE id = @AuditorId
						)
					)
				)
			)
			AND (@IsExclusive = 0 OR @IsExclusive IS NULL 
				OR (
					@IsExclusive = 1 
					AND (
						-- Only apply this filter if the AuditorId exists in the Customer_Auditors table
						NOT EXISTS (
							SELECT 1 
							FROM SBSC.Customer_Auditors 
							WHERE AuditorId = @AuditorId
						)
						OR vc.CustomerId IN (
							SELECT CustomerId 
							FROM SBSC.Customer_Auditors 
							WHERE AuditorId = @AuditorId
						)
					)
				)
			)
			AND (@CustomerId IS NULL OR vc.CustomerId = @CustomerId)
			AND (@Status IS NULL  
			OR	(@Status = 4 AND vc.SubmissionStatus IN (4, 5, 6))
			OR	(@Status = 1 AND vc.SubmissionStatus IN (0, 1))
			OR vc.SubmissionStatus = @Status) -- Add filter for SubmissionStatus when @Status is provided
			ORDER BY vc.LastUpdatedDate DESC;
		END
		ELSE
		BEGIN
			SELECT vc.* ,
				(SELECT COUNT(DISTINCT Id) 
					FROM SBSC.CustomerResponse 
					WHERE CustomerId = vc.CustomerId 
					AND RequirementId IN (
							SELECT RequirementId 
							FROM SBSC.RequirementChapters 
							WHERE ChapterId IN (
									SELECT Id 
									FROM SBSC.Chapter 
									WHERE CertificationId = vc.CertificateId)))  AS ResponseCount,
				(SELECT COUNT(DISTINCT Id) 
					FROM SBSC.Requirement 
					WHERE Id IN (
							SELECT RequirementId 
							FROM SBSC.RequirementChapters 
							WHERE ChapterId IN (
									SELECT Id 
									FROM SBSC.Chapter 
									WHERE CertificationId = vc.CertificateId)))  AS RequirementCount
			FROM SBSC.vw_CustomerCertificationDetails vc
			WHERE (@CustomerId IS NULL OR vc.CustomerId = @CustomerId)
			AND (@Status IS NULL  
			OR	(@Status = 4 AND vc.SubmissionStatus IN (4, 5, 6))
			OR	(@Status = 1 AND vc.SubmissionStatus IN (0, 1))
			OR vc.SubmissionStatus = @Status) -- Add filter for SubmissionStatus when @Status is provided
			ORDER BY vc.LastUpdatedDate DESC;

		END
	END

	IF @Action = 'READ_ASSIGNED_CUSTOMER_FROM_AUDITORS_LIST'
	BEGIN
		-- Validate AuditorId
		IF @AuditorId IS NULL
		BEGIN
			RAISERROR ('Error: AuditorId is required for READ_ASSIGNED_CUSTOMER_FROM_AUDITORS action.', 16, 1);
			RETURN;
		END
    
		IF @SortColumn IS NULL OR @SortColumn NOT IN ('Id', 'CompanyName', 'CustomerName', 'ModifiedDate', 'LastUpdatedDate')
			SET @SortColumn = 'Id'
		IF @SortDirection IS NULL OR @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC'

		SET @OfFset = (@PageNumber - 1) * @PageSize;

		SET @WhereClause = N' WHERE 1=1 AND (
			(
				ISJSON(Auditors) = 1 
				AND EXISTS (
					SELECT 1
					FROM OPENJSON(Auditors)
					WITH (
						id INT ''$.id''
					)
					WHERE id = @AuditorId
				)
			)
			OR EXISTS (
				SELECT 1 
				FROM SBSC.Auditor_Certifications 
				WHERE AuditorId = @AuditorId 
				AND CertificationId = CertificateId 
				AND IsDefault = 1
			)
		)
		AND (@Status IS NULL  
			OR	(@Status = 4 AND SubmissionStatus IN (4, 5, 6))
			OR	(@Status = 1 AND SubmissionStatus IN (0, 1))
			OR SubmissionStatus = @Status)'

		SET @ListSQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM SBSC.vw_CustomerCertificationDetails
			' + @WhereClause;

		SET @ListParamDefinition = N'@AuditorId INT, @Status SMALLINT, @TotalRecords INT OUTPUT'

		EXEC sp_executesql @ListSQL, @ListParamDefinition, @AuditorId, @Status, @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		SET @ListSQL = N'
			SELECT * FROM SBSC.vw_CustomerCertificationDetails
			' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection  + '
				OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
				FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';


		EXEC sp_executesql @ListSQL, @ListParamDefinition, @AuditorId, @Status, @TotalRecords OUTPUT;

		SELECT @TotalRecords AS TotalRecords,
		@TotalPages AS TotalPages,
		@PageNumber AS CurrentPage,
		@PageSize AS PageSize,
		CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
		CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
END

	-- READ operation
	ELSE IF @Action = 'READ'
	BEGIN
		--DECLARE @ReqCount INT = NULL;

		--SET @ReqCount = (select COUNT(rc.RequirementId) FROM SBSC.Certification c
		--	LEFT JOIN SBSC.Chapter ch ON ch.CertificationId = c.Id
		--	LEFT JOIN SBSC.RequirementChapters rc ON rc.ChapterId = ch.Id
		--	WHERE c.Id = @CertificationId)

		SELECT 
			c.[Id]
		  ,c.[CompanyName]
		  ,c.[Email]
		  ,c.[DefaultLangId]
		  ,c.[CustomerName]
		  ,c.[CaseId]
		  ,c.[CaseNumber]
		  ,c.[OrgNo]
		  ,c.[VatNo]
		  ,c.[ContactNumber]
		  ,c.[ContactCellPhone]
		  ,c.[DefaultAuditor]
		  ,c.[CreatedDate]
		  ,c.[IsAnonymizes]
		  ,c.[Certifications]
		  ,c.[AssignedAuditors]
		  ,c.[CertificateNumbers]
		  ,c.[CustomerCertificationIds]
		  ,c.[MfaStatus]
		  ,c.[IsActive]
		  ,c.[IsPasswordChanged]
		  ,c.[PasswordChangedDate]
		  ,c.CustomerType
		  ,c.ChildUsers
		  ,CASE
				WHEN ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = 'SSF1101Cyber Security_Live')
				THEN
					CONCAT(ISNULL(cr_count.ResponseCount, 0), '/61') 
				ELSE '-'
			END AS Answers
		FROM SBSC.vw_Customers c
		LEFT JOIN SBSC.Customer_Certifications ccert 
			ON ccert.CustomerId = c.Id AND ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = 'SSF1101Cyber Security_Live')
					--ccert.CustomerCertificationId = TRY_CAST(LEFT(vc.CustomerCertificationIds, 
						--									CHARINDEX(',', vc.CustomerCertificationIds + ',') - 1) AS INT)
		LEFT JOIN (
			SELECT 
				CustomerId, 
				COUNT(*) AS ResponseCount
			FROM SBSC.CustomerResponse
			GROUP BY CustomerId
		) cr_count ON c.Id = cr_count.CustomerId
		WHERE Id = @Id;
	END;

	ELSE IF @Action = 'READ_AUDITORS'
	BEGIN
		-- Variable to store the default auditor
		DECLARE @LeadCertificationAuditorId INT = NULL;

		-- Check if there is a DefaultAuditor based on input parameters
		IF @CustomerId IS NOT NULL
		BEGIN
			-- Check IsLeadAuditor when CustomerId is provided
			--SELECT @LeadAuditorId = ca.AuditorId
			--FROM SBSC.Certification_Assignment AS ca
			--INNER JOIN SBSC.Customer_Certifications AS cc ON ca.CustomerCertificationId = cc.CustomerCertificationId
			--WHERE cc.CustomerId = @CustomerId AND CAST(ca.IsLeadAuditor AS BIT) = 1;

			SELECT @LeadAuditorId = aa.AuditorId
			FROM SBSC.AssignmentAuditor AS aa
			JOIN SBSC.AssignmentCustomerCertification acc ON acc.AssignmentId = aa.AssignmentId
			INNER JOIN SBSC.Customer_Certifications AS cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
			WHERE cc.CustomerId = @CustomerId AND CAST(aa.IsLeadAuditor AS BIT) = 1;
		END
		
		IF @CertificateCode IS NOT NULL
		BEGIN
			-- Check IsDefault when only CertificateCode is provided
			SELECT TOP 1 @LeadCertificationAuditorId = ac.AuditorId
			FROM SBSC.Auditor_Certifications ac
			INNER JOIN SBSC.Certification c ON ac.CertificationId = c.Id
			WHERE c.CertificateCode IN (SELECT value FROM STRING_SPLIT(@CertificateCode, ','))
			AND CAST(ac.IsDefault AS BIT) = 1;
		END

		--SELECT 
		--	a.Id AS AuditorId,
		--	a.Name AS AuditorName,
		--	MAX(cert.CertificateCode) AS CertificateCode,
		--	MAX(ISNULL(cust.CertificateNumber, 0)) AS CertificateNumber,
		--	MAX(ISNULL(cert.Version, 1)) AS Version,
		--	CASE 
		--		WHEN a.Id = @LeadAuditorId THEN CAST(1 AS BIT)
		--		ELSE CAST(0 AS BIT)
		--	END AS DefaultAuditor,
		--	CASE 
		--		WHEN a.Id = @LeadCertificationAuditorId THEN CAST(1 AS BIT)
		--		ELSE CAST(0 AS BIT)
		--	END AS DefaultCertificationAuditor
		--FROM 
		--	SBSC.Auditor AS a
		--LEFT JOIN (
		--	-- Only include the certification path when filtering by CertificateCode
		--	SELECT DISTINCT 
		--		ac.AuditorId, 
		--		c.CertificateCode, 
		--		c.Id as CertificationId, 
		--		c.Version,
		--		CAST(ac.IsDefault AS BIT) AS DefaultAuditor
		--	FROM SBSC.Auditor_Certifications ac
		--	INNER JOIN SBSC.Certification c ON ac.CertificationId = c.Id
		--	WHERE @CertificateCode IS NOT NULL 
		--		AND c.CertificateCode IN (SELECT value FROM STRING_SPLIT(@CertificateCode, ','))
		--) cert ON cert.AuditorId = a.Id
		--LEFT JOIN (
		--	-- Include auditors from both Certification_Assignment and Customer_Auditors when filtering by CustomerId
		--	SELECT DISTINCT 
		--		AuditorId, 
		--		CertificateNumber,
		--		CustomerId,
		--		CertificateCode,
		--		Version
		--	FROM (
		--		-- Auditors from Certification_Assignment path
		--		SELECT 
		--			ca.AuditorId, 
		--			cc.CertificateNumber,
		--			cc.CustomerId,
		--			c.CertificateCode,
		--			c.Version
		--		FROM SBSC.Certification_Assignment ca
		--		INNER JOIN SBSC.Customer_Certifications cc ON ca.CustomerCertificationId = cc.CustomerCertificationId
		--		INNER JOIN SBSC.Certification c ON cc.CertificateId = c.Id
		--		WHERE @CustomerId IS NOT NULL AND cc.CustomerId = @CustomerId
            
		--		UNION
            
		--		-- Auditors from Customer_Auditors path
		--		SELECT 
		--			caud.AuditorId,
		--			NULL as CertificateNumber,
		--			caud.CustomerId,
		--			NULL as CertificateCode,
		--			NULL as Version
		--		FROM SBSC.Customer_Auditors caud
		--		WHERE @CustomerId IS NOT NULL AND caud.CustomerId = @CustomerId
		--	) combined
		--) cust ON cust.AuditorId = a.Id
		--WHERE 
		--	(
		--		@CertificateCode IS NOT NULL AND cert.AuditorId IS NOT NULL
		--	)
		--	OR
		--	(
		--		@CustomerId IS NOT NULL AND cust.AuditorId IS NOT NULL
		--	)
		--GROUP BY 
		--	a.Id,
		--	a.Name
		--ORDER BY 
		--	a.Name;

		SELECT 
			a.Id AS AuditorId,
			a.Name AS AuditorName,
			ac.IsActive,
			MAX(cert.CertificateCode) AS CertificateCode,
			MAX(ISNULL(cust.CertificateNumber, 0)) AS CertificateNumber,
			MAX(ISNULL(cert.Version, 1)) AS Version,
			CASE 
				WHEN a.Id = @LeadAuditorId THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
			END AS DefaultAuditor,
			CASE 
				WHEN a.Id = @LeadCertificationAuditorId THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
			END AS DefaultCertificationAuditor
		FROM 
			SBSC.Auditor AS a
		LEFT JOIN SBSC.AuditorCredentials ac ON ac.AuditorId = a.Id
		LEFT JOIN (
			-- Only include the certification path when filtering by CertificateCode
			SELECT DISTINCT 
				ac.AuditorId, 
				c.CertificateCode, 
				c.Id as CertificationId, 
				c.Version,
				CAST(ac.IsDefault AS BIT) AS DefaultAuditor
			FROM SBSC.Auditor_Certifications ac
			INNER JOIN SBSC.Certification c ON ac.CertificationId = c.Id
			WHERE @CertificateCode IS NOT NULL 
				AND c.CertificateCode IN (SELECT value FROM STRING_SPLIT(@CertificateCode, ','))
		) cert ON cert.AuditorId = a.Id
		LEFT JOIN (
			-- Include auditors from both Certification_Assignment and Customer_Auditors when filtering by CustomerId
			SELECT DISTINCT 
				AuditorId, 
				CertificateNumber,
				CustomerId,
				CertificateCode,
				Version
			FROM (
				-- Auditors from Certification_Assignment path
				SELECT 
					ca.AuditorId, 
					cc.CertificateNumber,
					cc.CustomerId,
					c.CertificateCode,
					c.Version
				FROM SBSC.Certification_Assignment ca
				INNER JOIN SBSC.Customer_Certifications cc ON ca.CustomerCertificationId = cc.CustomerCertificationId
				INNER JOIN SBSC.Certification c ON cc.CertificateId = c.Id
				WHERE @CustomerId IS NOT NULL AND cc.CustomerId = @CustomerId
				UNION
				-- Auditors from Customer_Auditors path
				SELECT 
					caud.AuditorId,
					NULL as CertificateNumber,
					caud.CustomerId,
					NULL as CertificateCode,
					NULL as Version
				FROM SBSC.Customer_Auditors caud
				WHERE @CustomerId IS NOT NULL AND caud.CustomerId = @CustomerId
			) combined
		) cust ON cust.AuditorId = a.Id
		WHERE 
			(
				@CertificateCode IS NOT NULL AND cert.AuditorId IS NOT NULL
			)
			OR
			(
				@CustomerId IS NOT NULL AND cust.AuditorId IS NOT NULL
			)
		GROUP BY 
			a.Id,
			a.Name,
			ac.IsActive
		ORDER BY 
			a.Name;
	END

	ELSE IF @Action = 'READ_CUSTOMERS'
	BEGIN
		--SELECT DISTINCT
		--	c.Id AS CustomerId,
		--	c.CompanyName AS CompanyName,
		--	MAX(cert.CertificateCode) AS CertificateCode,
		--	MAX(cc.CertificateNumber) AS CertificateNumber,
		--	MAX(ISNULL(cert.Version, 1)) AS Version
		--FROM 
		--	SBSC.Customers AS c
		--LEFT JOIN (
		--	-- Include customers from both Certification_Assignment and Customer_Auditors when filtering by AuditorId
		--	SELECT DISTINCT 
		--		CustomerId,
		--		CertificateCode,
		--		Version
		--	FROM (
		--		-- Customers from Certification_Assignment path
		--		SELECT 
		--			cc.CustomerId,
		--			cert.CertificateCode,
		--			cert.Version
		--		FROM SBSC.Certification_Assignment ca
		--		INNER JOIN SBSC.Customer_Certifications cc ON ca.CustomerCertificationId = cc.CustomerCertificationId
		--		INNER JOIN SBSC.Certification cert ON cc.CertificateId = cert.Id
		--		WHERE @AuditorId IS NOT NULL AND ca.AuditorId = @AuditorId
            
		--		UNION
            
		--		-- Customers from Customer_Auditors path
		--		SELECT 
		--			caud.CustomerId,
		--			NULL as CertificateCode,
		--			NULL as Version
		--		FROM SBSC.Customer_Auditors caud
		--		WHERE @AuditorId IS NOT NULL AND caud.AuditorId = @AuditorId
		--	) combined
		--) aud ON aud.CustomerId = c.Id
		--LEFT JOIN (
		--	-- Only include the certification path when filtering by CertificationId
		--	SELECT 
		--		cc.CustomerId,
		--		cc.CertificateNumber,
		--		cert.CertificateCode,
		--		cert.Version
		--	FROM SBSC.Customer_Certifications cc
		--	INNER JOIN SBSC.Certification cert ON cc.CertificateId = cert.Id
		--	WHERE @CertificateId IS NOT NULL AND cc.CertificateId = @CertificateId
		--) cert ON cert.CustomerId = c.Id
		--LEFT JOIN SBSC.Customer_Certifications cc ON cc.CustomerId = c.Id
		--WHERE 
		--	(
		--		@AuditorId IS NOT NULL AND aud.CustomerId IS NOT NULL
		--	)
		--	OR
		--	(
		--		@CertificateId IS NOT NULL AND cert.CustomerId IS NOT NULL
		--	)
		--GROUP BY 
		--	c.Id,
		--	c.CompanyName
		--ORDER BY 
		--	c.CompanyName;


		SELECT DISTINCT
			c.Id AS CustomerId,
			c.CompanyName AS CompanyName,
			MAX(cert.CertificateCode) AS CertificateCode,
			MAX(cc.CertificateNumber) AS CertificateNumber,
			MAX(ISNULL(cert.Version, 1)) AS Version
		FROM 
			SBSC.Customers AS c
		LEFT JOIN (
			-- Include customers from both Certification_Assignment and Customer_Auditors when filtering by AuditorId
			SELECT DISTINCT 
				CustomerId,
				CertificateCode,
				Version
			FROM (
				-- Customers from Certification_Assignment path
				SELECT 
					cc.CustomerId,
					cert.CertificateCode,
					cert.Version
				FROM SBSC.AssignmentCustomerCertification acc
				JOIN SBSC.AssignmentAuditor aa ON aa.AssignmentId = acc.AssignmentId
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				INNER JOIN SBSC.Certification cert ON cc.CertificateId = cert.Id
				WHERE @AuditorId IS NOT NULL AND aa.AuditorId = @AuditorId
            
				UNION
            
				-- Customers from Customer_Auditors path
				SELECT 
					caud.CustomerId,
					NULL as CertificateCode,
					NULL as Version
				FROM SBSC.Customer_Auditors caud
				WHERE @AuditorId IS NOT NULL AND caud.AuditorId = @AuditorId
			) combined
		) aud ON aud.CustomerId = c.Id
		LEFT JOIN (
			-- Only include the certification path when filtering by CertificationId
			SELECT 
				cc.CustomerId,
				cc.CertificateNumber,
				cert.CertificateCode,
				cert.Version
			FROM SBSC.Customer_Certifications cc
			INNER JOIN SBSC.Certification cert ON cc.CertificateId = cert.Id
			WHERE @CertificateId IS NOT NULL AND cc.CertificateId = @CertificateId
		) cert ON cert.CustomerId = c.Id
		LEFT JOIN SBSC.Customer_Certifications cc ON cc.CustomerId = c.Id
		WHERE 
			(
				@AuditorId IS NOT NULL AND aud.CustomerId IS NOT NULL
			)
			OR
			(
				@CertificateId IS NOT NULL AND cert.CustomerId IS NOT NULL
			)
		GROUP BY 
			c.Id,
			c.CompanyName
		ORDER BY 
			c.CompanyName;
	END

	IF @Action = 'LIST'
	BEGIN
		-- Set default sorting column and direction if not provided
		IF @SortColumn IS NULL OR @SortColumn NOT IN ('Id', 'CompanyName', 'CustomerName', 'Email', 'OrgNo', 'CreatedDate', 'CertificationStatus', 'Answers')
			SET @SortColumn = 'CustomerName';
		IF @SortDirection IS NULL OR @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC';


		SET @Offset = (@PageNumber - 1) * @PageSize;
		SET @TotalRecords = 0;

		-- WHERE clause for search filtering with specific fields
		SET @WhereClause = N' WHERE 1=1 AND IsAnonymizes = 0 AND (CustomerType IS NULL OR CustomerType = 0)';

		IF @SearchValue IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND (CompanyName LIKE ''%'' + @SearchValue + ''%'' 
				OR CustomerName LIKE ''%'' + @SearchValue + ''%'' 
				OR Email LIKE ''%'' + @SearchValue + ''%'' 
				OR ChildUsers LIKE ''%'' + @SearchValue + ''%''
				OR OrgNo LIKE ''%'' + @SearchValue + ''%'')';

		IF @CompanyName IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND CompanyName IN (SELECT value FROM STRING_SPLIT(@CompanyName, '',''))';

		--IF @Certifications IS NOT NULL
		--	SET @WhereClause = @WhereClause + N' AND EXISTS (
		--		SELECT 1 FROM STRING_SPLIT(@Certifications, '','') cert 
		--		WHERE Certifications LIKE ''%'' + cert.value + ''%'')';

		IF @CertificationId IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND Certifications LIKE ''%"id":'' + CAST(@CertificationId AS VARCHAR(100)) + '',%''';

		IF @Auditors IS NOT NULL AND EXISTS (SELECT 1 FROM SBSC.Auditor WHERE IsSBSCAuditor = 0 AND Id = @AuditorId)
			SET @WhereClause = @WhereClause + N' AND EXISTS (
				SELECT 1 FROM STRING_SPLIT(@Auditors, '','') aud 
				WHERE AssignedAuditors LIKE ''%'' + aud.value + ''%'')';

		-- Rewritten AuditorIds condition
		--IF @AuditorIds IS NOT NULL
		--    SET @WhereClause = @WhereClause + N' AND Id IN (
		--        SELECT DISTINCT CustomerId 
		--        FROM [SBSC].[Customer_Auditors] 
		--        WHERE AuditorID IN (
		--            SELECT TRY_CAST(value AS INT) 
		--            FROM STRING_SPLIT(@AuditorIds, '','')
		--        ))';

	
		CREATE TABLE #TempCertifications (
			Id INT,
			TempCertifications NVARCHAR(MAX)
		);

		IF @AuditorId IS NOT NULL AND EXISTS (SELECT 1 FROM SBSC.Auditor WHERE IsSBSCAuditor = 0 AND Id = @AuditorId)
		BEGIN
		

			DECLARE @CurrentCertification NVARCHAR(MAX);
			DECLARE @CurrentId INT;
			DECLARE @CurrentJson NVARCHAR(MAX);
			DECLARE @InsertJson NVARCHAR(MAX);

			DECLARE CertificationsCursor CURSOR FOR
			--SELECT Id, TRIM('[]' FROM Certifications) AS TrimmedCertifications FROM SBSC.vw_Customers WHERE Id IN (
		
			SELECT Id, Certifications
			FROM SBSC.vw_Customers
			WHERE 
				(Id IN (
					SELECT DISTINCT CustomerId 
					FROM [SBSC].[Customer_Auditors] 
					WHERE AuditorID = @AuditorId
				)
				OR 
				Id IN (
					SELECT DISTINCT CustomerId FROM SBSC.AssignmentOccasions ao
					INNER JOIN SBSC.AssignmentAuditor aa ON ao.Id = aa.AssignmentId
					WHERE AuditorId = @AuditorId
				))
				AND
				Certifications IS NOT NULL;

			OPEN CertificationsCursor;

			FETCH NEXT FROM CertificationsCursor INTO @CurrentId, @CurrentCertification;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				SET @InsertJson = NULL;
				SET @InsertJson = (
					SELECT cc.*
					FROM OPENJSON(@CurrentCertification)
					WITH (
						id INT,
						customerCertificationId INT,
						certificateCode NVARCHAR(100),
						certificateNumber NVARCHAR(50),
						version DECIMAL(16,2),
						published INT,
						submissionStatus INT,
						certificateTypeId INT,
						certificateTypeTitle NVARCHAR(100),
						certificationStatus NVARCHAR(MAX)
					) cc
					INNER JOIN SBSC.Auditor_Certifications ac ON cc.id = ac.CertificationId
					WHERE ac.AuditorId = @AuditorId
					FOR JSON PATH
				);

				INSERT INTO #TempCertifications (Id, TempCertifications) 
				VALUES (@CurrentId, @InsertJson);

				FETCH NEXT FROM CertificationsCursor INTO @CurrentId, @CurrentCertification;
			END;

			CLOSE CertificationsCursor;
			DEALLOCATE CertificationsCursor;

		END

		IF @CustomerName IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND CustomerName LIKE ''%'' + @CustomerName + ''%''';

		IF @Email IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND Email LIKE ''%'' + @Email + ''%''';

		IF @OrgNo IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND OrgNo LIKE ''%'' + @OrgNo + ''%''';

		IF @CreatedDate IS NOT NULL
			SET @WhereClause = @WhereClause + N' AND CreatedDate = @CreatedDate';

		-- Enhanced Certification Status filtering
		IF @CertificationStatus IS NOT NULL
		BEGIN
			-- Parse the certification status filter (can be comma-separated values)
			DECLARE @StatusFilter NVARCHAR(MAX) = @CertificationStatus;
        
			-- Add certification status filtering based on the calculated status
			SET @WhereClause = @WhereClause + N' AND EXISTS (
				SELECT 1 FROM STRING_SPLIT(@StatusFilter, '','') status_filter
				WHERE CASE 
							WHEN vc.IsActive = 0 THEN ''Not Activated''
							ELSE
								CASE 
									WHEN ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
									THEN
										CASE
											WHEN ccert.SubmissionStatus = 1 THEN ''Pending''
											WHEN ccert.SubmissionStatus = 2 THEN ''Deviation (Rejected)''
											WHEN ccert.SubmissionStatus = 3 THEN ''Report''
											WHEN ccert.SubmissionStatus = 4 THEN ''Passed''
											WHEN ccert.SubmissionStatus = 6 THEN ''Passed with conditions''
											ELSE ''Not Submitted''
										END
									ELSE ''Not Submitted''
								END
						END = status_filter.value
			)';
		END

		-- Count total records
		DECLARE @CountSQL NVARCHAR(MAX);

		IF @AuditorId IS NOT NULL AND EXISTS (SELECT 1 FROM SBSC.Auditor WHERE IsSBSCAuditor = 0 AND Id = @AuditorId)
		BEGIN
			SET @CountSQL = N'SELECT @TotalRecordsOUT = COUNT_BIG(1) FROM SBSC.vw_Customers vc WITH (NOLOCK)
						INNER JOIN #TempCertifications tc ON tc.Id = vc.Id
						LEFT JOIN SBSC.Customer_Certifications ccert ON ccert.CustomerId = vc.Id AND ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
						' + @WhereClause;
		END
		ELSE
		BEGIN
			SET @CountSQL = N'SELECT @TotalRecordsOUT = COUNT_BIG(1) FROM SBSC.vw_Customers vc WITH (NOLOCK)
						LEFT JOIN SBSC.Customer_Certifications ccert ON ccert.CustomerId = vc.Id AND ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
						' + @WhereClause;
		END

		DECLARE @ParmDefinition NVARCHAR(MAX);
		SET @ParmDefinition = N'@SearchValue NVARCHAR(100), 
							   @CompanyName NVARCHAR(MAX),
							   @Certifications NVARCHAR(MAX),
							   @CertificationId INT,
							   @Auditors NVARCHAR(MAX),
							   @AuditorId INT,
							   @AuditorIds NVARCHAR(MAX),
							   @CustomerName NVARCHAR(100), 
							   @Email NVARCHAR(100), 
							   @OrgNo NVARCHAR(100), 
							   @CreatedDate DATETIME, 
							   @CertificationStatus NVARCHAR(MAX),
							   @StatusFilter NVARCHAR(MAX),
							   @TotalRecordsOUT INT OUTPUT';

		EXEC sp_executesql @CountSQL, 
						  @ParmDefinition,
						  @SearchValue = @SearchValue,
						  @CompanyName = @CompanyName,
						  @Certifications = @Certifications,
						  @CertificationId = @CertificationId,
						  @Auditors = @Auditors,
						  @AuditorId = @AuditorId,
						  @AuditorIds = @AuditorIds,
						  @CustomerName = @CustomerName,
						  @Email = @Email,
						  @OrgNo = @OrgNo,
						  @CreatedDate = @CreatedDate,
						  @CertificationStatus = @CertificationStatus,
						  @StatusFilter = @StatusFilter,
						  @TotalRecordsOUT = @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);
	
		-- Retrieve paginated data using cleaner syntax
		IF @AuditorId IS NOT NULL AND EXISTS (SELECT 1 FROM SBSC.Auditor WHERE IsSBSCAuditor = 0 AND Id = @AuditorId)
		BEGIN
			SET @ListSQL = N'SELECT
						vc.[Id]
					  ,vc.[CompanyName]
					  ,vc.[Email]
					  ,vc.[CustomerName]
					  ,vc.[CaseId]
					  ,vc.[CaseNumber]
					  ,vc.[OrgNo]
					  ,vc.[VATNo]
					  ,vc.[ContactNumber]
					  ,vc.[ContactCellPhone]
					  ,vc.[DefaultAuditor]
					  ,vc.[CreatedDate]
					  ,vc.[IsAnonymizes]
					  ,tc.TempCertifications  AS Certifications
					  ,(SELECT Name FROM [SBSC].[Auditor] WHERE Id = @AuditorId) AS AssignedAuditors
					  ,vc.[CertificateNumbers]
					  ,vc.[CustomerCertificationIds]
					  ,vc.[MfaStatus]
					  ,vc.[IsActive]
					  ,CASE
							WHEN ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
							THEN
								CONCAT(ISNULL(cr_count.ResponseCount, 0), ''/61'') 
							ELSE ''-''
						END AS Answers
					  ,vc.[IsPasswordChanged]
					  ,vc.[PasswordChangedDate]
					  ,vc.DefaultLangId
					  ,vc.ChildUsers
					FROM SBSC.vw_Customers vc WITH (NOLOCK)
					LEFT JOIN SBSC.Customer_Certifications ccert 
					ON ccert.CustomerId = vc.Id AND ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
					LEFT JOIN (
						SELECT 
							CustomerId, 
							COUNT(*) AS ResponseCount
						FROM SBSC.CustomerResponse
						GROUP BY CustomerId
					) cr_count ON vc.Id = cr_count.CustomerId
					INNER JOIN #TempCertifications tc ON tc.Id = vc.Id' 
					+ @WhereClause +
					N' ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + 
					N' OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS FETCH NEXT ' + 
					CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';
		END
		ELSE
		BEGIN
			SET @ListSQL = N'SELECT 
						vc.[Id],
						vc.[CompanyName],
						vc.[Email],
						vc.[CustomerName],
						vc.[CaseId],
						vc.[CaseNumber],
						vc.[OrgNo],
						vc.[VATNo],
						vc.[ContactNumber],
						vc.[ContactCellPhone],
						vc.[DefaultAuditor],
						vc.[CreatedDate],
						vc.[IsAnonymizes],
						vc.[Certifications],
						vc.[AssignedAuditors],
						vc.[CertificateNumbers],
						vc.[CustomerCertificationIds],
						vc.[MfaStatus],
						vc.[IsActive],
						CASE
							WHEN ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
							THEN
								CONCAT(ISNULL(cr_count.ResponseCount, 0), ''/61'') 
							ELSE ''-''
						END AS Answers,
						vc.[IsPasswordChanged],
						vc.[PasswordChangedDate],
						vc.[DefaultLangId],
						vc.[ChildUsers]
					FROM SBSC.vw_Customers vc WITH (NOLOCK)
					LEFT JOIN SBSC.Customer_Certifications ccert 
					ON ccert.CustomerId = vc.Id AND ccert.CertificateId = (SELECT Id FROM SBSC.Certification WHERE CertificateCode = ''SSF1101Cyber Security_Live'')
					LEFT JOIN (
						SELECT 
							CustomerId, 
							COUNT(*) AS ResponseCount
						FROM SBSC.CustomerResponse
						GROUP BY CustomerId
					) cr_count ON vc.Id = cr_count.CustomerId' 
					+ @WhereClause +
					N' ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + 
					N' OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS FETCH NEXT ' + 
					CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';
		END
	
		SET @ListParamDefinition = N'@SearchValue NVARCHAR(100), 
								   @CompanyName NVARCHAR(MAX), 
								   @CustomerName NVARCHAR(100), 
								   @Certifications NVARCHAR(MAX),
								   @CertificationId INT,
								   @Auditors NVARCHAR(MAX),
								   @AuditorId INT,
								   @AuditorIds NVARCHAR(MAX),
								   @Email NVARCHAR(100), 
								   @OrgNo NVARCHAR(100), 
								   @CreatedDate DATETIME,
								   @CertificationStatus NVARCHAR(MAX),
								   @StatusFilter NVARCHAR(MAX)';
		EXEC sp_executesql @ListSQL, 
						  @ListParamDefinition,
						  @SearchValue = @SearchValue,
						  @CompanyName = @CompanyName,
						  @Certifications = @Certifications,
						  @CertificationId = @CertificationId,
						  @Auditors = @Auditors,
						  @AuditorId = @AuditorId,
						  @AuditorIds = @AuditorIds,
						  @CustomerName = @CustomerName,
						  @Email = @Email,
						  @OrgNo = @OrgNo,
						  @CreatedDate = @CreatedDate,
						  @CertificationStatus = @CertificationStatus,
						  @StatusFilter = @StatusFilter;

		-- Return total records and pages for pagination
		SELECT @TotalRecords AS TotalRecords, @TotalPages AS TotalPages;
		DROP TABLE #TempCertifications;
	END;


	IF @Action = 'ANONYMIZE'
	BEGIN
		-- Ensure the customer ID exists
		IF NOT EXISTS (SELECT 1 FROM SBSC.vw_CustomerDetails WHERE Id = @Id)
		BEGIN
			RAISERROR('Customer ID not found.', 16, 1);
			RETURN;
		END
		-- Step 3: Get the next auto-incremented value from the sequence
		DECLARE @AutoIncrement INT;
		SET @AutoIncrement = NEXT VALUE FOR Seq_Anonymization;

		-- Step 4: Update the email with 'anonymize[AutoIncrement]@anonymous.com'
		UPDATE SBSC.CustomerCredentials 
		SET 
			Email = CONCAT('anonymize', @AutoIncrement, '@anonymous.com'),
			Password = NULL,
			MfaStatus = 0,
			IsPasswordChanged = 0,  -- Assuming you want to reset password status
			PasswordChangedDate = NULL,  -- Nullify the password change date
			IsActive = 0
		WHERE CustomerId = @Id;

		UPDATE SBSC.Customers 
		SET 
			CompanyName = 'anonymize',
			CustomerName = 'anonymize', 
			CaseId = '',
			OrgNo = '',
			DefaultAuditor = NULL,
			IsAnonymizes = 1
		WHERE Id = @Id;

		-- Return success message
		SELECT 'Customer data has been anonymized successfully.' AS Message;
	END

	-- DELETE operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
        
			-- Check if the customer exists
			DECLARE @Exists INT;
			SELECT @Exists = COUNT(*)
			FROM SBSC.Customers
			WHERE Id = @Id;

			IF @Exists = 0
			BEGIN
				RAISERROR('Customer with Id %d does not exist.', 16, 1, @Id);
				RETURN; -- Exit the procedure if the customer does not exist
			END

			-- Step 1: Delete dependent records in the correct order
			--DELETE FROM SBSC.Certification_Assignment
			--WHERE CustomerCertificationId IN (
			--	SELECT CustomerCertificationId 
			--	FROM SBSC.Customer_Certifications 
			--	WHERE CustomerId = @Id
			--);

			DELETE from SBSC.CustomerResponse WHERE CustomerId = @Id

			DELETE FROM SBSC.CommentThread WHERE CustomerId = @Id

			DELETE FROM SBSC.DecisionRemarks WHERE CustomerCertificationId IN (
				SELECT CustomerCertificationId 
				FROM SBSC.Customer_Certifications 
				WHERE CustomerId = @Id);

			DELETE FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationId IN (
				SELECT CustomerCertificationId 
				FROM SBSC.Customer_Certifications 
				WHERE CustomerId = @Id);
		

			DELETE FROM SBSC.Customer_Certifications
			WHERE CustomerId = @Id;

			DELETE FROM SBSC.Customer_Address WHERE CustomerId = @Id;

			-- Step 2: Delete other related records
			DELETE FROM SBSC.CustomerCredentials WHERE CustomerId = @Id;

			-- Step 3: Finally, delete the customer record
			DELETE FROM SBSC.Customers WHERE Id = @Id;

			COMMIT TRANSACTION;

			-- Return the deleted customer ID
			SELECT @Id AS Id;
		END TRY
		BEGIN CATCH
			-- Rollback transaction in case of error
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			-- Raise the caught error
			DECLARE @CatchErrorMessage NVARCHAR(4000);
			DECLARE @CatchErrorSeverity INT;
			DECLARE @CatchErrorState INT;

			SET @CatchErrorMessage = ERROR_MESSAGE();
			SET @CatchErrorSeverity = ERROR_SEVERITY();
			SET @CatchErrorState = ERROR_STATE();

			RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState);
		END CATCH;
	END

	-- DELETE operation
	ELSE IF @Action = 'DELETE_SECONDARY'
	BEGIN
		BEGIN TRY
			IF NOT EXISTS (SELECT 1 FROM SBSC.CustomerCredentials WHERE Id = @SecondaryUserId)
			BEGIN
				RAISERROR('Customer credential with ID %d does not exist.', 16, 1, @SecondaryUserId);
				RETURN;
			END

			-- Check if the provided secondaryUserId is of primary user (customerType IS NULL or customerType = 0)
			IF EXISTS (SELECT 1 FROM SBSC.CustomerCredentials WHERE Id = @SecondaryUserId AND (CustomerType IS NULL OR CustomerType = 0))
			BEGIN
				RAISERROR('Cannot delete primary user. User ID %d is a primary user.', 16, 1, @SecondaryUserId);
				RETURN;
			END

			DELETE FROM SBSC.CustomerCredentials WHERE Id = @SecondaryUserId;

			-- Return the deleted customer ID
			SELECT @SecondaryUserId AS Id;
		END TRY
		BEGIN CATCH
			-- Rollback transaction in case of error
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			-- Raise the caught error
			DECLARE @CatchErrorMessageSecondary NVARCHAR(4000);
			DECLARE @CatchErrorSeveritySecondary INT;
			DECLARE @CatchErrorStateSecondary INT;

			SET @CatchErrorMessageSecondary = ERROR_MESSAGE();
			SET @CatchErrorSeveritySecondary = ERROR_SEVERITY();
			SET @CatchErrorStateSecondary = ERROR_STATE();

			RAISERROR(@CatchErrorMessageSecondary, @CatchErrorSeveritySecondary, @CatchErrorStateSecondary);
		END CATCH;
	END

	--ELSE IF @Action = 'DELETE_ASSIGNED_AUDITORS'
	--BEGIN
	--    BEGIN TRY
	--        BEGIN TRANSACTION;
        
	--        -- Validate CustomerCertificationId
	--        IF @CustomerCertificationId IS NULL OR @CustomerCertificationId <= 0
	--        BEGIN
	--            RAISERROR('Invalid or missing CustomerCertificationId.', 16, 1);
	--            RETURN;
	--        END

	--        -- Validate FromDate
	--        IF @FromDate IS NULL
	--        BEGIN
	--            RAISERROR('FromDate is required.', 16, 1);
	--            RETURN;
	--        END

	--        -- Validate ToDate
	--        IF @ToDate IS NULL
	--        BEGIN
	--            RAISERROR('ToDate is required.', 16, 1);
	--            RETURN;
	--        END

	--        -- Check if the certification exists
	--        DECLARE @CertificationExists INT;
	--        SELECT @CertificationExists = COUNT(*)
	--        FROM SBSC.Customer_Certifications
	--        WHERE CustomerCertificationId = @CustomerCertificationId;

	--        IF @CertificationExists = 0
	--        BEGIN
	--            RAISERROR('Certification with Id %d does not exist.', 16, 1, @CustomerCertificationId);
	--            RETURN;
	--        END

	--        -- Delete Auditor Assignments with specific FromDate and ToDate
	--        --DELETE FROM SBSC.Certification_Assignment
	--        --WHERE CustomerCertificationId = @CustomerCertificationId
	--        --  AND FromDate = @FromDate
	--        --  AND ToDate = @ToDate;

	--		DELETE FROM SBSC.AssignmentCustomerCertification
	--        WHERE CustomerCertificationId = @CustomerCertificationId
	--          AND FromDate = @FromDate
	--          AND ToDate = @ToDate;

	--        COMMIT TRANSACTION;

	--        -- Return success message
	--        SELECT 
	--            @CustomerCertificationId AS DeletedCustomerCertificationId;
	--    END TRY
	--    BEGIN CATCH
	--        -- Rollback transaction in case of error
	--        IF @@TRANCOUNT > 0
	--            ROLLBACK TRANSACTION;

	--        SET @CatchErrorMessage = ERROR_MESSAGE();
	--        SET @CatchErrorSeverity = ERROR_SEVERITY();
	--        SET @CatchErrorState = ERROR_STATE();

	--        RAISERROR(@CatchErrorMessage, @CatchErrorSeverity, @CatchErrorState);
	--    END CATCH;
	--END



	ELSE IF @Action = 'UPDATE'
	BEGIN
		-- Check for required parameters
		IF @Id IS NULL
		BEGIN
			RAISERROR('Missing required parameter: Id for UPDATE operation.', 16, 1);
			RETURN;
		END

		BEGIN TRY
			BEGIN TRANSACTION;

			-- Update Customers table
			UPDATE SBSC.Customers
			SET 
				CustomerName = LEFT(ISNULL(@CustomerName, CustomerName), 255),
				CompanyName = LEFT(ISNULL(@CompanyName, CompanyName), 255),
				CaseId = LEFT(ISNULL(@CaseId, CaseId), 100),
				OrgNo = LEFT(ISNULL(@OrgNo, OrgNo), 100),
				CaseNumber = LEFT(ISNULL(@CaseNumber, CaseNumber), 100),
				VATNo = LEFT(ISNULL(@VATNo, VATNo), 100),
				ContactNumber = LEFT(ISNULL(@ContactNumber, ContactNumber), 100)
			WHERE Id = @Id;

			-- Update CustomerCredentials table
			UPDATE SBSC.CustomerCredentials
			SET 
				Email = LEFT(LTRIM(RTRIM(LOWER(ISNULL(@Email, Email)))), 255),
				IsPasswordChanged = ISNULL(@IsPasswordChanged, IsPasswordChanged),
				PasswordChangedDate = ISNULL(@PasswordChangedDate, PasswordChangedDate),
				MfaStatus = ISNULL(@MFAStatus, MfaStatus),
				DefaultLangId = ISNULL(@DefaultLangId, DefaultLangId),
				IsActive = ISNULL(@IsActive, IsActive)
			WHERE CustomerId = @Id AND (CustomerType IS NULL OR CustomerType = 0);

			-- Handle Certifications
			IF NOT EXISTS (SELECT 1 FROM @CertificationsId)
			BEGIN
				-- Delete all certifications if none provided
				-- First delete related assignment records
				DELETE aa FROM SBSC.AssignmentAuditor aa
				INNER JOIN SBSC.AssignmentCustomerCertification acc ON aa.AssignmentId = acc.AssignmentId
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				WHERE cc.CustomerId = @Id;

				DELETE acc FROM SBSC.AssignmentCustomerCertification acc
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				WHERE cc.CustomerId = @Id;

				DELETE ao FROM SBSC.AssignmentOccasions ao
				INNER JOIN SBSC.AssignmentCustomerCertification acc ON ao.Id = acc.AssignmentId
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				WHERE cc.CustomerId = @Id;

				DELETE FROM SBSC.Customer_Certifications
				WHERE CustomerId = @Id;
			END
			ELSE
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

				-- Delete assignments for certifications being removed
				DELETE aa FROM SBSC.AssignmentAuditor aa
				INNER JOIN SBSC.AssignmentCustomerCertification acc ON aa.AssignmentId = acc.AssignmentId
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				WHERE cc.CustomerId = @Id
				AND NOT EXISTS (
					SELECT 1 
					FROM @CertificationsId cid 
					WHERE cid.CertificationId = cc.CertificateId
				);

				DELETE acc FROM SBSC.AssignmentCustomerCertification acc
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				WHERE cc.CustomerId = @Id
				AND NOT EXISTS (
					SELECT 1 
					FROM @CertificationsId cid 
					WHERE cid.CertificationId = cc.CertificateId
				);

				DELETE ao FROM SBSC.AssignmentOccasions ao
				INNER JOIN SBSC.AssignmentCustomerCertification acc ON ao.Id = acc.AssignmentId
				INNER JOIN SBSC.Customer_Certifications cc ON acc.CustomerCertificationId = cc.CustomerCertificationId
				WHERE cc.CustomerId = @Id
				AND NOT EXISTS (
					SELECT 1 
					FROM @CertificationsId cid 
					WHERE cid.CertificationId = cc.CertificateId
				);

				-- Delete certifications not in the input
				DELETE cc
				FROM SBSC.Customer_Certifications cc
				WHERE cc.CustomerId = @Id
				AND NOT EXISTS (
					SELECT 1 
					FROM @CertificationsId cid 
					WHERE cid.CertificationId = cc.CertificateId
				);

				-- Temporary table to capture inserted Ids and CertificationIds
				DECLARE @InsertedCertsUpdate TABLE (Id INT, CertificationId INT, SubmissionStatus SMALLINT);

				-- Insert only NEW certifications (ones that don't already exist for this customer)
				INSERT INTO SBSC.Customer_Certifications (
					CustomerId, 
					CertificateId, 
					Validity, 
					AuditYears, 
					CreatedDate,
					SubmissionStatus,
					DeviationEndDate
				)
				OUTPUT 
					INSERTED.CustomerCertificationId,
					INSERTED.CertificateId,
					INSERTED.SubmissionStatus
				INTO @InsertedCertsUpdate (Id, CertificationId, SubmissionStatus)
				SELECT 
					@Id, 
					cid.CertificationId, 
					c.Validity,
					c.AuditYears,
					GETUTCDATE(),
					CASE WHEN c.IsAuditorInitiated = 1 THEN 11 ELSE 0 END,
					NULL
				FROM @CertificationsId cid
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId
				WHERE NOT EXISTS (
					SELECT 1 
					FROM SBSC.Customer_Certifications cc 
					WHERE cc.CustomerId = @Id 
					AND cc.CertificateId = cid.CertificationId
				);

				-- Generate CertificateNumber for new certifications
				UPDATE cc
				SET CertificateNumber = 
					RIGHT(CAST(YEAR(GETDATE()) AS NVARCHAR(4)), 2) + '-' + 
					CAST(ic.Id AS NVARCHAR(20))
				FROM SBSC.Customer_Certifications cc
				INNER JOIN @InsertedCertsUpdate ic ON cc.CustomerCertificationId = ic.Id
				WHERE cc.CustomerId = @Id;

				-- Create individual assignment occasions and assignments for each new certification
				DECLARE @UpdateCertCursor CURSOR;
				DECLARE @CurrentUpdateCertId INT, @CurrentUpdateCustomerCertId INT, @CurrentUpdateCustomerStatus SMALLINT, @NewUpdateAssignmentOccasionId INT, @NewCustomerCertificationDetailsId INT;
            
				SET @UpdateCertCursor = CURSOR FOR
				SELECT ic.Id, ic.CertificationId, ic.SubmissionStatus 
				FROM @InsertedCertsUpdate ic
				INNER JOIN SBSC.Certification c ON c.Id = ic.CertificationId
				WHERE c.IsAuditorInitiated = 0;  -- Only update the customer certification details for online (auditorInitiated=0) certifications at first
            
				OPEN @UpdateCertCursor;
				FETCH NEXT FROM @UpdateCertCursor INTO @CurrentUpdateCustomerCertId, @CurrentUpdateCertId, @CurrentUpdateCustomerStatus;
            
				WHILE @@FETCH_STATUS = 0
				BEGIN
					INSERT INTO SBSC.CustomerCertificationDetails(CustomerCertificationId, Recertification, Status, CreatedDate)
					VALUES (@CurrentUpdateCustomerCertId, 0, 0, GETUTCDATE());
					SET @NewCustomerCertificationDetailsId = SCOPE_IDENTITY();

					-- Create assignment occasion for this certification
					INSERT INTO SBSC.AssignmentOccasions (FromDate, ToDate, AssignedTime, CustomerId, Status, LastUpdatedDate)
					VALUES (CONVERT(DATE, GETUTCDATE()), NULL, GETUTCDATE(), @Id, 0, GETUTCDATE());
					SET @NewUpdateAssignmentOccasionId = SCOPE_IDENTITY();

					INSERT INTO SBSC.AssignmentAuditor (AssignmentId, AuditorId, IsLeadAuditor)
					SELECT DISTINCT
						@NewAssignmentOccasionId,
						AuditorId,
						0 AS IsLeadAuditor
					FROM (
						-- Get customer-specific auditors
						SELECT ca.AuditorId
						FROM SBSC.Customer_Auditors ca
						WHERE ca.CustomerId = @Id
        
						UNION
        
						-- Get certification-specific auditors
						SELECT ac.AuditorId
						FROM SBSC.Auditor_Certifications ac
						WHERE ac.CertificationId = @CurrentUpdateCertId
					) AS CombinedAuditors;

					-- Create assignment-certification link
					INSERT INTO SBSC.AssignmentCustomerCertification (
						AssignmentId,
						CustomerCertificationId,
						CustomerCertificationDetailsId,
						Recertification
					)
					VALUES (
						@NewUpdateAssignmentOccasionId,
						@CurrentUpdateCustomerCertId,
						@NewCustomerCertificationDetailsId,
						ISNULL(@Recertification, 0)
					);

					FETCH NEXT FROM @UpdateCertCursor INTO @CurrentUpdateCustomerCertId, @CurrentUpdateCertId, @CurrentUpdateCustomerStatus;
				END
            
				CLOSE @UpdateCertCursor;
				DEALLOCATE @UpdateCertCursor;

				-- Update existing certifications with latest values
				UPDATE cc
				SET 
					Validity = c.Validity,
					AuditYears = c.AuditYears,
					CreatedDate = GETDATE()
				FROM SBSC.Customer_Certifications cc
				INNER JOIN @CertificationsId cid ON cc.CertificateId = cid.CertificationId
				INNER JOIN SBSC.Certification c ON c.Id = cid.CertificationId
				WHERE cc.CustomerId = @Id;
			END

			COMMIT TRANSACTION;

			-- Return updated data
			DECLARE @CertificationsUpdateJson NVARCHAR(MAX);
			SELECT @CertificationsUpdateJson = (
				SELECT 
					cc.CertificateNumber,
					c.CertificateCode
				FROM SBSC.Customer_Certifications cc
				INNER JOIN SBSC.Certification c ON cc.CertificateId = c.Id
				WHERE cc.CustomerId = @Id
				FOR JSON PATH
			);

			SELECT 
				@Id AS Id, 
				CompanyName, 
				Email, 
				@CertificationsUpdateJson AS Certifications
			FROM SBSC.Customers c
			INNER JOIN SBSC.CustomerCredentials cc ON c.Id = cc.CustomerId
			WHERE c.Id = @Id AND (cc.CustomerType IS NULL OR cc.CustomerType = 0);

		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			DECLARE @ErrorMessageUpdateCustomer NVARCHAR(4000), @ErrorSeverityUpdateCustomer INT, @ErrorStateUpdateCustomer INT;
			SELECT 
				@ErrorMessageUpdateCustomer = ERROR_MESSAGE(),
				@ErrorSeverityUpdateCustomer = ERROR_SEVERITY(),
				@ErrorStateUpdateCustomer = ERROR_STATE();
			RAISERROR(@ErrorMessageUpdateCustomer, @ErrorSeverityUpdateCustomer, @ErrorStateUpdateCustomer);
		END CATCH;
	END

	ELSE IF @Action = 'UPDATE_SECONDARY'
	BEGIN
		BEGIN TRY
			-- Check for required parameters
			IF @SecondaryUserId IS NULL
			BEGIN
				RAISERROR('Missing required parameter: SeondaryUserId for UPDATE operation.', 16, 1);
				RETURN;
			END

			IF NOT EXISTS (SELECT 1 FROM SBSC.CustomerCredentials WHERE Id = @SecondaryUserId)
			BEGIN
				RAISERROR('Customer credential with ID %d does not exist.', 16, 1, @SecondaryUserId);
				RETURN;
			END

			-- Check if the provided secondaryUserId is of primary user (customerType IS NULL or customerType = 0)
			IF EXISTS (SELECT 1 FROM SBSC.CustomerCredentials WHERE Id = @SecondaryUserId AND (CustomerType IS NULL OR CustomerType = 0))
			BEGIN
				RAISERROR('Cannot update primary user. User ID %d is a primary user.', 16, 1, @SecondaryUserId);
				RETURN;
			END

			-- Update CustomerCredentials table
			UPDATE SBSC.CustomerCredentials
			SET 
				Email = LEFT(LTRIM(RTRIM(LOWER(ISNULL(@Email, Email)))), 255),
				IsPasswordChanged = ISNULL(@IsPasswordChanged, IsPasswordChanged),
				PasswordChangedDate = ISNULL(@PasswordChangedDate, PasswordChangedDate),
				MfaStatus = ISNULL(@MFAStatus, MfaStatus),
				DefaultLangId = ISNULL(@DefaultLangId, DefaultLangId),
				IsActive = ISNULL(@IsActive, IsActive),
				UserName = ISNULL(@CustomerName, UserName),
				CustomerType = CASE 
					WHEN @CustomerType IS NULL OR @CustomerType = 0 THEN CustomerType 
					ELSE @CustomerType 
				END
			WHERE Id = @SecondaryUserId;
			
			SELECT @Email AS Email, @CustomerName AS CustomerName, @MFAStatus AS MfaStatus; 

		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			DECLARE @ErrorMessageUpdateCustomerSecondary NVARCHAR(4000), @ErrorSeverityUpdateCustomerSecondary INT, @ErrorStateUpdateCustomerSecondary INT;
			SELECT 
				@ErrorMessageUpdateCustomerSecondary = ERROR_MESSAGE(),
				@ErrorSeverityUpdateCustomerSecondary = ERROR_SEVERITY(),
				@ErrorStateUpdateCustomerSecondary = ERROR_STATE();
			RAISERROR(@ErrorMessageUpdateCustomerSecondary, @ErrorSeverityUpdateCustomerSecondary, @ErrorStateUpdateCustomerSecondary);
		END CATCH;
	END

	-- UPDATE operation
    ELSE IF @Action = 'UPDATE_USER_LANG'
    BEGIN
        -- Check if the email already exists for another user
        IF @Email IS NULL
        BEGIN
            RAISERROR('Enter a valid User email.', 16, 1)
            RETURN
        END

        BEGIN TRY
			-- Update AdminUser table
			UPDATE CustomerCredentials
			SET 
			DefaultLangId = ISNULL(@DefaultLangID, DefaultLangId)
			WHERE Email = @Email;

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
        IF @Email IS NULL
        BEGIN
            RAISERROR('Enter a valid User email.', 16, 1)
            RETURN
        END

        BEGIN TRY
			-- Update AdminUser table
			UPDATE CustomerCredentials
			SET 
			MfaStatus = @MFAStatus
			WHERE Email = @Email;

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

	ELSE IF @Action = 'UPDATE_VALIDITY_AND_AUDIT_YEAR'
BEGIN
    -- Check for required parameters
    IF @CustomerId IS NULL OR @CertificateId IS NULL
    BEGIN
        RAISERROR('Missing required parameters: CustomerId or CertificateId for UPDATE operation.', 16, 1);
        RETURN;
    END
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Check if the record exists for the given CustomerId and CertificateId
        IF NOT EXISTS (
            SELECT 1
            FROM SBSC.Customer_Certifications
            WHERE CustomerId = @CustomerId AND CertificateId = @CertificateId
        )
        BEGIN
            RAISERROR('No certification record found for the provided CustomerId and CertificateId.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END
        
        -- Update the Validity and AuditYears for the given CustomerId and CertificateId
        UPDATE SBSC.Customer_Certifications
        SET 
            Validity = ISNULL(@Validity, Validity),
            AuditYears = @AuditYears  -- Direct assignment without any formatting
        WHERE CustomerId = @CustomerId AND CertificateId = @CertificateId;
        
        -- Commit transaction
        COMMIT TRANSACTION;
        
        -- Return the full record
        SELECT 
            CustomerCertificationId,
            CustomerId,
            CertificateId,
            CertificateNumber,
            Validity,
            AuditYears,
            IssueDate,
            CreatedDate
        FROM SBSC.Customer_Certifications
        WHERE CustomerId = @CustomerId AND CertificateId = @CertificateId;
    END TRY
    BEGIN CATCH
        -- Rollback on error
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        SELECT 
            @ErrorMessage = ERROR_MESSAGE(), 
            @ErrorSeverity = ERROR_SEVERITY(), 
            @ErrorState = ERROR_STATE();
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
END

	ELSE IF @Action = 'GET_CERTIFICATE_AUDITYEARS'
	BEGIN
		SET NOCOUNT ON;
		SELECT 
			cc.CertificateId,
			c.CertificateCode,
			cc.CustomerCertificationId,
			cc.CertificateNumber,
			cc.Validity,
			cc.AuditYears,
			cc.IssueDate,
			-- CustomerCertificationDetails data for MAX(Recertification) combination
			ccd_max.AddressId,
			ca.City AS Address,
			ccd_max.DepartmentId,
			cd.DepartmentName,
			ccd_max.Recertification,
			ccd_max.Id AS CustomerCertificationDetailsId,
			c.AuditYears AS CertificationAuditYear,
			(
				-- AuditDetails filtered by CustomerCertificationId, AddressId and DepartmentId for all recertification values
				SELECT
					CAST(value AS INT) AS Id,
					ccd_audit.Id AS CustomerCertificationDetailsId,
					ccd_audit.[Status] AS SubmissionStatus,
					cra.JobId,
					cra.AuditYear,
					cra.AuditDate,
					cra.Recertification,
					cra.CreatedDate
				FROM STRING_SPLIT(cc.AuditYears, ',') ss
				LEFT JOIN SBSC.CustomerRecertificationAudits cra 
					ON cra.CustomerCertificationId = cc.CustomerCertificationId 
					AND cra.AuditYear = CAST(ss.value AS INT)
				LEFT JOIN SBSC.CustomerCertificationDetails ccd_audit ON cra.CustomerCertificationDetailsId = ccd_audit.Id
				WHERE ccd_audit.CustomerCertificationId = cc.CustomerCertificationId
					AND ccd_audit.AddressId = ccd_max.AddressId
					AND ccd_audit.DepartmentId = ccd_max.DepartmentId
				FOR JSON PATH
			) AS AuditDetails
		FROM 
			SBSC.Customer_Certifications cc
			LEFT JOIN SBSC.Certification c ON cc.CertificateId = c.Id
			-- Join with CustomerCertificationDetails having MAX recertification for each combination
			INNER JOIN SBSC.CustomerCertificationDetails ccd_max ON ccd_max.CustomerCertificationId = cc.CustomerCertificationId
			LEFT JOIN SBSC.Customer_Address ca ON ccd_max.AddressId = ca.Id
			LEFT JOIN SBSC.Customer_Department cd ON ccd_max.DepartmentId = cd.Id
			LEFT JOIN (
				-- Subquery to get MAX recertification for each CustomerCertificationId, AddressId, DepartmentId combination
				SELECT 
					CustomerCertificationId,
					AddressId,
					DepartmentId,
					MAX(Recertification) AS MaxRecertification
				FROM SBSC.CustomerCertificationDetails
				GROUP BY CustomerCertificationId, AddressId, DepartmentId
			) max_recert ON ccd_max.CustomerCertificationId = max_recert.CustomerCertificationId
						AND ccd_max.AddressId = max_recert.AddressId
						AND ccd_max.DepartmentId = max_recert.DepartmentId
						AND ccd_max.Recertification = max_recert.MaxRecertification
		WHERE 
			cc.CustomerId = @Id;
	END


	-- UPDATE_COLUMN operation
	ELSE IF @Action = 'UPDATE_COLUMN'
	BEGIN
		IF EXISTS (
			SELECT 1 
			FROM SBSC.Customers 
			WHERE Id = @Id
		)
		BEGIN
			DECLARE @SQL NVARCHAR(MAX) = 'UPDATE SBSC.Customers SET ' + QUOTENAME(@ColumnName) + ' = @NewValue WHERE Id = @Id';
			EXEC sp_executesql @SQL, N'@Id INT, @NewValue NVARCHAR(500)', @Id, @NewValue;

			SELECT 'Column updated successfully.' AS Message;
		END
		ELSE
		BEGIN
			RAISERROR('Customer with Id %d does not exist.', 16, 1, @Id);
		END
	END


	ELSE IF @Action = 'DELETE_SBSC_CUSTOMER'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
        
			
			SET @Id = (SELECT TOP 1 Id FROM SBSC.Customers WHERE CaseId = @CaseId AND CaseNumber = @CaseNumber)

			-- Check if the customer exists
			DECLARE @Exist INT;
			SELECT @Exist = COUNT(*)
			FROM SBSC.Customers
			WHERE Id = @Id;

			IF @Exist <= 0
			BEGIN
				RAISERROR('Customer  does not exist.',16, 1);

				RETURN; -- Exit the procedure if the customer does not exist
			END

			-- Step 1: Delete dependent records in the correct order
			--DELETE FROM SBSC.Certification_Assignment
			--WHERE CustomerCertificationId IN (
			--	SELECT CustomerCertificationId 
			--	FROM SBSC.Customer_Certifications 
			--	WHERE CustomerId = @Id
			--);

			DELETE FROM SBSC.AssignmentCustomerCertification
			WHERE CustomerCertificationId IN (
				SELECT CustomerCertificationId 
				FROM SBSC.Customer_Certifications 
				WHERE CustomerId = @Id
			);


			DELETE FROM SBSC.Customer_Certifications
			WHERE CustomerId = @Id;

			DELETE FROM SBSC.Customer_Address WHERE CustomerId = @Id;

			-- Step 2: Delete other related records
			DELETE FROM SBSC.CustomerCredentials WHERE CustomerId = @Id;

			-- Step 3: Finally, delete the customer record
			DELETE FROM SBSC.Customers WHERE Id = @Id;

			COMMIT TRANSACTION;

			-- Return the deleted customer ID
			SELECT @Id AS Id;
		END TRY
		BEGIN CATCH
			-- Rollback transaction in case of error
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;

			-- Raise the caught error
			DECLARE @CatchErrorMessages NVARCHAR(4000);
			DECLARE @CatchErrorSeveritys INT;
			DECLARE @CatchErrorStates INT;

			SET @CatchErrorMessages = ERROR_MESSAGE();
			SET @CatchErrorSeveritys = ERROR_SEVERITY();
			SET @CatchErrorStates = ERROR_STATE();

			RAISERROR(@CatchErrorMessages, @CatchErrorSeveritys, @CatchErrorStates);
		END CATCH;
	END
   
END
GO