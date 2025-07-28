SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_CustomerRecertificationAudit]
    @Action NVARCHAR(50),               
    @CustomerCertificationId INT = NULL,
    @JobId NVARCHAR(100) = NULL,
	@AuditYear INT = NULL,
	@AuditDate DateTime = NULL,
	@Recertification INT = NULL,
	@CreatedDate DATETIME = NULL,
	
	@CustomerId INT = NULL,
	@CertificationId INT = NULL,

	@CustomerCertificationDetailsId INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

	-- returns customer response by requirementId and customerId
    IF @Action = 'CREATE_RECERTIFICATION'
    BEGIN
		
		SET @CustomerCertificationId = (SELECT CustomerCertificationId FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId);

        INSERT INTO SBSC.CustomerRecertificationAudits(
				CustomerCertificationId, 
				CustomerCertificationDetailsId,
				JobId, 
				AuditYear, 
				AuditDate, 
				Recertification,
				CreatedDate
			)
			VALUES (
				@CustomerCertificationId,
				@CustomerCertificationDetailsId,
				@JobId,
				@AuditYear,
				@AuditDate,
				@Recertification,
				GETUTCDATE()
			);

			SELECT @CustomerCertificationId;
    END

	ELSE IF @Action = 'RESCHEDULE_RECERTIFICATION'
	BEGIN
		
		IF @CustomerCertificationDetailsId IS NULL
		BEGIN
			RAISERROR('CustomerCertificationDetailsId must be provided', 16, 1);
			RETURN;
		END
		
		SET @CustomerCertificationId = (SELECT CustomerCertificationId FROM SBSC.CustomerCertificationDetails WHERE Id = @CustomerCertificationDetailsId);

		-- Regular update without dates
		UPDATE SBSC.CustomerRecertificationAudits
		SET 
			AuditDate = @AuditDate
		WHERE 
			CustomerCertificationDetailsId = @CustomerCertificationDetailsId
			AND AuditYear = @AuditYear;

		-- Return success
		SELECT @CustomerCertificationId;
	END


	ELSE
    BEGIN
        -- Invalid action
         RAISERROR('Invalid @Action parameter.', 16, 1);
         RETURN;
    END
END;
GO