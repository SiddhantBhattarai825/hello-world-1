SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SBSC].[fn_GetChapterTreeRequirement]
(
    @ParentChapterId INT,          -- For recursion: the current parent chapter
    @LangId INT,
    @CertificationId INT = NULL,    -- Used only for the root call (when @ParentChapterId IS NULL)
    @CustomerId INT = NULL,         -- For computing requirement status
    @DeviationStatus BIT = 0 ,       -- New parameter for deviation status filtering
	@Recertification INT = NULL
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    DECLARE @json NVARCHAR(MAX);
    DECLARE @AuditYears NVARCHAR(50) = NULL;
    DECLARE @RelevantAuditYear NVARCHAR(10) = NULL;

    -- If CustomerId is provided, get the recertification and audit years
    IF @CustomerId IS NOT NULL AND @CertificationId IS NOT NULL
	BEGIN
		SELECT 
			@AuditYears = AuditYears
		FROM SBSC.Customer_Certifications
		WHERE CustomerId = @CustomerId 
		AND CertificateId = @CertificationId
		ORDER BY CreatedDate DESC;

		-- If Recertification > 0, calculate the relevant audit year value
		IF @Recertification >= 0 AND @AuditYears IS NOT NULL
		BEGIN
			-- Extract the audit year at the (Recertification) index (0-based)
			SELECT @RelevantAuditYear = value
			FROM (
				SELECT 
					LTRIM(RTRIM(value)) AS value, 
					ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS rn 
				FROM STRING_SPLIT(@AuditYears, ',')
				WHERE LTRIM(RTRIM(value)) <> ''
			) t
			WHERE rn = @Recertification;
		END
	END


    SELECT @json =
    (
        SELECT
            c.Id AS ChapterId,
            cl.ChapterTitle,
            cl.ChapterDescription,
            c.DisplayOrder,
            c.[Level],
            c.IsWarning,
            c.IsVisible,
            c.ParentChapterId,
            c.CertificationId,
            -- Get the requirements assigned to this chapter
            (
                SELECT 
                    r.Id,
                    rl.Headlines,
                    rl.Description,
                    r.RequirementTypeId,
                    rt.Name AS RequirementType,
                    rc.DispalyOrder AS DisplayOrder,
                    r.IsCommentable,
					r.IsFileUploadAble,
                    r.IsFileUploadRequired,
                    r.IsVisible,
                    r.IsActive,
                    r.AddedDate,
                    -- Filter requirements based on audit years if applicable
                    CASE 
                        WHEN @CustomerId IS NULL THEN 1
                        WHEN @Recertification IS NULL OR @Recertification = 0 THEN 1
                        WHEN @RelevantAuditYear IS NOT NULL AND r.AuditYears IS NOT NULL AND r.AuditYears <> '0' THEN
                            CASE
                                WHEN EXISTS (
                                    SELECT 1
                                    FROM STRING_SPLIT(r.AuditYears, ',')
                                    WHERE LTRIM(RTRIM(value)) = @RelevantAuditYear
                                ) THEN 1
                                ELSE 0
                            END
                        ELSE 0
                    END AS IsRelevantAuditYear,
                    -- Get the latest comment information for this requirement
                    JSON_QUERY((
						SELECT TOP 1
							ct.CustomerCommentTurn AS CustomerCommentTurn,
							ct.ReadStatus AS ReadStatus
						FROM [SBSC].[CommentThread] ct
						WHERE ct.RequirementId = r.Id
						AND ct.CustomerId = @CustomerId
						ORDER BY ct.CreatedDate DESC
						FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
					)) AS LatestCommentInfo,
                    CASE 
						WHEN @CustomerId IS NULL THEN NULL
						WHEN (cr.Id IS NULL AND r.RequirementTypeId != 5) THEN 0
						WHEN @Recertification > 0 AND NOT EXISTS (
							SELECT 1 
							FROM [SBSC].[CustomerResponse] cr_check
							WHERE cr_check.RequirementId = r.Id
							AND cr_check.CustomerId = @CustomerId
							AND cr_check.Recertification = @Recertification
						) THEN 0
						WHEN r.RequirementTypeId = 1 AND r.IsFileUploadRequired = 0
						AND EXISTS (
							SELECT 1
								FROM SBSC.CustomerResponse 
								WHERE CustomerId = @CustomerId 
								AND RequirementId = r.Id
								AND (@Recertification <= 0 OR Recertification = @Recertification)
								AND FreeTextAnswer IS NOT NULL
						) 
						THEN 1
						WHEN r.RequirementTypeId = 2 AND r.IsFileUploadRequired = 0
						AND EXISTS (
							SELECT 1 
							FROM [SBSC].[CustomerSelectedAnswers] csa
							INNER JOIN [SBSC].[RequirementAnswerOptions] rao ON csa.AnswerOptionsId = rao.Id
							WHERE csa.CustomerResponseId = cr.Id
							AND rao.RequirementTypeOptionId = 1
							AND (@Recertification <= 0 OR EXISTS (
								SELECT 1
								FROM [SBSC].[CustomerResponse] cr_inner
								WHERE cr_inner.Id = csa.CustomerResponseId
								AND cr_inner.Recertification = @Recertification
							))
						) THEN 0
						WHEN (((r.RequirementTypeId = 2) OR (r.RequirementTypeId = 3) OR (r.RequirementTypeId = 4)) 
						AND r.IsFileUploadRequired = 0
						AND EXISTS (
							select 1
							from sbsc.[CustomerSelectedAnswers]
							INNER JOIN SBSC.CustomerResponse cres ON cres.Id = CustomerResponseId
							WHERE CustomerResponseId = cr.Id
							AND AnswerOptionsId IS NOT NULL
							AND (@Recertification <= 0 OR cres.Recertification = @Recertification
							))
						) THEN 1
						WHEN r.IsFileUploadRequired = 1 THEN
							CASE 
								WHEN EXISTS (
									SELECT 1 
									FROM [SBSC].[CustomerDocuments] cd 
									WHERE cd.CustomerResponseId = cr.Id
								) THEN 1
								ELSE 2
							END
						WHEN r.RequirementTypeId = 5
								THEN
									CASE
										WHEN (r.IsFileUploadAble = 0 AND r.IsCommentable = 0)
											THEN 1
										WHEN (r.IsFileUploadAble = 1 AND r.IsCommentable = 1
											AND (EXISTS (
												SELECT 1
													FROM SBSC.CustomerResponse 
													WHERE CustomerId = @CustomerId 
													AND RequirementId = r.Id
													AND (@Recertification <= 0 OR Recertification = @Recertification)
													AND Comment IS NOT NULL)
												OR EXISTS (
														SELECT 1 
														FROM [SBSC].[CustomerDocuments] cd 
														WHERE cd.CustomerResponseId = cr.Id
													)))
													THEN 1
										WHEN (r.IsFileUploadAble = 1
											AND EXISTS (
														SELECT 1 
														FROM [SBSC].[CustomerDocuments] cd 
														WHERE cd.CustomerResponseId = cr.Id
													))
												THEN 1
										WHEN (r.IsCommentable = 1
											AND EXISTS (
												SELECT 1
													FROM SBSC.CustomerResponse 
													WHERE CustomerId = @CustomerId 
													AND RequirementId = r.Id
													AND (@Recertification <= 0 OR Recertification = @Recertification)
													AND Comment IS NOT NULL))
												THEN 1
										ELSE 0
									END
						ELSE 0
							
					END AS isAnswered,
                    (
                        SELECT 
                            rao.Id,
                            rao.DisplayOrder,
                            rao.RequirementTypeOptionId AS Answer,
                            rao.IsCritical,
                            ISNULL(
                                CASE 
                                    WHEN rao.RequirementTypeOptionId IS NOT NULL THEN 
                                        (
                                            SELECT ISNULL(rtol.AnswerOptions, '')
                                            FROM [SBSC].[RequirementTypeOptionLanguage] rtol 
                                            WHERE rtol.RequirementTypeOptionId = rao.RequirementTypeOptionId 
                                              AND rtol.LangId = @LangId
                                        )
                                    ELSE raol.Answer 
                                END, ''
                            ) AS AnswerText,
                            raol.HelpText
                        FROM [SBSC].[RequirementAnswerOptions] rao
                        LEFT JOIN [SBSC].[RequirementAnswerOptionsLanguage] raol 
                          ON raol.AnswerOptionId = rao.Id AND raol.LangId = @LangId
                        WHERE rao.RequirementId = r.Id
                        ORDER BY rao.DisplayOrder
                        FOR JSON PATH
                    ) AS AnswerOptionsJson,
                    (
                        SELECT 
                            rc_inner.Id,
                            rc_inner.ReferenceNo,
                            rc_inner.ChapterId,
                            ch_inner.Title AS ChapterTitle,
                            ch_inner.CertificationId,
                            cert_inner.CertificateCode,
                            cert_inner.Validity,
                            CASE 
								WHEN EXISTS (
									SELECT 1
									FROM SBSC.RequirementAnswerOptions 
									WHERE IsCritical = 1 
									AND Id IN (
										SELECT AnswerOptionsId 
										FROM SBSC.CustomerSelectedAnswers 
										WHERE CustomerResponseId IN (
											SELECT TOP 1 Id 
											FROM SBSC.CustomerResponse 
											WHERE RequirementId = r.Id 
											AND CustomerId = @CustomerId
											ORDER BY Id DESC
										)
									)
								) 
								THEN CAST(1 AS BIT)
								ELSE CAST(0 AS BIT)
							END AS IsWarning
                        FROM [SBSC].[RequirementChapters] rc_inner
                        INNER JOIN [SBSC].[Chapter] ch_inner 
                          ON rc_inner.ChapterId = ch_inner.Id
                        INNER JOIN [SBSC].[Certification] cert_inner 
                          ON ch_inner.CertificationId = cert_inner.Id
                        WHERE rc_inner.RequirementId = r.Id
                        ORDER BY rc_inner.DispalyOrder
                        FOR JSON PATH
                    ) AS RequirementChaptersJson,
                    ISNULL((
                        SELECT TOP 1
                            ar.Id,
                            ar.ResponseStatusId,
                            ar.IsApproved,
                            ar.Response,
                            ar.ResponseDate,
                            ar.Comment,
                            ar.CustomerBasicDocResponse,
                            (
                                SELECT TOP 1 an.Note 
                                FROM SBSC.AuditorNotes an 
                                WHERE an.AuditorCustomerResponseId = ar.Id 
                                ORDER BY an.CreatedDate DESC
                            ) as Note,
							ar.ApprovalDate
                        FROM [SBSC].[AuditorCustomerResponses] ar
                        WHERE ar.CustomerResponseId = cr.Id
                        ORDER BY ar.ResponseDate DESC
                        FOR JSON PATH
                    ), '[]') AS RequirementAuditorResponse
                FROM [SBSC].[Requirement] r
                INNER JOIN [SBSC].[RequirementChapters] rc 
                  ON rc.RequirementId = r.Id
                INNER JOIN [SBSC].[RequirementType] rt 
                  ON rt.Id = r.RequirementTypeId
                LEFT JOIN (
                    SELECT 
                        cr_inner.RequirementId,
						cr_inner.Recertification,
                        cr_inner.Id
                    FROM (
                        SELECT 
                            RequirementId,
							Recertification,
                            Id,
                            ROW_NUMBER() OVER (PARTITION BY RequirementId ORDER BY Id DESC) AS rn
                        FROM [SBSC].[CustomerResponse]
                        WHERE CustomerId = @CustomerId
                    ) AS cr_inner
                    WHERE cr_inner.rn = 1
                ) AS cr ON cr.RequirementId = r.Id
                LEFT JOIN [SBSC].[RequirementLanguage] rl 
                  ON rl.RequirementId = r.Id AND rl.LangId = @LangId
                WHERE rc.ChapterId = c.Id
				-- Apply deviation status filter if needed
				AND (
					@CustomerId IS NULL 
					OR @DeviationStatus = 0 
					OR EXISTS (
						SELECT 1
						FROM [SBSC].[AuditorCustomerResponses] ar
						WHERE ar.CustomerResponseId = cr.Id  -- Use outer "cr" from LEFT JOIN
						  AND ar.ResponseStatusId IN (1, 2, 3)  -- Explicit statuses
						  AND (
							  -- Use @Recertification if provided, else ignore
							  @Recertification IS NULL 
							  OR cr.Recertification = @Recertification
						  )
					)
				)
                -- Apply deviation status filter if needed
      --          AND (
      --              @CustomerId IS NULL 
      --              OR @DeviationStatus = 0 
      --              OR EXISTS (
      --                  SELECT 1
      --                  FROM [SBSC].[AuditorCustomerResponses] ar
						--INNER JOIN SBSC.CustomerResponse cr ON cr.Id = ar.CustomerResponseId
      --                  WHERE ar.CustomerResponseId = cr.Id
						--AND ar.ResponseStatusId < 4
						-- AND cr.CustomerId = @CustomerId
						--  AND cr.RequirementId IN (
						--		SELECT RequirementId 
						--		FROM SBSC.RequirementChapters
						--		WHERE ChapterId IN (
						--			SELECT Id 
						--			FROM SBSC.Chapter 
						--			WHERE CertificationId = @CertificationId
						--		)
						--	)
						--  AND cr.Recertification = (
						--		SELECT Recertification 
						--		FROM SBSC.Customer_Certifications 
						--		WHERE CustomerId = @CustomerId AND CertificateId = @CertificationId
						--	)
      --              )
      --          )
                -- Improved filter for audit years based on recertification
				AND (
					@CustomerId IS NULL -- No filtering if not for a specific customer
					OR @Recertification IS NULL -- No filtering if recertification is null
					OR @Recertification = 0 -- No filtering if recertification is 0
					OR (
						@Recertification > 0
						AND @RelevantAuditYear IS NOT NULL
						AND (
							-- Requirement's audit years contain the relevant year for this recertification
							EXISTS (
								SELECT 1
								FROM STRING_SPLIT(r.AuditYears, ',')
								WHERE LTRIM(RTRIM(value)) = @RelevantAuditYear
							)
						)
					)
					-- Handle requirements with '0' as a special case: apply only to the first year
					OR (
						r.AuditYears = '0'
						AND @Recertification = 0 -- Apply only if this is the first audit year
					)
				)

                ORDER BY rc.DispalyOrder
                FOR JSON PATH
            ) AS RequirementsJson,
            -- Recursive call: retrieve child sections (if any)
            JSON_QUERY(
                SBSC.fn_GetChapterTreeRequirement(
                    c.Id, 
                    @LangId, 
                    @CertificationId,       -- Not needed for recursive calls
                    @CustomerId,
                    @DeviationStatus,  -- Pass the deviation status to recursive calls
					@Recertification
                )
            ) AS Sections
        FROM SBSC.Chapter AS c
        LEFT JOIN SBSC.ChapterLanguage AS cl
          ON cl.ChapterId = c.Id AND cl.LanguageId = @LangId
        WHERE 
            (
              (@ParentChapterId IS NULL AND c.ParentChapterId IS NULL)
              OR c.ParentChapterId = @ParentChapterId
            )
            AND 
            (
              (@CertificationId IS NULL)
              OR c.CertificationId = @CertificationId
            )
        ORDER BY c.DisplayOrder
        FOR JSON PATH
    );

    RETURN ISNULL(@json, '[]');
END;
GO