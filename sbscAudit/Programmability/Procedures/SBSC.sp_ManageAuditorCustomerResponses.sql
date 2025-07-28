SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_ManageAuditorCustomerResponses]
    @Action NVARCHAR(10),
    @Id INT = NULL,
    @CustomerResponseId INT = NULL,
    @AuditorId INT = NULL,
    @Response NVARCHAR(MAX) = NULL,
    @ResponseDate DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Validate Action
        IF @Action NOT IN ('CREATE', 'UPDATE', 'DELETE', 'READ')
        BEGIN
            THROW 50001, 'Invalid Action. Allowed values are Insert, Update, Delete, Select.', 1;
        END

        -- Insert Operation
        IF @Action = 'CREATE'
        BEGIN
            -- Validate CustomerResponseId exists in CustomerResponses table
            IF NOT EXISTS (
                SELECT 1 
                FROM [SBSC].[CustomerResponses]
                WHERE [Id] = @CustomerResponseId
            )
            BEGIN
                THROW 50002, 'Invalid CustomerResponseId. It does not exist in the CustomerResponses table.', 1;
            END

            INSERT INTO [SBSC].[AuditorCustomerResponses] (
                [CustomerResponseId],
                [AuditorId],
                [Response],
                [ResponseDate]
            )
            VALUES (
                @CustomerResponseId,
                @AuditorId,
                @Response,
                ISNULL(@ResponseDate, GETUTCDATE())
            );

            SELECT SCOPE_IDENTITY() AS NewId;
        END

        -- Update Operation
        IF @Action = 'UPDATE'
        BEGIN
            -- Validate Id
            IF NOT EXISTS (
                SELECT 1 
                FROM [SBSC].[AuditorCustomerResponses]
                WHERE [Id] = @Id
            )
            BEGIN
                THROW 50003, 'Invalid Id. Record does not exist in AuditorCustomerResponses table.', 1;
            END

            -- Validate CustomerResponseId exists in CustomerResponses table
            IF NOT EXISTS (
                SELECT 1 
                FROM [SBSC].[CustomerResponses]
                WHERE [Id] = @CustomerResponseId
            )
            BEGIN
                THROW 50004, 'Invalid CustomerResponseId. It does not exist in the CustomerResponses table.', 1;
            END

            UPDATE [SBSC].[AuditorCustomerResponses]
            SET
                [CustomerResponseId] = @CustomerResponseId,
                [AuditorId] = @AuditorId,
                [Response] = @Response,
                [ResponseDate] = ISNULL(@ResponseDate, [ResponseDate])
            WHERE [Id] = @Id;
        END

        -- Delete Operation
        IF @Action = 'DELETE'
        BEGIN
            -- Validate Id
            IF NOT EXISTS (
                SELECT 1 
                FROM [SBSC].[AuditorCustomerResponses]
                WHERE [Id] = @Id
            )
            BEGIN
                THROW 50005, 'Invalid Id. Record does not exist in AuditorCustomerResponses table.', 1;
            END

            DELETE FROM [SBSC].[AuditorCustomerResponses]
            WHERE [Id] = @Id;
        END

        -- Select Operation
        IF @Action = 'READ'
        BEGIN
            IF @Id IS NOT NULL
            BEGIN
                SELECT *
                FROM [SBSC].[AuditorCustomerResponses]
                WHERE [Id] = @Id;
            END
            ELSE
            BEGIN
                SELECT *
                FROM [SBSC].[AuditorCustomerResponses];
            END
        END
    END TRY
    BEGIN CATCH
        -- Handle Errors
        DECLARE @ErrorMessage NVARCHAR(4000),
                @ErrorSeverity INT,
                @ErrorState INT;

        SELECT 
            @ErrorMessage = ERROR_MESSAGE(),
            @ErrorSeverity = ERROR_SEVERITY(),
            @ErrorState = ERROR_STATE();

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH
END
GO