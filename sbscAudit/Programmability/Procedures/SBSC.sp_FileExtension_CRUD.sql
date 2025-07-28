SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_FileExtension_CRUD]
    @Action VARCHAR(10),
    @Id INT = NULL,
	@Extension NVARCHAR(MAX) = NULL,
	@Size INT = NULL,

	@PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC' 
AS
BEGIN
    --SET NOCOUNT ON;
    IF @Action NOT IN ('CREATE', 'READ', 'DELETE', 'LIST')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, DELETE, or LIST', 16, 1);
        RETURN;
    END

	IF @Action = 'CREATE'
	BEGIN
		
		DECLARE @CurrentExtension NVARCHAR(50); 

		DECLARE thisExtension CURSOR FOR
		SELECT value
		FROM STRING_SPLIT(@Extension, ',');

		OPEN thisExtension;

		FETCH NEXT FROM thisExtension INTO @CurrentExtension;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF NOT EXISTS (SELECT 1 FROM [SBSC].[FileExtension] WHERE LOWER([Extension]) = LOWER(@CurrentExtension))
			BEGIN
				INSERT INTO [SBSC].[FileExtension] ([Extension])
				VALUES (@CurrentExtension);
			END
    
			FETCH NEXT FROM thisExtension INTO @CurrentExtension;
		END;

		CLOSE thisExtension;
		DEALLOCATE thisExtension;

		IF @Size IS NULL
		BEGIN
			IF EXISTS (SELECT TOP(1) Size FROM [SBSC].[FileExtension] WHERE Size IS NOT NULL)
				SET @Size = (SELECT TOP(1) Size FROM [SBSC].[FileExtension] WHERE Size IS NOT NULL)
			ELSE
				SET @Size = 20
		END
		UPDATE [SBSC].[FileExtension] SET Size = @Size;
		
	END

	IF @Action = 'READ'
    BEGIN
        IF @Id IS NULL
            SELECT * FROM [SBSC].[FileExtension]
        ELSE
            SELECT [Id], Extension, Size
            FROM [SBSC].[FileExtension]
            WHERE Id = @Id
    END

	IF @Action = 'DELETE'
	IF EXISTS(SELECT 1 FROM SBSC.[FileExtension] WHERE Id = @Id)
    BEGIN
        DELETE FROM [SBSC].[FileExtension]
        WHERE Id = @Id
        
		SELECT @Id AS Id;
        SELECT @@ROWCOUNT AS RowsAffected
    END

	IF @Action = 'LIST'
	BEGIN
		IF @SortColumn NOT IN ('Id', 'Extension','Size')
			SET @SortColumn = 'Id';

		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		SET @WhereClause = N'
			WHERE (@SearchValue IS NULL
			OR Extension LIKE ''%'' + @SearchValue + ''%'')';

		SET @SQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM [SBSC].[FileExtension] ' + @WhereClause;

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT';
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @TotalRecords OUTPUT;

		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		SET @SQL = N'
			SELECT Id, Extension, Size
			FROM [SBSC].[FileExtension] ' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
			OFFSET @Offset ROWS 
			FETCH NEXT @PageSize ROWS ONLY;';

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @Offset INT, @PageSize INT';
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @Offset, @PageSize;

		SELECT @TotalRecords AS TotalRecords, 
			   @TotalPages AS TotalPages, 
			   @PageNumber AS CurrentPage, 
			   @PageSize AS PageSize,
			   CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			   CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END
END
GO