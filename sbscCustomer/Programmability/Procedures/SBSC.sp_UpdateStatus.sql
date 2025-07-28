SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_UpdateStatus]
@Action NVARCHAR(500) = NULL,
@Status BIT = NULL,
@AssignmentId INT = NULL,
@CustomerCertificationDetailsId INT = NULL
AS
BEGIN
	IF (@AssignmentId IS NULL AND @CustomerCertificationDetailsId IS NULL)
	BEGIN
		RAISERROR ('AssignmentId or CustomerCertificaitonDetailsId is required.', 16, 1);
		RETURN;
	END

	IF @Action = 'UPDATE_OF_CUSTOMER'
	BEGIN
		UPDATE SBSC.CustomerCertificationDetails
		SET UpdatedByCustomer = @Status
		WHERE ((@CustomerCertificationDetailsId IS NOT NULL AND Id = @CustomerCertificationDetailsId)
		OR
		(@CustomerCertificationDetailsId IS NULL AND Id IN (SELECT CustomerCertificationDetailsId 
											FROM SBSC.AssignmentCustomerCertification
											WHERE AssignmentId = @AssignmentId)
		))

	END

	ELSE IF @Action = 'UPDATE_OF_AUDITOR'
	BEGIN
		UPDATE SBSC.CustomerCertificationDetails
		SET UpdatedByAuditor = @Status
		WHERE ((@CustomerCertificationDetailsId IS NOT NULL AND Id = @CustomerCertificationDetailsId)
		OR
		(@CustomerCertificationDetailsId IS NULL AND Id IN (SELECT CustomerCertificationDetailsId 
											FROM SBSC.AssignmentCustomerCertification
											WHERE AssignmentId = @AssignmentId)
		))
	END

	ELSE IF @Action = 'CERTIFICATION_MODIFIED'
	BEGIN
		UPDATE SBSC.AssignmentOccasions
		SET LastUpdatedDate = GETUTCDATE()
		WHERE ((@AssignmentId IS NOT NULL AND Id = @AssignmentId)
			OR (@AssignmentId IS NULL AND Id = (
				SELECT AssignmentId 
				FROM SBSC.AssignmentCustomerCertification
				WHERE CustomerCertificationDetailsId = @CustomerCertificationDetailsId
			))
		)
	END

	ELSE
	BEGIN
		RAISERROR ('Invalid @Action parameter.', 16, 1);
		RETURN;
	END
END
GO