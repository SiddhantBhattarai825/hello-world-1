SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE VIEW [SBSC].[vw_RequirementDetails]
AS
SELECT        r.Id AS RequirementId, r.DisplayOrder, rt.Name AS RequirementType, r.IsCommentable, r.IsFileUploadRequired, r.IsVisible, r.IsActive, r.AddedDate, rl.Headlines, rl.Description, l.Id AS LangId, l.LanguageName, 
                         r.RequirementTypeId, rl.Notes, r.AuditYears, r.IsFileUploadAble, r.Version, r.ParentRequirementId, r.IsChanged, rc1.ChapterId, CASE WHEN EXISTS
                             (SELECT        1
                               FROM            SBSC.RequirementChapters rc JOIN
                                                         SBSC.Chapter ch ON rc.ChapterId = ch.Id JOIN
                                                         SBSC.CertificationLanguage cl ON ch.CertificationId = cl.CertificationId
                               WHERE        rc.RequirementId = r.Id AND cl.Published = 1 AND cl.LangId = rl.LangId AND rc.ChapterId = rc1.ChapterId) THEN 1 
							   WHEN EXISTS
                             (SELECT        1
                               FROM            SBSC.RequirementChapters rc JOIN
                                                         SBSC.Chapter ch ON rc.ChapterId = ch.Id JOIN
                                                         SBSC.CertificationLanguage cl ON ch.CertificationId = cl.CertificationId
                               WHERE        rc.RequirementId = r.Id AND cl.Published = 2 AND cl.LangId = rl.LangId AND rc.ChapterId = rc1.ChapterId) THEN 2
							   ELSE 0 END AS certificationPublished
FROM            SBSC.Requirement AS r LEFT OUTER JOIN
                         SBSC.RequirementLanguage AS rl ON r.Id = rl.RequirementId LEFT OUTER JOIN
						 SBSC.RequirementChapters rc1 ON rc1.RequirementId = r.Id LEFT OUTER JOIN
                         SBSC.Languages AS l ON rl.LangId = l.Id LEFT OUTER JOIN
                         SBSC.RequirementType AS rt ON r.RequirementTypeId = rt.Id
GO