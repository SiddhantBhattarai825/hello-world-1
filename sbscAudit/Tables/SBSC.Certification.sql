CREATE TABLE [SBSC].[Certification] (
  [Id] [int] IDENTITY,
  [CertificateTypeId] [int] NOT NULL,
  [CertificateCode] [nvarchar](500) NULL,
  [Validity] [int] NULL,
  [IsVisible] [int] NULL,
  [IsActive] [int] NULL,
  [AddedDate] [datetime] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [datetime] NULL,
  [ModifiedBy] [int] NULL,
  [AuditYears] [nvarchar](255) NULL CONSTRAINT [DF_Certification_AuditYears] DEFAULT ('0'),
  [Published] [int] NULL CONSTRAINT [DF__Certifica__Publi__469D7149] DEFAULT (0),
  [Version] [decimal](5, 2) NULL CONSTRAINT [DF__Certifica__Versi__7C055DC1] DEFAULT (1.0),
  [IsAuditorInitiated] [smallint] NULL,
  [ParentCertificationId] [int] NULL,
  [IsDeleted] [bit] NULL DEFAULT (0),
  CONSTRAINT [PK__Certific__3214EC0793672AA9] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_Certification_CertificateCode_Version] UNIQUE ([CertificateCode], [Version])
)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[trg_AfterDeleteCertification]
ON [SBSC].[Certification]
AFTER DELETE
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM deleted)
        BEGIN
            DECLARE @CurrentCertificationId INT;
            SELECT @CurrentCertificationId = Id FROM deleted;

            EXEC sp_execute_remote 
                @data_source_name = N'SbscCustomerDataSource',
                @stmt = N'EXEC [SBSC].[sp_DeleteRemoteAuditData_DML] 
					@Action = @Action, 
					@CertificationId = @CertificationId',
                @params = N'@Action NVARCHAR(100), @CertificationId INT',
                @Action = 'DELETE_CERTIFICATION',
                @CertificationId = @CurrentCertificationId;
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[trg_AfterUpdateCertification]
ON [SBSC].[Certification]
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

	

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM inserted) 
        BEGIN
            DECLARE @CurrentAuditYears NVARCHAR(MAX);
            DECLARE @OldAuditYears NVARCHAR(MAX);
            DECLARE @CertificationId INT;

            SELECT @CurrentAuditYears = AuditYears FROM inserted; 
            SELECT @OldAuditYears = AuditYears FROM deleted; 

            SELECT @CertificationId = Id FROM inserted;

            IF @CurrentAuditYears <> @OldAuditYears
            BEGIN
                EXEC sp_execute_remote 
                    @data_source_name = N'SbscCustomerDataSource',
                    @stmt = N'EXEC [SBSC].[sp_UpdateRemoteAuditData_DML] 
                        @Action = @Action, 
                        @CertificationId = @CertificationId, 
                        @AuditYears = @AuditYears',
                    @params = N'@Action NVARCHAR(100), @CertificationId INT, @AuditYears NVARCHAR(MAX)',
                    @Action = 'UPDATE_AUDITYEAR',
                    @CertificationId = @CertificationId,
                    @AuditYears = @CurrentAuditYears;
            END
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

ALTER TABLE [SBSC].[Certification] WITH NOCHECK
  ADD CONSTRAINT [FK_Certification_CertificateTypeId] FOREIGN KEY ([CertificateTypeId]) REFERENCES [SBSC].[CertificationCategory] ([Id])
GO

ALTER TABLE [SBSC].[Certification] WITH NOCHECK
  ADD CONSTRAINT [FK_ParentCertificationId] FOREIGN KEY ([ParentCertificationId]) REFERENCES [SBSC].[Certification] ([Id])
GO