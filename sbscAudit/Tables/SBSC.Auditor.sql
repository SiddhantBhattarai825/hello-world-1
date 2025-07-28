CREATE TABLE [SBSC].[Auditor] (
  [Id] [int] IDENTITY,
  [Name] [nvarchar](500) NOT NULL,
  [IsSBSCAuditor] [bit] NOT NULL,
  [Status] [bit] NOT NULL,
  [UserType] [varchar](10) NULL DEFAULT ('Auditor'),
  [CreatedDate] [datetime] NULL DEFAULT (getutcdate()),
  CONSTRAINT [PK_Auditor] PRIMARY KEY CLUSTERED ([Id])
)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[trg_AfterDeleteAuditor]
ON [SBSC].[Auditor]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM deleted)
        BEGIN
            DECLARE @CurrentAuditorId INT;
            SELECT @CurrentAuditorId = Id FROM deleted;

            EXEC sp_execute_remote 
                @data_source_name = N'SbscCustomerDataSource',
                @stmt = N'EXEC [SBSC].[sp_DeleteRemoteAuditData_DML] 
					@Action = @Action,
					@AuditorId = @AuditorId',
                @params = N'@Action NVARCHAR(100), @AuditorId INT',
                @Action = N'DELETE_AUDITOR',
                @AuditorId = @CurrentAuditorId;
        END
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000), 
                @ErrorSeverity INT, 
                @ErrorState INT;

        SET @ErrorMessage = ERROR_MESSAGE();
        SET @ErrorSeverity = ERROR_SEVERITY();
        SET @ErrorState = ERROR_STATE();

        RAISERROR('Error in executing the remote stored procedure: %s', 16, 1, @ErrorMessage);

        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END
    END CATCH
END;
GO