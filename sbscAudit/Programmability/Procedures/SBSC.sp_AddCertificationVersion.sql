SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
-- Clones the data of certification for MultiLanguage, Chapter and Documents. 
CREATE PROCEDURE [SBSC].[sp_AddCertificationVersion]
	@Action NVARCHAR(20),
    @CertificationId INT = NULL,
    @NewVersion DECIMAL(5,2) = NULL,
    @AddedBy INT = NULL, 

	@PageNumber INT = 1,
    @PageSize INT = 100,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'UpdatedDate',
    @SortDirection NVARCHAR(4) = 'DESC'
AS
BEGIN
    SET NOCOUNT ON;
    
	IF @Action NOT IN ('ADDVERSION', 'LISTVERSION', 'UPDATESTATUS')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE or LIST', 16, 1);
        RETURN;
    END

	-- CREATE operation
    IF @Action = 'ADDVERSION'
	BEGIN

    
		-- Start the transaction
		BEGIN TRY
			BEGIN TRANSACTION;
        
			-- Check if the source certification exists
			IF NOT EXISTS (SELECT 1 FROM [SBSC].[Certification] WHERE Id = @CertificationId)
			BEGIN
				RAISERROR('The specified Certification ID does not exist.', 16, 1);
				RETURN;
			END

		   -- Get the existing certification details
			DECLARE @CertificateTypeId INT,
					@CertificateCode VARCHAR(50),
					@Validity INT,
					@AuditYears NVARCHAR(255),
					@Published INT,
					@IsVisible BIT,
					@OldVersion DECIMAL(5,2);

			-- Select details based on CertificationId
			SELECT @CertificateTypeId = CertificateTypeId,
				   @CertificateCode = CertificateCode,
				   @Validity = Validity,
				   @AuditYears = AuditYears,
				   @Published = Published,
				   @IsVisible = IsVisible
			FROM [SBSC].[Certification]
			WHERE Id = @CertificationId;

			-- Fetch the latest version for the same CertificateCode, ordered by Version DESC
			SELECT TOP 1 @OldVersion = [Version]
			FROM [SBSC].[Certification]
			WHERE CertificateCode = @CertificateCode
			ORDER BY [Version] DESC;

			-- If NewVersion is not provided, increment the old version by 1
			IF @NewVersion IS NULL
			BEGIN
				SET @NewVersion = CAST(FLOOR(@OldVersion) + 1 AS DECIMAL(8,2));
    
				-- Validate the new version doesn't exceed the DECIMAL(5,2) limits
				IF @NewVersion > 999.99
				BEGIN
					RAISERROR('Version number cannot exceed 999.99', 16, 1);
					RETURN;
				END
			END

			DECLARE @ClonedCertificateId INT = NULL;
			DECLARE @ClonedChapterId INT = NULL;
			DECLARE @ClonedRequirementId INT = NULL;
			DECLARE @ClonedRequirementAnswerId INT = NULL;

			INSERT INTO [SBSC].[Certification] (
				[CertificateTypeId],
				[CertificateCode],
				[Validity],
				[AuditYears],
				[Published],
				[IsActive],
				[IsVisible],
				[AddedDate],
				[AddedBy],
				[ModifiedBy],
				[ModifiedDate],
				[Version],
				IsAuditorInitiated,
				[ParentCertificationId]
			)
			SELECT
				CertificateTypeId,
				[CertificateCode],
				Validity,
				AuditYears,
				0,
				0,
				IsVisible,
				GETUTCDATE(),
				@AddedBy,
				Null,
				NULL,
				@NewVersion,
				IsAuditorInitiated,
				@CertificationId
			FROM SBSC.Certification
			WHERE Id = @CertificationId

			-- Get the newly inserted Certification Id
			SET @ClonedCertificateId = SCOPE_IDENTITY();



			-- Clone CERTIFICATIONLANGUAGE entries
			
			INSERT INTO [SBSC].[CertificationLanguage] (
				[CertificationId],
				[LangId],
				[CertificationName],
				[Description],
				Published,
				PublishedDate
			)
			SELECT 
				@ClonedCertificateId,
				[LangId],
				[CertificationName],
				[Description],
				0,
				NULL
			FROM [SBSC].[CertificationLanguage]
			WHERE CertificationId = @CertificationId;

			-- Clone DocumentsCertifications entries
			INSERT INTO [SBSC].[DocumentsCertifications] (
				[DocId],
				[CertificationId],
				DisplayOrder,
				IsWarning
			)
			SELECT 
				[DocId],
				@ClonedCertificateId,
				DisplayOrder,
				IsWarning
			FROM [SBSC].[DocumentsCertifications]
			WHERE CertificationId = @CertificationId;


			--AUDITOR_CERTIFICATION CLONE	

			INSERT INTO [SBSC].[Auditor_Certifications] (
				[AuditorId]
				,[CertificationId]
				,[IsDefault]
			)
			SELECT 
				[AuditorId]
				,@ClonedCertificateId
				,[IsDefault]
			FROM [SBSC].[Auditor_Certifications]
			WHERE CertificationId = @CertificationId;


			--REPORTBLOCKSCERTIFICATION CLONE

			INSERT INTO [SBSC].[ReportBlocksCertifications] (
				[ReportBlockId]
				,[CertificationId]
			)
			SELECT 
				[ReportBlockId]
				,@ClonedCertificateId
			FROM [SBSC].[ReportBlocksCertifications]
			WHERE CertificationId = @CertificationId;



			DECLARE @Chapter TABLE (Id INT);
			DELETE FROM @Chapter;


			INSERT INTO @Chapter (Id)
			SELECT Id FROM [SBSC].[Chapter]
			WHERE CertificationId = @CertificationId;

			DECLARE @CurrentChapId INT;

			SET @CurrentChapId = (SELECT MIN(Id) FROM @Chapter);

			-- While loop to iterate over the table
			WHILE @CurrentChapId IS NOT NULL
			BEGIN
				--CHAPTER CLONE

				INSERT INTO [SBSC].[Chapter] (
					[Title],
					[IsVisible],
					IsWarning,
					[AddedDate],
					[AddedBy],
					[ModifiedDate],
					[ModifiedBy],
					[CertificationId],
					DisplayOrder,
					ParentChapterId,
					HasChildSections,
					[Level]
				)
				SELECT 
					[Title],
					[IsVisible],
					[IsWarning],
					GETUTCDATE(),    -- New AddedDate
					@AddedBy,        -- New AddedBy
					NULL,    -- New ModifiedDate
					NULL,        -- New ModifiedBy
					@ClonedCertificateId,
					DisplayOrder,
					ParentChapterId,
					HasChildSections,
					[Level]
				FROM [SBSC].[Chapter]
				WHERE Id = @CurrentChapId

				SET @ClonedChapterId = SCOPE_IDENTITY();

				-- CHAPTERLANGUAGE CLONE

				INSERT INTO SBSC.ChapterLanguage (
					[ChapterId]
					,[ChapterTitle]
					,[ChapterDescription]
					,[LanguageId]
					,[ModifiedBy]
					,[ModifiedDate]
				)
				SELECT
					@ClonedChapterId
				  ,[ChapterTitle]
				  ,[ChapterDescription]
				  ,[LanguageId]
				  ,@AddedBy
				  ,GETUTCDATE()
				FROM SBSC.ChapterLanguage
				WHERE ChapterId = @CurrentChapId


				--REQUIREMENTCHAPTERS ARRANGEMENT

				INSERT INTO SBSC.RequirementChapters (RequirementId, ChapterId, ReferenceNo, IsWarning, DispalyOrder)
				SELECT 
					RequirementId,
					@ClonedChapterId,
					ReferenceNo,
					IsWarning,
					DispalyOrder
				FROM SBSC.RequirementChapters
				WHERE ChapterId = @CurrentChapId


				SET @CurrentChapId = (SELECT MIN(Id) FROM @Chapter WHERE Id > @CurrentChapId);
			END

			-- Commit the transaction
			COMMIT TRANSACTION;

			-- Return the newly created version details
			SELECT 
				@ClonedCertificateId AS [Id],
				@CertificateTypeId AS [CertificateTypeId],
				@CertificateCode AS [CertificateCode],
				@Validity AS [Validity],
				@AuditYears AS [AuditYears],
				@NewVersion AS [Version];

		END TRY
		BEGIN CATCH
			-- Rollback the transaction if any error occurs
			IF @@TRANCOUNT > 0
			BEGIN
				ROLLBACK TRANSACTION;
			END;

			-- Return error information
			DECLARE @ErrorMessage NVARCHAR(4000),
					@ErrorSeverity INT,
					@ErrorState INT;

			SELECT 
				@ErrorMessage = ERROR_MESSAGE(),
				@ErrorSeverity = ERROR_SEVERITY(),
				@ErrorState = ERROR_STATE();

			-- Rethrow the error
			RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
		END CATCH;
	END

	ELSE IF @Action = 'LISTVERSION'
	BEGIN

		DECLARE @CertificationCode NVARCHAR(100);

		-- Retrieve the CertificationCode for the specified CertificationId
		SELECT @CertificationCode = CertificateCode
		FROM [SBSC].[Certification]
		WHERE Id = @CertificationId;

		-- Validate and sanitize the sort column
		IF @SortColumn NOT IN ('AddedDate', 'Version', 'IsActive', 'Published')
			SET @SortColumn = 'AddedDate';

		-- Validate the sort direction
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'DESC';

		-- Declare variables for pagination
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;
		DECLARE @TotalPages INT;

		-- Define the WHERE clause for search filtering
		SET @WhereClause = N' WHERE CertificateCode LIKE @CertificationCode'; -- Filter by CertificateCode
    
		IF @SearchValue IS NOT NULL
		BEGIN
			SET @WhereClause += N'
				AND (CONVERT(VARCHAR(19), AddedDate, 120) LIKE ''%'' + @SearchValue + ''%''
				OR [Version] LIKE ''%'' + @SearchValue + ''%''
				OR CONVERT(VARCHAR, IsActive) LIKE ''%'' + @SearchValue + ''%''
				OR CONVERT(VARCHAR, Published) LIKE ''%'' + @SearchValue + ''%'')';
		END

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(Id)
			FROM SBSC.Certification
		' + @WhereClause;

		SET @ParamDefinition = N'@CertificationCode NVARCHAR(100), @SearchValue NVARCHAR(100), @TotalRecords INT OUTPUT';

		-- Execute the total count query
		EXEC sp_executesql @SQL, @ParamDefinition, 
						   @CertificationCode = @CertificationCode, 
						   @SearchValue = @SearchValue, 
						   @TotalRecords = @TotalRecords OUTPUT;

		-- Calculate total pages
		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);

		-- Retrieve paginated data
		SET @SQL = N'
			SELECT Id, CertificateCode, [Version], AddedDate, IsActive, Published
			FROM SBSC.Certification
			' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
			OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
			FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

		-- Execute the paginated query
		EXEC sp_executesql @SQL, @ParamDefinition, 
						   @CertificationCode = @CertificationCode, 
						   @SearchValue = @SearchValue, 
						   @TotalRecords = @TotalRecords OUTPUT;

		-- Return pagination details
		SELECT @TotalRecords AS TotalRecords, 
			   @TotalPages AS TotalPages, 
			   @PageNumber AS CurrentPage, 
			   @PageSize AS PageSize,
			   CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			   CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END

	ELSE IF @Action = 'UPDATESTATUS'
	BEGIN
		IF @CertificationId IS NULL
		BEGIN
			RAISERROR('CertificationId field is required to update status', 16, 1);
			RETURN;
		END

		BEGIN TRY
			BEGIN TRANSACTION;

			DECLARE @CertificationCodeFromId NVARCHAR(100);

			-- Retrieve the CertificationCode for the specified CertificationId
			SELECT @CertificationCodeFromId = CertificateCode
			FROM [SBSC].[Certification]
			WHERE Id = @CertificationId;

			-- Check if CertificationCode was found
			IF @CertificationCodeFromId IS NULL
			BEGIN
				RAISERROR('No Certification found with the specified CertificationId', 16, 1);
				ROLLBACK TRANSACTION;
				RETURN;
			END

			-- Set IsActive to 0 for all rows with the retrieved CertificationCode
			UPDATE [SBSC].[Certification]
			SET IsActive = 0
			WHERE CertificateCode = @CertificationCodeFromId;

			-- Set IsActive to 1 for the specific CertificationId
			UPDATE [SBSC].[Certification]
			SET IsActive = 1
			WHERE Id = @CertificationId;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION;
			DECLARE @ErrorMessageUpdate NVARCHAR(4000), @ErrorSeverityUpdate INT, @ErrorStateUpdate INT;
			SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE();
			RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
		END CATCH
	END
END
GO