SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
-- =============================================
-- Author:      <Author, , Name>
-- Create Date: <Create Date, , >
-- Description: <Description, , >
-- =============================================
CREATE PROCEDURE [SBSC].[sp_ImpersonateToken_CRUD]
    @Action NVARCHAR(20),
    @Id INT = NULL,
    @JwtToken NVARCHAR(MAX) = NULL,
    @Identifier NVARCHAR(100) = NULL,
    @ValidTime DATETIME = NULL,
    @IsUsed BIT = NULL,
    
    -- Optional parameters for paging, searching, and sorting (not used in this basic example)
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'ID',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE.', 16, 1);
        RETURN;
    END

    -- CREATE operation
    IF @Action = 'CREATE'
    BEGIN
        INSERT INTO [SBSC].[ImpersonateToken] (JwtToken, Identifier, ValidTime, IsUsed)
        VALUES (@JwtToken, @Identifier, @ValidTime, ISNULL(@IsUsed, 0));

        -- Return the newly created record (ID and values)
        SELECT 
            --SCOPE_IDENTITY() AS Id, 
            @JwtToken AS JwtToken, 
            @Identifier AS Identifier, 
            @ValidTime AS ValidTime, 
            ISNULL(@IsUsed, 0) AS IsUsed;
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        IF @Id IS NOT NULL
        BEGIN
            -- Return the specific record by ID
            SELECT * 
            FROM [SBSC].[ImpersonateToken] 
            WHERE ID = @Id;
        END
        ELSE
        BEGIN
            -- Return all records. (You can extend this section to implement paging/sorting if needed.)
            SELECT * 
            FROM [SBSC].[ImpersonateToken];
        END
    END

    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        -- Return the updated record information
        SELECT * FROM SBSC.ImpersonateToken WHERE Identifier = @Identifier;

        UPDATE [SBSC].[ImpersonateToken]
        SET 
            JwtToken   = ISNULL(@JwtToken, JwtToken),
            Identifier = ISNULL(@Identifier, Identifier),
            ValidTime  = ISNULL(@ValidTime, ValidTime),
            IsUsed     = ISNULL(@IsUsed, IsUsed)
        WHERE Identifier = @Identifier;

    END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            DELETE FROM [SBSC].[ImpersonateToken]
            WHERE ID = @Id;

            COMMIT TRANSACTION;
            SELECT @Id AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END
END
GO