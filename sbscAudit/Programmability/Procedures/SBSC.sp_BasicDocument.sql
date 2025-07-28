SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

-- =============================================
-- Author:      <Author,,Name>
-- Create date: <Create Date,,>
-- Description: Stored Procedure for Document CRUD operations
-- =============================================
CREATE PROCEDURE [SBSC].[sp_BasicDocument]
    @Action NVARCHAR(50),
    @Id INT = NULL,
    @Name NVARCHAR(255) = NULL,
    @DisplayOrder INT = NULL,
    @RequirementTypeId INT= NULL,
    @DocumentType NVARCHAR(50) = NULL,
	@AddedDate DATETIME = NULL,
	@AddedBy INT = NULL,
    @IsVisible BIT = NULL,
	@Certifications NVARCHAR(MAX) = NULL, -- JSON array of certifications
	@Version DECIMAL(6,2) = NULL,
	@IsWarning BIT = NULL,
	@IsUploadFileRequired BIT = NULL,
	@IsFileUploadable BIT = NULL,
	@IsCommentable BIT = NULL,
	@AssignmentId INT = NULL,

	@UserType NVARCHAR(50) = NULL, 
	@AdminId INT = NULL, 
	@AuditorId INT = NULL, 
	@CustomerId INT = NULL,
	@UserId INT = NULL,
	@UserRole INT = NULL,
    
    -- Language specific
	@DefaultLangId INT = NULL,
    @LangId INT = NULL,
	@Headlines NVARCHAR(255) = NULL,
    @Description NVARCHAR(MAX) = NULL,
	@HeadlinesLang NVARCHAR(500) = NULL,
	@DescriptionLang NVARCHAR(MAX) = NULL,
    
	-- Certifications specific
	@CertificationId INT = NULL,
	@CertificationCode NVARCHAR(50) = NULL,
	@CertificationCodes [SBSC].[CertificationCodeTableType] READONLY,

    -- Pagination and sorting
    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'DisplayOrder',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'UPDATELANG', 'GETDOCUMENTCERTIFICATIONS', 'DISPLAYORDER', 'LIST_BY_CERTIFICATION_IDS', 'UPDATE_READ_STATUS')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, UPDATELANG, GETDOCUMENTCERTIFICATIONS, DISPLAYORDER, UPDATE_READ_STATUS or LIST_BY_CERTIFICATION_IDS.', 16, 1);
        RETURN;
    END

    -- CREATE Operation
	IF @Action = 'CREATE' 
	BEGIN 
		IF @CertificationId IS NULL
		BEGIN
			RAISERROR ('CertificationId is required.',16,1);
			RETURN;
		END


		DECLARE @NewDocumentId INT; 
		
		IF @RequirementTypeId IS NULL
		BEGIN
			SELECT @RequirementTypeId = Id
			FROM [SBSC].[RequirementType]
			WHERE [Name] = 'Free Text';

			-- If no match found, set default value to 1
			IF @RequirementTypeId IS NULL
			BEGIN
				SET @RequirementTypeId = 1;
			END
		END

		BEGIN TRY 
			BEGIN TRANSACTION; 

			-- Insert into Document table 
			INSERT INTO [SBSC].[Documents] ( 
				[DisplayOrder], [IsVisible], 
				[AddedDate], [RequirementTypeId], [AddedBy],  
				[UserRole], [ModifiedDate], [ModifiedBy], Version,
				IsFileUploadable, IsFileUploadRequired, IsCommentable
			) 
			VALUES ( 
				CASE 
					WHEN @DisplayOrder IS NULL THEN (SELECT MAX(DisplayOrder) FROM SBSC.Documents) + 1
					ELSE @DisplayOrder
				END, 
				ISNULL(@IsVisible, 1), 
				GETUTCDATE(), @RequirementTypeId, @AddedBy,
				@UserRole, NULL, NULL, 1,
				1, 0, 1
			); 

			-- Get the newly inserted DocumentId 
			SET @NewDocumentId = SCOPE_IDENTITY(); 

			-- Update DisplayOrder to match NewDocumentId if DisplayOrder was NULL
			--IF @DisplayOrder IS NULL
			--BEGIN
			--	UPDATE [SBSC].[Documents]
			--	SET [DisplayOrder] = @NewDocumentId
			--	WHERE [Id] = @NewDocumentId;
			--END

			INSERT INTO SBSC.DocumentsCertifications (DocId, CertificationId, DisplayOrder, IsWarning)
			VALUES(@NewDocumentId, @CertificationId, 
			CASE 
				WHEN @DisplayOrder IS NULL THEN 
					CASE 
						WHEN (SELECT MAX(DisplayOrder) FROM SBSC.DocumentsCertifications WHERE CertificationId = @CertificationId) IS NULL THEN 1
						ELSE (SELECT MAX(DisplayOrder) FROM SBSC.DocumentsCertifications WHERE CertificationId = @CertificationId) + 1
					END
				ELSE @DisplayOrder
			END, ISNULL(@IsWarning, 0));

			-- Handle Certifications if provided
			--IF @Certifications IS NOT NULL AND LEN(@Certifications) > 0
			--BEGIN
				--DECLARE @CertificationsTable TABLE (CertificationId INT);
    
				-- Parse JSON certifications, validate existence, and check IsActive status
				--INSERT INTO @CertificationsTable (CertificationId)
				--SELECT c.Id
				--FROM OPENJSON(@Certifications) WITH (CertCode NVARCHAR(255) '$') AS s
				--INNER JOIN SBSC.Certification AS c ON c.CertificateCode = LTRIM(RTRIM(s.CertCode))
				--WHERE s.CertCode IS NOT NULL
				--  AND c.IsActive = 1;  -- Only include active certifications

				-- Check if certifications were found
			--	IF NOT EXISTS (SELECT 1 FROM @CertificationsTable)
			--	BEGIN
			--		RAISERROR('No valid or active certifications found for provided codes: %s', 16, 1, @Certifications);
			--		ROLLBACK TRANSACTION;
			--		RETURN;
			--	END

			--	-- Insert into Auditor_Certifications
			--	INSERT INTO SBSC.DocumentsCertifications (DocId, CertificationId)
			--	SELECT @NewDocumentId, CertificationId
			--	FROM @CertificationsTable;
			--END

			-- Insert into DocumentsCertifications table
			-- INSERT INTO [SBSC].[DocumentsCertifications] (DocId, CertificationId)
			-- SELECT @NewDocumentId, CertificationId
			-- FROM @CertificationIds;

			-- Loop through all languages and insert into DocumentLanguage table 
			DECLARE @CurrentLangId INT; 

			-- Cursor to loop through all languages 
			DECLARE LanguageCursor CURSOR FOR 
			SELECT Id FROM [SBSC].[Languages]; 

			OPEN LanguageCursor; 

			FETCH NEXT FROM LanguageCursor INTO @CurrentLangId; 
			WHILE @@FETCH_STATUS = 0 
			BEGIN 
				IF @CurrentLangId = @DefaultLangId 
				BEGIN 
					-- Insert with the provided Headlines and Description for the specified LangId 
					INSERT INTO [SBSC].[DocumentLanguage] ( 
						[DocId], [LangId], [Headlines], [Description] 
					) 
					VALUES ( 
						@NewDocumentId, @DefaultLangId, @Headlines, @Description 
					); 
				END 
				 
				-- Check if the current LangId matches the provided @LangId 
				ELSE IF @CurrentLangId = @LangId 
				BEGIN 
					-- Insert with the provided Headlines and Description for the specified LangId 
					INSERT INTO [SBSC].[DocumentLanguage] ( 
						[DocId], [LangId], [Headlines], [Description] 
					) 
					VALUES ( 
						@NewDocumentId, @LangId, @HeadlinesLang, @DescriptionLang
					); 
				END 
				ELSE 
				BEGIN 
					-- Insert with NULL values for other languages 
					INSERT INTO [SBSC].[DocumentLanguage] ( 
						[DocId], [LangId], [Headlines], [Description] 
					) 
					VALUES ( 
						@NewDocumentId,  
						@CurrentLangId, 
						NULL, 
						NULL 
					); 
				END 

				FETCH NEXT FROM LanguageCursor INTO @CurrentLangId; 
			END 

			-- Close and deallocate the cursor 
			CLOSE LanguageCursor; 
			DEALLOCATE LanguageCursor; 

			-- Commit the transaction 
			COMMIT TRANSACTION; 

			-- Return newly inserted document 
			SELECT  
				@NewDocumentId AS [Id], 
				@Headlines AS [Headlines], 
				@Description AS [Description]
		END TRY 
		BEGIN CATCH 
			IF @@TRANCOUNT > 0 
				ROLLBACK TRANSACTION; 

			THROW; -- Re-throw error 
		END CATCH; 
	END


	-- READ Operation
	ELSE IF @Action = 'READ'
	BEGIN
		IF @Id IS NULL
		BEGIN
			RAISERROR ('DocumentId is required.',16,1);
			RETURN;
		END

		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLangId;
		END
	
		
		-- Return specific document with its certifications
		SELECT 
			vd.*
		FROM [SBSC].[vw_DocumentDetails] vd
		WHERE [DocumentId] = @Id 
		AND [LangId] = @LangId;
	END


    -- UPDATE Operation
    ELSE IF @Action = 'UPDATE'
	BEGIN
		BEGIN TRANSACTION;
    
		BEGIN TRY
			IF NOT EXISTS(SELECT 1 FROM SBSC.Documents WHERE Id = @Id)
			BEGIN
				RAISERROR ('Document not found.',16,1);
				RETURN;
			END
			-- Update main document information
			UPDATE [SBSC].[Documents]
			SET
				RequirementTypeId = ISNULL(@RequirementTypeId, RequirementTypeId),
				IsVisible = ISNULL(@IsVisible, IsVisible),
				ModifiedBy = ISNULL(@AddedBy, ModifiedBy),
				ModifiedDate = GETUTCDATE(),
				UserRole = ISNULL(@UserRole, UserRole),
				IsFileUploadRequired = ISNULL(@IsUploadFileRequired, 0),
				IsFileUploadable = ISNULL(@IsFileUploadable, 1),
				IsCommentable = ISNULL(@IsCommentable, 1)
			WHERE Id = @Id;

			-- Check if the relationship exists and update/insert accordingly
			IF EXISTS(SELECT 1 FROM SBSC.DocumentsCertifications WHERE DocId = @Id AND CertificationId = @CertificationId)
			BEGIN
				-- Update existing record
				UPDATE SBSC.DocumentsCertifications 
				SET DisplayOrder = CASE 
									WHEN @DisplayOrder IS NULL THEN DisplayOrder -- Keep existing
									ELSE @DisplayOrder 
								   END,
					IsWarning = ISNULL(@IsWarning, IsWarning)
				WHERE DocId = @Id AND CertificationId = @CertificationId;
			END
			ELSE
			BEGIN
				-- Insert new record
				INSERT INTO SBSC.DocumentsCertifications (DocId, CertificationId, DisplayOrder, IsWarning)
				VALUES(@Id, @CertificationId, 
					   CASE 
						   WHEN @DisplayOrder IS NULL THEN 
							   ISNULL((SELECT MAX(DisplayOrder) FROM SBSC.DocumentsCertifications WHERE CertificationId = @CertificationId), 0) + 1
						   ELSE @DisplayOrder
					   END, 
					   ISNULL(@IsWarning, 0));
			END

			IF @DefaultLangId IS NOT NULL
			BEGIN
				UPDATE [SBSC].[DocumentLanguage]
				SET [Headlines] = ISNULL(@Headlines, Headlines),
					[Description] = ISNULL(@Description, [Description])
				WHERE [DocId] = @Id AND [LangId] = @DefaultLangId;
			END

			IF @LangId IS NOT NULL
			BEGIN
				UPDATE [SBSC].[DocumentLanguage]
				SET [Headlines] = ISNULL(@HeadlinesLang, Headlines),
					[Description] = ISNULL(@DescriptionLang, [Description])
				WHERE [DocId] = @Id AND [LangId] = @LangId;
			END


			
			-- Return updated document
			SELECT 
				@Id AS Id, 
				@IsVisible AS IsVisible;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			ROLLBACK TRANSACTION;
			THROW;
		END CATCH
	END

    -- DELETE Operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRY
			-- First get the current DisplayOrder of the record to be deleted
			DECLARE @CurrentDisplayOrder INT;
			SELECT @CurrentDisplayOrder = DisplayOrder 
			FROM [SBSC].[DocumentsCertifications] 
			WHERE DocId = @Id;

			-- Delete the record
			DELETE FROM [SBSC].[Documents] WHERE Id = @Id;
        
			-- Update DisplayOrder for all records that come after the deleted record
			IF @CurrentDisplayOrder IS NOT NULL
			BEGIN
				UPDATE [SBSC].[DocumentsCertifications]
				SET DisplayOrder = DisplayOrder - 1
				WHERE CertificationId = @CertificationId
				AND DisplayOrder > @CurrentDisplayOrder;
			END

			SELECT @Id AS Id; 
		END TRY
		BEGIN CATCH
			THROW; -- Re-throw error
		END CATCH;
	END

    ELSE IF @Action = 'LIST'
	BEGIN
		DECLARE @DefaultLanguageId INT;
		-- If LangId is not provided, get the first Id from Languages table
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @DefaultLanguageId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageId; -- Set LangId to the first language Id
		END

		IF @SortColumn NOT IN ('DisplayOrder', 'Headlines')
			SET @SortColumn = 'DisplayOrder';
        
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';
   
		-- Declare variables for pagination
		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT = (@PageNumber - 1) * @PageSize;
		DECLARE @TotalRecords INT = 0;  -- Initialize the total records variable
		DECLARE @TotalPages INT;
    
		-- Define the WHERE clause for search and certification filtering
		SET @WhereClause = N'
			WHERE vd.LangId = @LangId
			AND (@CertificationId IS NULL OR vd.CertificationId = @CertificationId)
			AND (@SearchValue IS NULL OR vd.Headlines LIKE ''%'' + @SearchValue + ''%'')';

		IF @AuditorId IS NOT NULL AND EXISTS (SELECT 1 FROM SBSC.Auditor WHERE IsSBSCAuditor = 0 AND Id = @AuditorId)
		BEGIN
			SET @WhereClause += N'
				AND vd.DocumentId IN (SELECT DocId FROM SBSC.DocumentsCertifications
					WHERE CertificationId IN (SELECT CertificationId 
							FROM SBSC.Auditor_Certifications 
							WHERE AuditorId = @AuditorId))
			'
		END

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(vd.DocumentId)
			FROM [SBSC].[vw_DocumentDetails] vd
			' + @WhereClause;

		SET @ParamDefinition = N'@SearchValue NVARCHAR(100), @LangId INT, @AuditorId INT, @CertificationId INT = NULL, @TotalRecords INT OUTPUT'; 
    
		-- Execute the total count query and assign the result to @TotalRecords
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @AuditorId, @CertificationId, @TotalRecords OUTPUT;
    
		-- Calculate total pages based on @TotalRecords
		SET @TotalPages = CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize);
    
		-- Retrieve paginated data with certifications
		SET @SQL = N'
			SELECT 
				vd.*
			FROM [SBSC].[vw_DocumentDetails] vd
			' + @WhereClause + '
			ORDER BY ' + QUOTENAME(@SortColumn) + ' ' + @SortDirection + '
			OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + ' ROWS 
			FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + ' ROWS ONLY';

		-- Execute the paginated query
		EXEC sp_executesql @SQL, @ParamDefinition, @SearchValue, @LangId, @AuditorId, @CertificationId, @TotalRecords OUTPUT;
    
		-- Return pagination details
		SELECT @TotalRecords AS TotalRecords, 
				@TotalPages AS TotalPages, 
				@PageNumber AS CurrentPage, 
				@PageSize AS PageSize,
				CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
				CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END

    -- UPDATELANG Operation to update document language-specific information
    ELSE IF @Action = 'UPDATELANG'
    BEGIN
		DECLARE @DefaultUpdateLangId INT;
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultUpdateLangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
            SET @LangId = @DefaultUpdateLangId;
        END

        IF @Id IS NULL
            BEGIN
                RAISERROR('Document Id must be provided for updating language.', 16, 1);
            END
        ELSE
			BEGIN TRY
				UPDATE [SBSC].[DocumentLanguage]
				SET Headlines = ISNULL(@Headlines, Headlines),
					[Description] = ISNULL(@Description, [Description]) 
				WHERE [DocId] = @Id and [LangId] = @LangId

				SELECT @@ROWCOUNT AS RowsAffected; -- Return the number of rows affected
			END TRY
			BEGIN CATCH
				THROW; -- Re-throw the error
			END CATCH
	END

	ELSE IF @Action = 'GETDOCUMENTCERTIFICATIONS'
    BEGIN
	    DECLARE @DefaultLanguageCertificationId INT;
        -- If LangId is not provided, get the first Id from Languages table
        IF @LangId IS NULL
        BEGIN
            SELECT TOP 1 @DefaultLanguageCertificationId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
			SET @LangId = @DefaultLanguageCertificationId; 
        END

        SELECT 
            dc.DocId,
            dc.CertificationId,
            c.CertificateCode,
            cl.CertificationName
        FROM 
            [SBSC].[DocumentsCertifications] dc
            INNER JOIN [SBSC].[Certification] c 
                ON dc.CertificationId = c.Id
            -- Left join with CertificationLanguage for requested language
            LEFT JOIN [SBSC].[CertificationLanguage] cl 
                ON c.Id = cl.CertificationId 
                AND cl.LangId = @LangId
        WHERE 
            dc.DocId = @Id
        ORDER BY 
            c.CertificateCode;
    END
	
	-- DISPLAYORDER operation
	ELSE IF @Action = 'DISPLAYORDER'
	BEGIN
		DECLARE @OldDisplayOrder INT;

		-- Validate if the provided Document ID exists
		IF NOT EXISTS (SELECT 1 FROM [SBSC].DocumentsCertifications WHERE DocId = @Id AND CertificationId = @CertificationId)
		BEGIN
			RAISERROR('Invalid Document ID and Certification ID combination', 16, 1);
			RETURN;
		END

		-- Get the current DisplayOrder for the provided Document ID
		SELECT @OldDisplayOrder = DisplayOrder
		FROM [SBSC].DocumentsCertifications
		WHERE DocId = @Id
		AND CertificationId = @CertificationId;

		-- If the old DisplayOrder is NULL, we need to handle it as a special case
		IF @OldDisplayOrder IS NULL
		BEGIN
        BEGIN TRANSACTION;
        
			-- Shift all existing items up
			UPDATE [SBSC].DocumentsCertifications
			SET DisplayOrder = DisplayOrder + 1
			WHERE CertificationId = @CertificationId
			AND DisplayOrder >= @DisplayOrder
			AND DisplayOrder IS NOT NULL;

			-- Set the new DisplayOrder
			UPDATE [SBSC].DocumentsCertifications
			SET DisplayOrder = @DisplayOrder
			WHERE DocId = @Id 
			AND CertificationId = @CertificationId;

			IF @@ERROR <> 0
			BEGIN
				ROLLBACK TRANSACTION;
				RAISERROR('Error updating display order', 16, 1);
				RETURN;
			END

			COMMIT TRANSACTION;
			RETURN;
		END

		IF @DisplayOrder = @OldDisplayOrder
		BEGIN
			RETURN; -- No update needed
		END

		BEGIN TRANSACTION;
			-- If moving down in the order (DisplayOrder is increasing)
			IF @DisplayOrder > @OldDisplayOrder
			BEGIN
				-- Shift display orders down for items between old and new positions
				UPDATE [SBSC].DocumentsCertifications
				SET DisplayOrder = DisplayOrder - 1
				WHERE CertificationId = @CertificationId AND DisplayOrder > @OldDisplayOrder AND DisplayOrder <= @DisplayOrder;
			END
			-- If moving up in the order (DisplayOrder is decreasing)
			ELSE IF @DisplayOrder < @OldDisplayOrder
			BEGIN
				-- Shift display orders up for items between new and old positions
				UPDATE [SBSC].DocumentsCertifications
				SET DisplayOrder = DisplayOrder + 1
				WHERE CertificationId = @CertificationId AND DisplayOrder >= @DisplayOrder AND DisplayOrder < @OldDisplayOrder;
			END

			-- Update the dragged item's DisplayOrder to the new value
			UPDATE [SBSC].DocumentsCertifications
			SET DisplayOrder = @DisplayOrder
			WHERE DocId = @Id
			AND CertificationId = @CertificationId;

		-- Commit the transaction
		COMMIT TRANSACTION;
	END

	IF @Action = 'LIST_BY_CERTIFICATION_CODES'
    BEGIN
        IF @LangId IS NULL
        BEGIN
            DECLARE @DefaultLangDocumentId INT;
            SELECT TOP 1 @DefaultLangDocumentId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
            SET @LangId = @DefaultLangDocumentId;
        END
        
        -- Select data grouped by certification
        SELECT 
            c.Id AS CertificationId,
            c.CertificateCode,
            (
                SELECT 
                    vd.*,
                    CASE 
                        WHEN @CustomerId IS NOT NULL THEN (
                            SELECT TOP 1
                                rs.StatusName as AuditorResponseStatus, acr.IsApproved
                            FROM [SBSC].[CustomerBasicDocResponse] cbdr
                            LEFT JOIN [SBSC].[AuditorCustomerResponses] acr 
                                ON acr.CustomerBasicDocResponse = cbdr.Id
                            LEFT JOIN [SBSC].[AuditorResponseStatuses] rs
                                ON rs.Id = acr.ResponseStatusId
                            WHERE cbdr.BasicDocId = dc.DocId
                                AND cbdr.CustomerId = @CustomerId
                            ORDER BY acr.ResponseDate DESC
                            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                        )
                        ELSE NULL 
                    END as AuditorResponse
                FROM [SBSC].[vw_DocumentDetails] vd
                INNER JOIN [SBSC].[DocumentsCertifications] dc 
                    ON vd.DocumentId = dc.DocId
                WHERE dc.CertificationId = c.Id 
                    AND vd.LangId = @LangId
                FOR JSON PATH
            ) AS CertificationDocumentsJson
        FROM [SBSC].[Certification] c
        WHERE EXISTS (
            SELECT 1 FROM @CertificationCodes cc
            WHERE cc.CertificationCode = c.CertificateCode
        )
        ORDER BY c.CertificateCode;
    END

	ELSE IF @Action = 'LIST_BY_CERTIFICATION_IDS'
	BEGIN
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @LangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
		END

		SELECT DISTINCT
			c.Id AS CertificationId,
			c.CertificateCode,
			--acc.CustomerCertificationDetailsId,
			ISNULL(CertDocs.CertificationDocumentsJson, '[]') AS CertificationDocumentsJson
		FROM [SBSC].[Certification] c
		INNER JOIN SBSC.Customer_Certifications cc ON c.Id = cc.CertificateId
		JOIN SBSC.AssignmentCustomerCertification acc ON acc.CustomerCertificationId = cc.CustomerCertificationId
		OUTER APPLY (
			SELECT DISTINCT
				vd.*,
				dct.IsApproved,
				(SELECT TOP 1 CustomerCommentTurn 
						FROM SBSC.DocumentCommentThread 
						WHERE DocumentId = vd.DocumentId AND CustomerId = cc.CustomerId 
						ORDER BY CreatedDate DESC) AS CustomerCommentTurn,
				CAST(CASE
					WHEN @UserRole = 2 AND (
						SELECT TOP 1 CustomerCommentTurn 
						FROM SBSC.DocumentCommentThread 
						WHERE DocumentId = vd.DocumentId AND CustomerId = cc.CustomerId 
						ORDER BY CreatedDate DESC
					) = 1 THEN 1
					WHEN @UserRole = 3 AND (
						SELECT TOP 1 CustomerCommentTurn 
						FROM SBSC.DocumentCommentThread 
						WHERE DocumentId = vd.DocumentId AND CustomerId = cc.CustomerId 
						ORDER BY CreatedDate DESC
					) = 0 THEN 1
					WHEN ((@UserRole = 2 OR @UserRole = 3) AND (
						SELECT TOP 1 ReadStatus 
						FROM SBSC.DocumentCommentThread 
						WHERE DocumentId = vd.DocumentId AND CustomerId = cc.CustomerId 
						ORDER BY CreatedDate DESC
					) = 1) THEN 1
					ELSE 0
				END AS BIT) AS ReadStatus
			FROM [SBSC].[vw_DocumentDetails] vd
			LEFT JOIN SBSC.DocumentCommentThread dct 
				ON vd.DocumentId = dct.DocumentId AND dct.CustomerId = cc.CustomerId
			WHERE vd.CertificationId = c.Id
			  AND vd.LangId = @LangId
			FOR JSON PATH, INCLUDE_NULL_VALUES
		) AS CertDocs(CertificationDocumentsJson)
		WHERE acc.AssignmentId = @AssignmentId
		  AND cc.CustomerId = @CustomerId
		ORDER BY c.CertificateCode;

	END
END

GO