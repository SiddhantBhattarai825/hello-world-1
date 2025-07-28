CREATE TABLE [SBSC].[Requirement] (
  [Id] [int] IDENTITY,
  [RequirementTypeId] [int] NOT NULL,
  [IsCommentable] [bit] NOT NULL,
  [IsFileUploadRequired] [bit] NOT NULL CONSTRAINT [DF_IsFileUploadRequired] DEFAULT (0),
  [DisplayOrder] [int] NULL,
  [IsVisible] [bit] NULL,
  [IsActive] [int] NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  [AuditYears] [nvarchar](50) NULL,
  [IsFileUploadAble] [bit] NOT NULL CONSTRAINT [DF_IsFileUploadAble] DEFAULT (1),
  [ParentRequirementId] [int] NULL,
  [Version] [decimal](6, 2) NULL,
  [IsChanged] [bit] NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__Requirem__3214EC07E7991D0F] PRIMARY KEY CLUSTERED ([Id])
)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[TR_Requirement_FileUpload_Consistency]
ON [SBSC].[Requirement]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if IsFileUploadAble column was updated to false
    IF UPDATE(IsFileUploadAble)
    BEGIN
        -- Update IsFileUploadRequired to false for rows where IsFileUploadAble was changed to false
        UPDATE R
        SET R.IsFileUploadRequired = 0
        FROM [SBSC].[Requirement] R
        INNER JOIN inserted I ON R.Id = I.Id
        WHERE I.IsFileUploadAble = 0
        AND R.IsFileUploadRequired = 1;
    END
END
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[trg_AfterDeleteRequirement]
ON [SBSC].[Requirement]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM deleted)
        BEGIN
            DECLARE @CurrentRequirementId INT;
            SELECT @CurrentRequirementId = Id FROM deleted;

            EXEC sp_execute_remote 
                @data_source_name = N'SbscCustomerDataSource',
                @stmt = N'EXEC [SBSC].[sp_DeleteRemoteAuditData_DML] 
						@Action = @Action,
						@RequirementId = @RequirementId',
                @params = N'@Action NVARCHAR(100), @RequirementId INT',
                @Action = 'DELETE_RESPONSE',
                @RequirementId = @CurrentRequirementId;
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

ALTER TABLE [SBSC].[Requirement]
  ADD CONSTRAINT [FK_Requirement_ParentRequirement] FOREIGN KEY ([ParentRequirementId]) REFERENCES [SBSC].[Requirement] ([Id])
GO

ALTER TABLE [SBSC].[Requirement] WITH NOCHECK
  ADD CONSTRAINT [FK_Requirement_RequirementType] FOREIGN KEY ([RequirementTypeId]) REFERENCES [SBSC].[RequirementType] ([Id])
GO