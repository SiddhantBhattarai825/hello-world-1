SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SBSC].[sp_Report_CRUD]
    @Action NVARCHAR(50),
    @Id INT = NULL,
    @CertificationId INT = NULL,
	@CustomerId INT = NULL,
    @CustomerCertificationId INT = NULL,
	@DefaultLangId INT = NULL,
	@HeadlinesDefault NVARCHAR(255) = NULL,
    @LangId INT = NULL,
	@HeadlinesLang NVARCHAR(255) = NULL,
	@DisplayOrder INT = NULL,
	@IsDefault BIT = NULL,
	@AuditorId INT = NULL,
	@CustomerCertificationDetailsId INT = NULL,

	@CertificationIds [SBSC].[CertificationIdList] READONLY,
	@Details NVARCHAR(MAX) = NULL,
	@ApplyAll BIT = NULL,

	-- for multiple tilfalle at once
	@AssignmentId INT = NULL,


    @PageNumber INT = 1,
    @PageSize INT = 10,
    @SearchValue NVARCHAR(100) = NULL,
    @SortColumn NVARCHAR(50) = 'Id',
    @SortDirection NVARCHAR(4) = 'ASC'
AS
BEGIN
    SET NOCOUNT ON;

    -- Validate the Action parameter
    IF @Action NOT IN ('CREATE', 'READ', 'UPDATE', 'DELETE', 'LIST', 'CREATE_CUSTOMER_REPORT', 'UPDATE_CUSTOMER_REPORT', 'GET_CUSTOMER_REPORT', 'DISPLAYORDER')
    BEGIN
        RAISERROR('Invalid @Action parameter. Use CREATE, READ, UPDATE, DELETE, LIST, CREATE_CUSTOMER_REPORT, GET_CUSTOMER_REPORT, or DISPLAYORDER.', 16, 1);
        RETURN;
    END
	
    -- CREATE operation
	IF @Action = 'CREATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;

			-- Insert into Report table
			INSERT INTO [SBSC].[ReportBlocks] (DisplayOrder, IsDefault)
			VALUES (@DisplayOrder, ISNULL(@IsDefault, 0));

			DECLARE @NewReportId INT = SCOPE_IDENTITY();

			-- Insert into ReportLanguage table for all languages
			DECLARE @CurrentLangId INT;
			DECLARE LangCursor CURSOR FOR
			SELECT Id FROM [SBSC].[Languages];

			OPEN LangCursor;
        
			FETCH NEXT FROM LangCursor INTO @CurrentLangId;
			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF @CurrentLangId = @DefaultLangId
				BEGIN
					INSERT INTO [SBSC].[ReportBlocksLanguage] (ReportBlockId, Headlines, [LangId])
					VALUES (@NewReportId, @HeadlinesDefault, @CurrentLangId);
				END
				ELSE IF @CurrentLangId = @LangId
				BEGIN
					INSERT INTO [SBSC].[ReportBlocksLanguage] (ReportBlockId, Headlines, [LangId])
					VALUES (@NewReportId, @HeadlinesLang, @CurrentLangId);
				END
				ELSE
				BEGIN
					INSERT INTO [SBSC].[ReportBlocksLanguage] (ReportBlockId, Headlines, [LangId])
					VALUES (@NewReportId, NULL, @CurrentLangId);
				END

				FETCH NEXT FROM LangCursor INTO @CurrentLangId;
			END

			CLOSE LangCursor;
			DEALLOCATE LangCursor;

			-- Handle Certification associations
			IF @ApplyAll = 1
			BEGIN
				-- Insert into all certifications
				INSERT INTO [SBSC].[ReportBlocksCertifications] (ReportBlockId, CertificationId)
				SELECT @NewReportId, Id
				FROM [SBSC].[Certification];
			END
			ELSE IF EXISTS (SELECT 1 FROM @CertificationIds)
			BEGIN
				-- Insert into selected certifications
				INSERT INTO [SBSC].[ReportBlocksCertifications] (ReportBlockId, CertificationId)
				SELECT @NewReportId, CertificationId
				FROM @CertificationIds;
			END

			COMMIT TRANSACTION;

			SELECT @NewReportId AS ReportId,
					@HeadlinesDefault AS HeadlinesDefault, 
					@DefaultLangId AS DefaultLangId,
					@HeadlinesLang AS HeadlinesLang,
					@LangId AS LangId,
					@DisplayOrder AS DisplayOrder,
					@IsDefault AS IsDefault;

		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			THROW;
		END CATCH;
	END
	
    -- READ operation
    ELSE IF @Action = 'READ'
    BEGIN
        IF @Id IS NOT NULL
        BEGIN
            SELECT * 
            FROM [SBSC].[vw_ReportDetails]
            WHERE Id = @Id AND LangId = ISNULL(@LangId, (SELECT TOP 1 Id FROM [SBSC].[Languages] WHERE IsDefault = 1));
        END
        ELSE
        BEGIN
            SELECT * 
            FROM [SBSC].[vw_ReportDetails]
			WHERE [LangId] = ISNULL(@LangId, (SELECT TOP 1 Id FROM [SBSC].[Languages] WHERE IsDefault = 1));
        END
    END

    -- UPDATE operation
	ELSE IF @Action = 'UPDATE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
            
			-- Get the current DisplayOrder of the report being updated
			DECLARE @CurrentDisplayOrder int;
			SELECT @CurrentDisplayOrder = DisplayOrder
			FROM [SBSC].[ReportBlocks]
			WHERE Id = @Id;

			-- Only proceed with DisplayOrder updates if it's actually changing
			IF @DisplayOrder IS NOT NULL AND @DisplayOrder != @CurrentDisplayOrder
			BEGIN
				-- If moving to a later position (increasing DisplayOrder)
				IF @DisplayOrder > @CurrentDisplayOrder
				BEGIN
					UPDATE [SBSC].[ReportBlocks]
					SET DisplayOrder = DisplayOrder - 1
					WHERE DisplayOrder > @CurrentDisplayOrder 
					AND DisplayOrder <= @DisplayOrder
					AND Id != @Id;
				END
				-- If moving to an earlier position (decreasing DisplayOrder)
				ELSE
				BEGIN
					UPDATE [SBSC].[ReportBlocks]
					SET DisplayOrder = DisplayOrder + 1
					WHERE DisplayOrder >= @DisplayOrder 
					AND DisplayOrder < @CurrentDisplayOrder
					AND Id != @Id;
				END
			END

			-- Update the target ReportBlock
			UPDATE [SBSC].[ReportBlocks]
			SET DisplayOrder = ISNULL(@DisplayOrder, DisplayOrder),
				IsDefault = ISNULL(@IsDefault, IsDefault)
			WHERE Id = @Id;

			-- Update language-specific data
			IF @LangId IS NOT NULL
			BEGIN
				UPDATE [SBSC].[ReportBlocksLanguage]
				SET Headlines = ISNULL(@HeadlinesLang, Headlines)
				WHERE ReportBlockId = @Id AND [LangId] = @LangId;
			END

			IF @DefaultLangId IS NOT NULL
			BEGIN
				UPDATE [SBSC].[ReportBlocksLanguage]
				SET Headlines = ISNULL(@HeadlinesDefault, Headlines)
				WHERE ReportBlockId = @Id AND [LangId] = @DefaultLangId;
			END

			-- Handle Certification associations
			IF @ApplyAll = 1
			BEGIN
				-- Delete all existing associations for this ReportBlock
				DELETE FROM [SBSC].[ReportBlocksCertifications]
				WHERE ReportBlockId = @Id;
            
				-- Insert associations for all certifications
				INSERT INTO [SBSC].[ReportBlocksCertifications] (ReportBlockId, CertificationId)
				SELECT @Id, Id
				FROM [SBSC].[Certification];
			END
			ELSE IF EXISTS (SELECT 1 FROM @CertificationIds)
			BEGIN
				-- Delete existing associations for this ReportBlock
				DELETE FROM [SBSC].[ReportBlocksCertifications]
				WHERE ReportBlockId = @Id;
            
				-- Insert associations for the provided certifications
				INSERT INTO [SBSC].[ReportBlocksCertifications] (ReportBlockId, CertificationId)
				SELECT @Id, CertificationId
				FROM @CertificationIds;
			END

			COMMIT TRANSACTION;

			SELECT  Id AS ReportId,
					@HeadlinesDefault AS HeadlinesDefault,
					@DefaultLangId AS DefaultLangId,
					@HeadlinesLang AS HeadlinesLang,
					@LangId AS LangId,
					DisplayOrder,
					IsDefault
			FROM SBSC.ReportBlocks 
			WHERE Id = @Id
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			THROW;
		END CATCH;
	END

    -- DELETE operation
	ELSE IF @Action = 'DELETE'
	BEGIN
		BEGIN TRY
			BEGIN TRANSACTION;
            
			-- Get the current DisplayOrder of the report being deleted
			DECLARE @CurrentDisplayOrderDelete int;
			SELECT @CurrentDisplayOrderDelete = DisplayOrder
			FROM [SBSC].[ReportBlocks]
			WHERE Id = @Id;

			-- Delete language-specific data
			DELETE FROM [SBSC].[ReportBlocksLanguage] 
			WHERE ReportBlockId = @Id;

			-- Delete certification associations
			DELETE FROM [SBSC].[ReportBlocksCertifications]
			WHERE ReportBlockId = @Id;

			-- Delete the report block
			DELETE FROM [SBSC].[ReportBlocks] 
			WHERE Id = @Id;

			-- Update DisplayOrder for remaining reports
			UPDATE [SBSC].[ReportBlocks]
			SET DisplayOrder = DisplayOrder - 1
			WHERE DisplayOrder > @CurrentDisplayOrderDelete;

			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
			THROW;
		END CATCH;
	END

    -- LIST operation
	ELSE IF @Action = 'LIST'
	BEGIN
		-- Set default sorting column and direction if not provided
		IF @SortColumn NOT IN ('Id', 'DisplayOrder')
			SET @SortColumn = 'DisplayOrder';
		IF @SortDirection NOT IN ('ASC', 'DESC')
			SET @SortDirection = 'ASC';

		DECLARE @SQL NVARCHAR(MAX);
		DECLARE @WhereClause NVARCHAR(MAX);
		DECLARE @ParamDefinition NVARCHAR(500);
		DECLARE @Offset INT;
		DECLARE @TotalRecords INT;
		DECLARE @TotalPages INT;
		DECLARE @OrderByClause NVARCHAR(MAX);
    
		-- Get default language if not provided
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @LangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
		END

		SET @Offset = (@PageNumber - 1) * @PageSize;
		SET @TotalRecords = 0;
		SET @WhereClause = N'WHERE 1 = 1 AND LangId = @LangId';
    
		IF @SearchValue IS NOT NULL
			SET @WhereClause = @WhereClause + N'
			AND (Headlines LIKE ''%'' + @SearchValue + ''%'')';

		SET @OrderByClause = N'ORDER BY ' + QUOTENAME(@SortColumn) + N' ' + @SortDirection;

		-- Count total records
		SET @SQL = N'
			SELECT @TotalRecords = COUNT(*)
			FROM [SBSC].[vw_ReportDetails] r
			' + @WhereClause;

		-- Define parameter types for sp_executesql
		SET @ParamDefinition = N'
			@LangId INT, 
			@SearchValue NVARCHAR(100), 
			@CertificationId INT,
			@TotalRecords INT OUTPUT';

		-- Execute the total count query
		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@LangId, 
			@SearchValue, 
			@CertificationId,
			@TotalRecords OUTPUT;

		-- Calculate total pages
		SET @TotalPages = CASE 
			WHEN @TotalRecords > 0 
			THEN CEILING(CAST(@TotalRecords AS FLOAT) / @PageSize) 
			ELSE 0 
		END;

		-- FIRST result set: Return the main data
		SET @SQL = N'SELECT 
			Id,
			DisplayOrder,
			Headlines,
			LangId,
			IsDefault,
			CertificationsJson
		FROM [SBSC].[vw_ReportDetails] r
		' + @WhereClause + N'
		' + @OrderByClause + N'
		OFFSET ' + CAST(@Offset AS NVARCHAR(10)) + N' ROWS 
		FETCH NEXT ' + CAST(@PageSize AS NVARCHAR(10)) + N' ROWS ONLY';
    
		-- Execute the main data query FIRST
		EXEC sp_executesql @SQL, 
			@ParamDefinition, 
			@LangId, 
			@SearchValue, 
			@CertificationId,
			@TotalRecords OUTPUT;

		-- SECOND result set: Return pagination info
		SELECT 
			@TotalRecords AS TotalRecords, 
			@TotalPages AS TotalPages, 
			@PageNumber AS CurrentPage, 
			@PageSize AS PageSize,
			CASE WHEN @PageNumber < @TotalPages THEN 1 ELSE 0 END AS HasNextPage,
			CASE WHEN @PageNumber > 1 THEN 1 ELSE 0 END AS HasPreviousPage;
	END

	-- CREATE customer reports
	ELSE IF @Action = 'CREATE_CUSTOMER_REPORT'
	BEGIN    
		IF @AssignmentId > 0
		BEGIN
			-- Get all CustomerCertificationIds for the given AssignmentId
			DECLARE @CustomerCertificationDetailsIds TABLE (CustomerCertificationDetailsId INT);
        
			INSERT INTO @CustomerCertificationDetailsIds (CustomerCertificationDetailsId)
			SELECT CustomerCertificationDetailsId 
			FROM SBSC.AssignmentCustomerCertification 
			WHERE AssignmentId = @AssignmentId;

			DECLARE @DetailId INT;
			DECLARE DetailId CURSOR FOR
			SELECT CustomerCertificationDetailsId 
			FROM SBSC.AssignmentCustomerCertification 
			WHERE AssignmentId = @AssignmentId;

			OPEN DetailId

			FETCH NEXT FROM DetailId INTO @DetailId;

			WHILE @@FETCH_STATUS = 0
			BEGIN
				IF EXISTS (
					SELECT 1 
					FROM SBSC.ReportCustomerCertifications 
					WHERE ReportBlockId = @Id 
					AND CustomerCertificationDetailsId = @DetailId)
				BEGIN
					UPDATE rcc
					SET Details = ISNULL(@Details, rcc.Details),
						ModifiedDate = GETUTCDATE(),
						AuditorId = ISNULL(@AuditorId, rcc.AuditorId)
					FROM SBSC.ReportCustomerCertifications rcc
					--INNER JOIN SBSC.AssignmentCustomerCertification acc ON rcc.CustomerCertificationId = acc.CustomerCertificationId
					WHERE rcc.ReportBlockId = @Id AND rcc.CustomerCertificationDetailsId = @DetailId
				END
				ELSE
				BEGIN
					INSERT INTO SBSC.ReportCustomerCertifications (CustomerCertificationId, ReportBlockId, Details, CreatedDate, ModifiedDate, AuditorId, Recertification, CustomerCertificationDetailsId)
					VALUES(
						(SELECT CustomerCertificationId FROM SBSC.CustomerCertificationDetails 
						WHERE Id = @DetailId),
						@Id,
						@Details,
						GETUTCDATE(),
						GETUTCDATE(),
						@AuditorId,
						(SELECT Recertification FROM SBSC.CustomerCertificationDetails 
						WHERE Id = @DetailId),
						@DetailId)
				END
				FETCH NEXT FROM DetailId INTO @DetailId
			END

			CLOSE DetailId
			DEALLOCATE DetailId


			EXEC sp_execute_remote 
						@data_source_name = N'SbscCustomerDataSource',
						@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
								@Action = @Action,
								@AssignmentId = @AssignmentId',
						@params = N'@Action NVARCHAR(500), @AssignmentId INT',
						@Action = 'CERTIFICATION_MODIFIED',
						@AssignmentId = @AssignmentId;

        
			-- Return results for only the first inserted record
			SELECT @Id AS ReportBlockId, 
				   @Details AS Details, 
				   (SELECT CustomerCertificationId 
					FROM SBSC.CustomerCertificationDetails 
					WHERE Id = ccd.CustomerCertificationDetailsId) AS CustomerCertificationId
			FROM (SELECT TOP 1 * FROM @CustomerCertificationDetailsIds) ccd;
        END
		ELSE
		BEGIN
			-- Original single CustomerCertificationId logic
			INSERT INTO SBSC.ReportCustomerCertifications (CustomerCertificationId, ReportBlockId, Details, CreatedDate, ModifiedDate, AuditorId, Recertification, CustomerCertificationDetailsId)
			VALUES (@CustomerCertificationId, @Id, @Details, GETUTCDATE(), GETUTCDATE(), @AuditorId, 
					(SELECT MAX(Recertification) 
					 FROM SBSC.Customer_Certifications 
					 WHERE CustomerCertificationId = @CustomerCertificationId),
					 @CustomerCertificationDetailsId);

			EXEC sp_execute_remote 
					@data_source_name = N'SbscCustomerDataSource',
					@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
							@Action = @Action,
							@CustomerCertificationDetailsId = @CustomerCertificationDetailsId',
					@params = N'@Action NVARCHAR(500), @CustomerCertificationDetailsId INT',
					@Action = 'CERTIFICATION_MODIFIED',
					@CustomerCertificationDetailsId = @CustomerCertificationDetailsId;

        
			SELECT @Id AS ReportBlockId,
					@CustomerCertificationId AS CustomerCertificationId,
					@Details AS Details;
		END
	END

	-- UPDATE customer reports 
	ELSE IF @Action = 'UPDATE_CUSTOMER_REPORT'
	BEGIN
		IF @AssignmentId > 0
		BEGIN
			-- Update all records for CustomerCertificationIds associated with the AssignmentId
			UPDATE rcc
			SET Details = ISNULL(@Details, rcc.Details),
				ModifiedDate = GETUTCDATE(),
				AuditorId = ISNULL(@AuditorId, rcc.AuditorId)
			FROM SBSC.ReportCustomerCertifications rcc
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON rcc.CustomerCertificationId = acc.CustomerCertificationId
			WHERE rcc.ReportBlockId = @Id AND acc.AssignmentId = @AssignmentId;

			EXEC sp_execute_remote 
						@data_source_name = N'SbscCustomerDataSource',
						@stmt = N'EXEC [SBSC].[sp_UpdateStatus] 
								@Action = @Action,
								@AssignmentId = @AssignmentId',
						@params = N'@Action NVARCHAR(500), @AssignmentId INT',
						@Action = 'CERTIFICATION_MODIFIED',
						@AssignmentId = @AssignmentId;
        
			-- Return results for all updated records
			SELECT 
				@Id AS ReportBlockId,
				rcc.CustomerCertificationId,
				@Details AS Details
			FROM SBSC.ReportCustomerCertifications rcc
			INNER JOIN SBSC.AssignmentCustomerCertification acc ON rcc.CustomerCertificationId = acc.CustomerCertificationId
			WHERE rcc.ReportBlockId = @Id AND acc.AssignmentId = @AssignmentId;
		END
		ELSE
		BEGIN
			-- Original single CustomerCertificationId logic
			UPDATE SBSC.ReportCustomerCertifications
			SET Details = ISNULL(@Details, Details),
				ModifiedDate = GETUTCDATE(),
				AuditorId = ISNULL(@AuditorId, AuditorId)
			WHERE ReportBlockId = @Id AND CustomerCertificationId = @CustomerCertificationId;

			SELECT @Id AS ReportBlockId,
					@CustomerCertificationId AS CustomerCertificationId,
					@Details AS Details;
		END
	END

	-- READ customer reports
	ELSE IF @Action = 'GET_CUSTOMER_REPORT'
	BEGIN
		-- Get default language if not provided
		IF @LangId IS NULL
		BEGIN
			SELECT TOP 1 @LangId = [Id] FROM [SBSC].[Languages] WHERE IsDefault = 1;
		END

		IF @AssignmentId IS NULL
		BEGIN
			RAISERROR('Invalid assignment Id provided for report.', 16, 1);
		END

		-- Get CustomerCertificationDetailsId and related data from assignment
		DECLARE @CustomerCertificationDetailsGetIds TABLE (
			CustomerCertificationDetailsId INT,
			CustomerCertificationId INT,
			CertificateId INT
		);

		INSERT INTO @CustomerCertificationDetailsGetIds (CustomerCertificationDetailsId, CustomerCertificationId, CertificateId)
		SELECT DISTINCT 
			acc.CustomerCertificationDetailsId,
			ccd.CustomerCertificationId,
			cc.CertificateId
		FROM SBSC.AssignmentCustomerCertification acc
		INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
		INNER JOIN SBSC.Customer_Certifications cc ON ccd.CustomerCertificationId = cc.CustomerCertificationId
		WHERE acc.AssignmentId = @AssignmentId;


		-- First result set: first unique Report data
		select DISTINCT
				rbc.ReportBlockId,
				acc.AssignmentId,
				cc.CustomerCertificationId,
				ccd.Id AS CustomerCertificationDetailsId,
				CAST (ccd.Recertification AS INT) AS Recertification,
				cc.CertificateNumber,
				c.CertificateCode,
				rcc.Details,
				rb.DisplayOrder,
				rbl.Headlines,
				rbl.LangId,
				rb.IsDefault,
				rcc.CreatedDate,
				aosh.StatusDate AS SubmittedDate
			FROM SBSC.ReportBlocksCertifications rbc
			LEFT JOIN SBSC.ReportBlocks rb ON rb.Id = rbc.ReportBlockId
			LEFT JOIN SBSC.ReportBlocksLanguage rbl ON rbl.ReportBlockId = rbc.ReportBlockId
			LEFT JOIN SBSC.Customer_Certifications cc ON rbc.CertificationId = cc.CertificateId
			LEFT JOIN SBSC.Certification c ON c.Id = cc.CertificateId
			INNER JOIN SBSC.CustomerCertificationDetails ccd ON ccd.CustomerCertificationId = cc.CustomerCertificationId
			LEFT JOIN SBSC.ReportCustomerCertifications rcc ON rcc.CustomerCertificationDetailsId = ccd.Id AND rcc.ReportBlockId = rb.Id
			LEFT JOIN SBSC.AssignmentCustomerCertification acc ON acc.CustomerCertificationDetailsId = ccd.Id
			LEFT JOIN [SBSC].[AssignmentOccasionStatusHistory] aosh ON (aosh.AssignmentOccasionId = acc.ID AND aosh.Status = 3)
			WHERE ccd.Id = (SELECT TOP 1 CustomerCertificationDetailsId FROM SBSC.AssignmentCustomerCertification where AssignmentId = @AssignmentId)
			and LangId = @LangId
		ORDER BY rb.DisplayOrder;

		-- Create CTE for chapter hierarchy with display order paths
		WITH ChapterHierarchy AS (
			-- Base case: top-level chapters
			SELECT 
				c.Id AS ChapterId,
				c.DisplayOrder,
				CAST(c.DisplayOrder AS VARCHAR(MAX)) AS PrefixPath,
				c.[Level],
				c.ParentChapterId,
				c.CertificationId
			FROM SBSC.Chapter c
			WHERE c.ParentChapterId IS NULL
			  AND c.CertificationId IN (
				SELECT CertificateId 
				FROM @CustomerCertificationDetailsGetIds
			)
			UNION ALL
			-- Recursive step: child chapters
			SELECT 
				ch.Id AS ChapterId,
				ch.DisplayOrder,
				CAST(p.PrefixPath + '.' + CAST(ch.DisplayOrder AS VARCHAR(10)) AS VARCHAR(MAX)) AS PrefixPath,
				ch.[Level],
				ch.ParentChapterId,
				ch.CertificationId
			FROM SBSC.Chapter ch
			INNER JOIN ChapterHierarchy p ON ch.ParentChapterId = p.ChapterId
			WHERE ch.CertificationId IN (
				SELECT CertificateId 
				FROM @CustomerCertificationDetailsGetIds
			)
		)

		-- Second result set: Auditor Notes (Simplified approach with CTE for prefix)
		SELECT 
			an.Id,
			an.AuditorId,
			cert.CertificateCode,
			r.Id AS RequirementId,
			COALESCE(ch.PrefixPath + '.' + CAST(rc.DispalyOrder AS VARCHAR(10)), CONVERT(VARCHAR, r.DisplayOrder)) AS Prefix,
			CONVERT(VARCHAR, r.Id) AS Requirement,
			an.Note,
			an.CreatedDate
		FROM SBSC.AuditorNotes an 
		INNER JOIN SBSC.CustomerResponse cr ON an.CustomerResponseId = cr.Id
		INNER JOIN SBSC.AssignmentCustomerCertification acc ON acc.CustomerCertificationDetailsId = cr.CustomerCertificationDetailsId
		INNER JOIN SBSC.Requirement r ON cr.RequirementId = r.Id
		INNER JOIN SBSC.RequirementChapters rc ON rc.RequirementId = r.Id
		INNER JOIN SBSC.Chapter c ON rc.ChapterId = c.Id
		INNER JOIN SBSC.Certification cert ON cert.Id = c.CertificationId
		LEFT JOIN ChapterHierarchy ch ON ch.ChapterId = rc.ChapterId
		WHERE acc.AssignmentId = @AssignmentId
		ORDER BY Prefix;

		DECLARE @ResponseStatusCounts TABLE (
			ResponseStatusId INT,
			Count INT
		);
		DECLARE @TotalDeviation INT = 0;

		-- Loop through each CustomerCertificationDetailsId
		DECLARE @CurrentCertDetailsId INT;
		DECLARE CertDetailsId CURSOR FOR
		SELECT DISTINCT CustomerCertificationDetailsId 
		FROM @CustomerCertificationDetailsGetIds;

		OPEN CertDetailsId;
		FETCH NEXT FROM CertDetailsId INTO @CurrentCertDetailsId;

		WHILE @@FETCH_STATUS = 0
		BEGIN
			-- Get CertificateId for current CustomerCertificationDetailsId
			DECLARE @CurrentCertId INT;
			SELECT @CurrentCertId = CertificateId 
			FROM @CustomerCertificationDetailsGetIds 
			WHERE CustomerCertificationDetailsId = @CurrentCertDetailsId;
    
			-- Third result: ResponseStatus Counts for current CustomerCertificationDetailsId
			INSERT INTO @ResponseStatusCounts (ResponseStatusId, Count)
			SELECT 
				ars.ResponseStatusId, 
				COALESCE(COUNT(acr.ResponseStatusId), 0)
			FROM 
				(VALUES (1), (2), (3)) AS ars(ResponseStatusId)
			LEFT JOIN 
				SBSC.AuditorCustomerResponses acr
				ON acr.ResponseStatusId = ars.ResponseStatusId
				AND acr.CustomerResponseId IN (
					SELECT Id 
					FROM SBSC.CustomerResponse 
					WHERE CustomerCertificationDetailsId = @CurrentCertDetailsId
					AND RequirementId IN (
						SELECT rc.RequirementId 
						FROM SBSC.RequirementChapters rc
						INNER JOIN SBSC.Chapter ch ON rc.ChapterId = ch.Id
						WHERE ch.CertificationId = @CurrentCertId
					)
				)
				AND acr.ResponseStatusId < 4
			GROUP BY 
				ars.ResponseStatusId;
    
			-- Fourth result: Total deviation for current CustomerCertificationDetailsId
			DECLARE @DeviationCount INT;
			SELECT @DeviationCount = COUNT(IsApproved) 
			FROM SBSC.AuditorCustomerResponses 
			WHERE CustomerResponseId IN (
				SELECT Id 
				FROM SBSC.CustomerResponse 
				WHERE CustomerCertificationDetailsId = @CurrentCertDetailsId
				AND RequirementId IN (
					SELECT rc.RequirementId 
					FROM SBSC.RequirementChapters rc
					INNER JOIN SBSC.Chapter ch ON rc.ChapterId = ch.Id
					WHERE ch.CertificationId = @CurrentCertId
				)
			)
			AND IsApproved != 1;
    
			-- Accumulate total deviation
			SET @TotalDeviation += ISNULL(@DeviationCount, 0);
    
			-- Fetch next CustomerCertificationDetailsId
			FETCH NEXT FROM CertDetailsId INTO @CurrentCertDetailsId;
		END

		CLOSE CertDetailsId;
		DEALLOCATE CertDetailsId;

		-- Third result set: Final aggregated Response Status Counts
		SELECT 
			ResponseStatusId,
			SUM(Count) AS [TotalCount]
		FROM @ResponseStatusCounts
		GROUP BY ResponseStatusId
		ORDER BY ResponseStatusId;

		-- Fourth result set: Final aggregated Total Deviation
		SELECT @TotalDeviation AS TotalDeviation;

		-- Fifth result set: submission status and publish
		SELECT DISTINCT
			c.Id,
			c.CertificateCode,
			ao.Status,
			(SELECT
				Published
			FROM SBSC.CertificationLanguage
			WHERE CertificationId = c.Id
			AND LangId = @LangId
			) AS Published,
			cc.Recertification
		FROM SBSC.[AssignmentOccasions] ao
		INNER JOIN [SBSC].[AssignmentCustomerCertification] acc ON acc.AssignmentId = ao.Id
		INNER JOIN SBSC.CustomerCertificationDetails ccd ON acc.CustomerCertificationDetailsId = ccd.Id
		INNER JOIN SBSC.Customer_Certifications cc ON cc.CustomerCertificationId = ccd.CustomerCertificationId
		INNER JOIN [SBSC].Certification c ON c.Id = cc.CertificateId
		WHERE ao.Id = @AssignmentId
	END

	ELSE IF @Action = 'DISPLAYORDER'
	BEGIN
		DECLARE @OldDisplayOrder INT;
    
		-- Validate if the provided ReportBlock ID exists
		IF NOT EXISTS (SELECT 1 FROM [SBSC].[ReportBlocks] WHERE Id = @Id)
		BEGIN
			RAISERROR('Invalid ReportBlock ID', 16, 1);
			RETURN;
		END
    
		-- Get the current DisplayOrder for the provided ReportBlock ID
		SELECT @OldDisplayOrder = DisplayOrder
		FROM [SBSC].[ReportBlocks]
		WHERE Id = @Id;
    
		-- If the new DisplayOrder is same as old, no update needed
		IF @DisplayOrder = @OldDisplayOrder
		BEGIN
			RETURN;
		END
    
		BEGIN TRANSACTION;
		BEGIN TRY
			-- If moving down in the order (DisplayOrder is increasing)
			IF @DisplayOrder > @OldDisplayOrder
			BEGIN
				UPDATE [SBSC].[ReportBlocks]
				SET DisplayOrder = DisplayOrder - 1
				WHERE DisplayOrder > @OldDisplayOrder 
				AND DisplayOrder <= @DisplayOrder;
			END
			-- If moving up in the order (DisplayOrder is decreasing)
			ELSE IF @DisplayOrder < @OldDisplayOrder
			BEGIN
				UPDATE [SBSC].[ReportBlocks]
				SET DisplayOrder = DisplayOrder + 1
				WHERE DisplayOrder >= @DisplayOrder 
				AND DisplayOrder < @OldDisplayOrder;
			END
        
			-- Update the target ReportBlock's DisplayOrder to the new value
			UPDATE [SBSC].[ReportBlocks]
			SET DisplayOrder = @DisplayOrder
			WHERE Id = @Id;
        
			COMMIT TRANSACTION;
		END TRY
		BEGIN CATCH
			IF @@TRANCOUNT > 0
				ROLLBACK TRANSACTION;
            
			THROW;
		END CATCH
	END

END
GO