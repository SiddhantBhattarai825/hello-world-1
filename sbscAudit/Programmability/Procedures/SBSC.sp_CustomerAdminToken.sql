SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_CustomerAdminToken]
	@Action NVARCHAR(50),
	@AdminId INT = NULL,
	@Email NVARCHAR(MAX) = NULL,
	@JwtToken NVARCHAR(MAX) = NULL,
	@Identifier NVARCHAR(MAX) = NULL,
	@ValidTime DATETIME = NULL,
	@IsUsed BIT = NULL
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
		INSERT INTO SBSC.CustomerAdminToken (AdminId, Email, JwtToken, Identifier, ValidTime, IsUsed)
		VALUES (@AdminId, @Email, @JwtToken, @Identifier, @ValidTime, 0);

		SELECT 
			@AdminId AS AdminId,
			@Email AS Email,
			@JwtToken AS JwtToken,
			@Identifier AS Identifier,
			@ValidTime AS ValidTime,
			CAST(0 AS BIT) AS IsUsed;
	END

	ELSE IF @Action = 'UPDATE'
    BEGIN
		SELECT * FROM [SBSC].CustomerAdminToken
		WHERE Identifier = @Identifier;

        UPDATE [SBSC].CustomerAdminToken
        SET IsUsed = ISNULL(@IsUsed, IsUsed)
        WHERE Identifier = @Identifier;

    END
END
GO