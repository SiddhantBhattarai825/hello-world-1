SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_DownloadLinkGenerate] 
	@Action NVARCHAR(100),
	@DocumentUploads [SBSC].[CustomerDocumentsType] READONLY,
	@CustomerDocuments [SBSC].[CustomerDocumentsType] READONLY,
	@CommentDocument [SBSC].[CustomerDocumentsType] READONLY,
	@CustomerBasicDocument [SBSC].[CustomerDocumentsType] READONLY,
	@DownloadLink NVARCHAR(MAX) = NULL,
	@DocumentName NVARCHAR(MAX) = NULL
AS
BEGIN
	IF (@Action = 'GETDETAILS')
	BEGIN
		SELECT du.*, dc.CustomerId, dc.AuditorId FROM [SBSC].[DocumentUploads] du
		JOIN SBSC.DocumentCommentThread dc ON du.CommentId = dc.Id
		--WHERE DownloadLink IS NULL

		select cd.*, cr.CustomerId from SBSC.CustomerDocuments cd
		JOIN SBSC.CustomerResponse cr ON cr.Id = cd.CustomerResponseId
		--WHERE DownloadLink IS NULL   

		select cd.*, ct.CustomerId, ct.AuditorId from SBSC.CommentDocument cd
		JOIN SBSC.CommentThread ct ON ct.Id = cd.CommentId
		--WHERE DownloadLink IS NULL

		select cbd.*, cb.CustomerId from SBSC.CustomerBasicDocuments cbd
		JOIN SBSC.CustomerBasicDocResponse cb ON cb.Id = cbd.CustomerBasicDocResponseId
		--WHERE DownloadLink IS NULL

	END

	ELSE IF (@Action = 'INSERT_DOWNLOAD_LINK')
	BEGIN
		UPDATE d
		SET d.DownloadLink = du.DownloadLink
		FROM SBSC.DocumentUploads d
		JOIN @DocumentUploads du ON d.DocumentName = du.DocumentName



		UPDATE d
		SET d.DownloadLink = du.DownloadLink
		FROM SBSC.CustomerDocuments d
		JOIN @CustomerDocuments du ON d.DocumentName = du.DocumentName

		UPDATE d
		SET d.DownloadLink = du.DownloadLink
		FROM SBSC.CommentDocument d
		JOIN @CommentDocument du ON d.DocumentName = du.DocumentName

		UPDATE d
		SET d.DownloadLink = du.DownloadLink
		FROM SBSC.CustomerBasicDocuments d
		JOIN @CustomerBasicDocument du ON d.DocumentName = du.DocumentName
	END

	ELSE
	BEGIN
		RAISERROR('Incorrect @Action parameter', 16, 1);
		RETURN;
	END

END
GO