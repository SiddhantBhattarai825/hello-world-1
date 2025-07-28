SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_ResponseStatus]
	@Action NVARCHAR(MAX) = NULL,
	@CustomerId INT = NULL,
	@CertificationId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

		-- Validate the Action parameter
		IF @Action NOT IN ('READ', 'TEST')
		BEGIN
			RAISERROR('Invalid @Action parameter. Use READ', 16, 1);
			RETURN;
		END

		-- CREATE action
	IF @Action = 'READ'
	BEGIN
		IF EXISTS(SELECT 1 FROM SBSC.AuditorCustomerResponses 
		WHERE 
			IsApproved <> 1 
			AND CustomerResponseId IN (
				SELECT Id FROM SBSC.CustomerResponse 
				WHERE 
					CustomerId = @CustomerId 
					AND RequirementId IN (
						SELECT RequirementId FROM SBSC.RequirementChapters
						WHERE
							ChapterId IN (
								SELECT Id FROM SBSC.Chapter
								WHERE
									CertificationId = @CertificationId
								)
						)
				)
		)
		BEGIN
			RETURN 0;
		END
		ELSE IF NOT EXISTS(
			SELECT 1 
			FROM SBSC.AuditorCustomerResponses 
			WHERE 
				IsApproved <> 1 
				AND CustomerResponseId IN (
					SELECT Id FROM SBSC.CustomerResponse 
					WHERE 
						CustomerId = @CustomerId 
						AND RequirementId IN (
							SELECT RequirementId 
							FROM SBSC.RequirementChapters
							WHERE
								ChapterId IN (
									SELECT Id FROM SBSC.Chapter
									WHERE
										CertificationId = @CertificationId
								)
						)
				)
		)
		BEGIN
			RETURN 1;
		END
	END
END
GO