SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_PreviewToken]
	@Action NVARCHAR(50),
	@JwtToken NVARCHAR(MAX) = NULL,
	@Identifier NVARCHAR(MAX) = NULL,
	@ValidTime DATETIME = NULL,
	@IsUsed BIT = NULL,
	@CertificationId INT = NULL,
	@LangId INT = NULL
AS
BEGIN
	SET NOCOUNT ON;

	IF @Action NOT IN ('CREATE', 'UPDATE')
	BEGIN
		RAISERROR('Invalid @Action parameter. Use CREATE, or UPDATE.', 16, 1);
		RETURN;
	END

	IF @Action = 'CREATE'
	BEGIN
		INSERT INTO SBSC.PreviewToken (JwtToken, Identifier, ValidTime, IsUsed, CertificationId, LangId)
		VALUES (@JwtToken, @Identifier, @ValidTime, 0, @CertificationId, @LangId);

		SELECT 
			@CertificationId AS CertificationId,
			@LangId AS LangId,
			(SELECT Published FROM SBSC.CertificationLanguage WHERE CertificationId = @CertificationId AND LangId = @LangId) AS IsPublished,
			@JwtToken AS JwtToken,
			@Identifier AS Identifier,
			@ValidTime AS ValidTime,
			CAST(0 AS BIT) AS IsUsed;
	END

	ELSE IF @Action = 'UPDATE'
    BEGIN
		SELECT 
			t.*,
			cl.Published AS IsPublished
		FROM 
			[SBSC].[PreviewToken] t
			INNER JOIN SBSC.CertificationLanguage cl 
				ON t.CertificationId = cl.CertificationId 
				AND t.LangId = cl.LangId
		WHERE 
			t.Identifier = @Identifier;

        UPDATE [SBSC].[PreviewToken]
        SET IsUsed = ISNULL(@IsUsed, IsUsed)
        WHERE Identifier = @Identifier;

    END
END
GO