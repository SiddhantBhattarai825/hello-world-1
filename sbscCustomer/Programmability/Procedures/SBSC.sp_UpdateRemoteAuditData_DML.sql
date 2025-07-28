SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_UpdateRemoteAuditData_DML]
(
	@Action NVARCHAR(100) = NULL,
    @CertificationId INT = NULL,
	@AuditorId INT = NULL,
	@AuditYears NVARCHAR(MAX) = NULL,
	@RequirementId INT = NULL,
	@Strings NVARCHAR(MAX) = NULL
)
AS
BEGIN
	SET NOCOUNT ON;
	IF @Action NOT IN ('UPDATE_AUDITYEAR')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use UPDATE_AUDITYEAR', 16, 1);
        RETURN;
    END

	IF @Action = 'UPDATE_AUDITYEAR'
	BEGIN
		IF (@AuditYears IS NULL)
		BEGIN
			THROW 50001, '@AuditYears is null.', 1;
		END

		IF (@CertificationId IS NULL)
		BEGIN
			THROW 50001, '@CertificationId is null.', 1;
		END


		UPDATE cc
		SET cc.AuditYears = (
			SELECT STRING_AGG(v.Value, ', ') 
			FROM 
				STRING_SPLIT(cc.AuditYears, ',') AS s 
				LEFT JOIN (
					SELECT TRIM(Value) AS Value
					FROM STRING_SPLIT(@AuditYears, ',') 
				) AS v
				ON TRIM(s.Value) = v.Value 
		)
		FROM 
			SBSC.Customer_Certifications cc
		WHERE 
			cc.CertificateId = @CertificationId; 
	END
END
GO