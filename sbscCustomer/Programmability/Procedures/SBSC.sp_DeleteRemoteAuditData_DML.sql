SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_DeleteRemoteAuditData_DML]
(
	@Action NVARCHAR(100) = NULL,
    @CertificationId INT = NULL,
	@AuditorId INT = NULL,
	@RequirementId INT = NULL,
	@Strings NVARCHAR(MAX) = NULL
)
AS
BEGIN

	SET NOCOUNT ON;
	IF @Action NOT IN ('DELETE_AUDITOR', 'DELETE_CERTIFICATION', 'DELETE_RESPONSE')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use DELETE_AUDITOR, DELETE_CERTIFICATION, or DELETE_RESPONSE', 16, 1);
        RETURN;
    END



	IF @Action = 'DELETE_AUDITOR'
	BEGIN
		IF (@AuditorId IS NULL)
		BEGIN
			THROW 50001, '@AuditorId is null.', 1;
		END

		DELETE FROM [SBSC].[Customer_Auditors] WHERE AuditorId = @AuditorId;
	END

	ELSE IF @Action = 'DELETE_CERTIFICATION'
	BEGIN
		IF (@CertificationId IS NULL)
			THROW 50001, '@CertificationId is null.', 1;

		DELETE FROM [SBSC].[Customer_Certifications] WHERE CertificateId = @CertificationId;
	END

	ELSE IF @Action = 'DELETE_RESPONSE'
	BEGIN
		IF (@RequirementId IS NULL)
			THROW 50001, '@RequirementId is null.', 1;

		DELETE FROM SBSC.CommentThread WHERE RequirementId = @RequirementId;
		DELETE FROM [SBSC].[CustomerResponse] WHERE RequirementId = @RequirementId;
	END
END
GO