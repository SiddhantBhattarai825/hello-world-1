SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_CertificationVersion]
    @Action NVARCHAR(50),  
    @CustomerId INT = NULL,
	@CertificationId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

	IF @Action = 'VERIFY_LATEST_CERTIFICATION'
	BEGIN
		IF @CustomerId IS NULL OR @CertificationId IS NULL
		BEGIN
			RAISERROR('Customer ID and Certificate ID must be provided', 16, 1);
			RETURN;
		END

		IF NOT EXISTS (SELECT 1 FROM SBSC.Certification WHERE Id = @CertificationId)
		BEGIN
			RAISERROR ('CertificationId doesnot exists', 16, 1);
			RETURN;
		END

		DECLARE @ChildId INT ;
		DECLARE @ParentCertificationId INT = @CertificationId;

		IF EXISTS (SELECT 1 FROM SBSC.Certification WHERE ParentCertificationId = @CertificationId)
		BEGIN
			WHILE 1 = 1
			BEGIN
				SELECT @ChildId = Id
				FROM Certification
				WHERE ParentCertificationId = @ParentCertificationId;

				IF EXISTS (SELECT 1 FROM SBSC.Certification WHERE ParentCertificationId = @ChildId)
				BEGIN
					SET @ParentCertificationId = @ChildId;
				END
				ELSE
				BEGIN
					BREAK;
				END
			END
			
			IF EXISTS (SELECT 1 FROM SBSC.Certification WHERE IsAuditorInitiated = 0 AND Id = @CertificationId)
			BEGIN
				INSERT INTO SBSC.Customer_Certifications (CustomerId, CertificateId, CertificateNumber, Validity, AuditYears, IssueDate, ExpiryDate, CreatedDate, SubmissionStatus, DeviationEndDate, Recertification)
				SELECT
					@CustomerId,
					@ChildId,
					CertificateNumber,
					Validity,
					AuditYears,
					IssueDate,
					NULL,
					GETUTCDATE(),
					0,
					NULL,
					0
				FROM SBSC.Customer_Certifications
				WHERE CustomerId = @CustomerId
				AND CertificateId = @CertificationId

				DECLARE @NewCustomerCertificationId INT;

				INSERT INTO SBSC.CustomerCertificationDetails (CustomerCertificationId, AddressId, DepartmentId, Recertification, Status, DeviationEndDate, CreatedDate, IssueDate, ExpiryDate)
				VALUES(
					@NewCustomerCertificationId,
					NULL,
					NULL,
					0,
					0,
					NULL,
					GETUTCDATE(),
					NULL,
					NULL)			
			END
			ELSE IF EXISTS (SELECT 1 FROM SBSC.Certification WHERE IsAuditorInitiated = 1 AND Id = @CertificationId)
			BEGIN
				INSERT INTO SBSC.Customer_Certifications (CustomerId, CertificateId, CertificateNumber, Validity, AuditYears, IssueDate, ExpiryDate, CreatedDate, SubmissionStatus, DeviationEndDate, Recertification)
				SELECT
					@CustomerId,
					@ChildId,
					CertificateNumber,
					Validity,
					AuditYears,
					NULL,
					NULL,
					GETUTCDATE(),
					11,
					NULL,
					0
				FROM SBSC.Customer_Certifications
				WHERE CustomerId = @CustomerId
				AND CertificateId = @CertificationId
			END

			ELSE
			BEGIN
				RAISERROR ('Certification is not specified whether it is online or offline.', 16, 1);
				RETURN;
			END
		END
		ELSE
		BEGIN
			RAISERROR ('No new Versions for this certification.', 16, 1);
			RETURN;
		END
	END

	ELSE IF @Action = 'EXPIRY_DATE_OF_CUSTOMER_CERTIFICATION'
	BEGIN
		SELECT 
			ExpiryDate, 
			CustomerId 
		FROM SBSC.Customer_Certifications 
		WHERE CertificateId = @CertificationId
		AND (@CustomerId IS NULL OR CustomerId = @CustomerId)
	END

	ELSE IF @Action = 'CHECK_NEW_CERTIFICATION_VERSION'
	BEGIN
		SELECT 1 FROM SBSC.Certification WHERE ParentCertificationId = @CertificationId
	END

	ELSE
    BEGIN
        -- Invalid action
         RAISERROR('Invalid @Action parameter.', 16, 1);
         RETURN;
    END
END;
GO