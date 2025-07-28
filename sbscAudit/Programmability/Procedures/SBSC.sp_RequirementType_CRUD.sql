SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_RequirementType_CRUD] 
    @Action NVARCHAR(20),
    @Id INT = NULL,
    @Name NVARCHAR(100) = NULL,
    @IsVisible INT = NULL,
    @IsActive INT = NULL,
    @AddedDate DATE = NULL,
    @AddedBy INT = NULL,
    @ModifiedBy INT = NULL,
    @ModifiedDate DATE = NULL,

    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, or LIST.', 16, 1);
        RETURN;
    END

    -- CREATE operation
    IF @Action = 'CREATE'
    BEGIN
        INSERT INTO [SBSC].[RequirementType] (Name, IsVisible, IsActive, AddedDate, AddedBy, ModifiedDate, ModifiedBy)
        VALUES (@Name, ISNULL(@IsVisible, 1), ISNULL(@IsActive, 1), ISNULL(@AddedDate, GETDATE()), @AddedBy, @ModifiedDate, @ModifiedBy);

        -- Return the newly created record
        SELECT SCOPE_IDENTITY() AS Id, @Name AS Name;
    END

    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        IF @Id IS NOT NULL
        BEGIN
            SELECT * FROM [SBSC].[RequirementType] WHERE Id = @Id;
        END
        ELSE
        BEGIN
            SELECT * FROM [SBSC].[RequirementType];
        END
    END

    -- UPDATE operation
    ELSE IF @Action = 'UPDATE'
    BEGIN
        UPDATE [SBSC].[RequirementType]
        SET Name = ISNULL(@Name, Name),
            IsVisible = ISNULL(@IsVisible, IsVisible),
            IsActive = ISNULL(@IsActive, IsActive),
            ModifiedDate = ISNULL(@ModifiedDate, GETDATE()),
            ModifiedBy = @ModifiedBy
        WHERE Id = @Id;

        -- Return the updated record
        SELECT @Id AS Id, @Name AS Name;
    END

    -- DELETE operation
    ELSE IF @Action = 'DELETE'
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            DELETE FROM [SBSC].[RequirementType] WHERE Id = @Id;

            COMMIT TRANSACTION;
            SELECT @Id AS Id;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
    END

    -- LIST operation
    ELSE IF @Action = 'LIST'
    BEGIN
        -- Validate and sanitize the sort column
        IF @SortColumn NOT IN ('Id', 'Name', 'IsVisible', 'IsActive')
            SET @SortColumn = 'Id';

        -- Validate the sort direction
        IF @SortDirection NOT IN ('ASC', 'DESC')
            SET @SortDirection = 'ASC';

        -- Pagination logic
        DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;

        SELECT Id, Name, IsVisible, IsActive, AddedDate, AddedBy, ModifiedDate, ModifiedBy
        FROM [SBSC].[RequirementType]
        WHERE (@SearchValue IS NULL OR Name LIKE '%' + @SearchValue + '%')
        ORDER BY CASE WHEN @SortColumn = 'Id' THEN Id END ASC,
                 CASE WHEN @SortColumn = 'Name' THEN Name END ASC
        OFFSET @Offset ROWS
        FETCH NEXT @PageSize ROWS ONLY;

        -- Return pagination details
        SELECT COUNT(*) AS TotalRecords,
               CEILING(CAST(COUNT(*) AS FLOAT) / @PageSize) AS TotalPages,
               @PageNumber AS CurrentPage,
               @PageSize AS PageSize;
    END
END;
GO