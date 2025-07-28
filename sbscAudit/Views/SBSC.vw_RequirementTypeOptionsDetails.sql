SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SBSC].[vw_RequirementTypeOptionsDetails]
AS
SELECT        rto.Id, rto.IsVisible, rto.IsActive, rto.AddedDate, rto.AddedBy, rto.ModifiedDate, rto.ModifiedBy, rto.Score, rto.DisplayOrder, rtol.LangId, rtol.AnswerOptions, rtol.Description, rtol.HelpText
FROM            SBSC.RequirementTypeOption AS rto INNER JOIN
                         SBSC.RequirementTypeOptionLanguage AS rtol ON rto.Id = rtol.RequirementTypeOptionId
GO