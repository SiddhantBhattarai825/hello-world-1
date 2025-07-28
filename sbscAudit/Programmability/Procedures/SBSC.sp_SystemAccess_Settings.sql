SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_SystemAccess_Settings]
    @Action NVARCHAR(20),
    @RemainingLoginAttempts INT = NULL,
    @LockoutEndTime Time = NULL
    
AS
BEGIN
    SET NOCOUNT ON;

    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATE_COLUMN', 'UPDATE_USER_LANG')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, UPDATE_COLUMN or UPDATE_USER_LANG', 16, 1);
        RETURN;
    END

    IF @Action = 'CREATE'
    BEGIN
		
        BEGIN TRY

			IF NOT EXISTS (SELECT TOP 1  [ID] FROM [SBSC].[SystemAccessSettings])
				BEGIN

					INSERT INTO [SBSC].[SystemAccessSettings] ([LockoutEndTime], [RemainingAttemptCount])
					VALUES (@LockoutEndTime, @RemainingLoginAttempts); 

				END
			ELSE
				BEGIN
					UPDATE TOP (1) [SBSC].[SystemAccessSettings]
					SET 
						[LockoutEndTime] = @LockoutEndTime,
						[RemainingAttemptCount] = @RemainingLoginAttempts
				END
					SELECT TOP 1 [Id], [LockoutEndTime], [RemainingAttemptCount]
					FROM [SBSC].[SystemAccessSettings];
		END TRY

		BEGIN CATCH
		
			DECLARE @ErrMsg NVARCHAR(4000) = 'Some error occurred: ' + ERROR_MESSAGE();
			RAISERROR(@ErrMsg, 16, 1);

		END CATCH
		
	END

	IF @Action = 'READ'
	BEGIN
		
		IF NOT EXISTS (SELECT TOP 1 [ID] FROM [SBSC].[SystemAccessSettings])
			BEGIN
				RAISERROR('No admin settings available.', 16, 1);
				RETURN;

			END

		ELSE
			BEGIN
				SELECT TOP 1 [Id], [LockoutEndTime], [RemainingAttemptCount]
				FROM [SBSC].[SystemAccessSettings]
							
			END

	END
END
GO