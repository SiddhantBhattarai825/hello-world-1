-- =====================================================================
-- External Tables Migration Script for sbscCustomer Database
-- This script creates external tables with proper error handling
-- =====================================================================

PRINT 'Starting external table creation for sbscCustomer database...';
PRINT 'Script execution time: ' + CONVERT(VARCHAR, GETDATE(), 120);

-- External Table: Auditor
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Auditor' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Auditor] (
            [Id] INT NOT NULL,
            [Name] NVARCHAR (500) NOT NULL,
            [IsSBSCAuditor] BIT NOT NULL,
            [Status] BIT NOT NULL,
            [UserType] VARCHAR (10) NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Auditor'
        );
        PRINT '✓ External table SBSC.Auditor created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Auditor: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Auditor already exists.';

-- External Table: Auditor_Certifications
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Auditor_Certifications' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Auditor_Certifications] (
            [AuditorId] INT NOT NULL,
            [CertificationId] INT NOT NULL,
            [IsDefault] BIT NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Auditor_Certifications'
        );
        PRINT '✓ External table SBSC.Auditor_Certifications created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Auditor_Certifications: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Auditor_Certifications already exists.';

-- External Table: AuditorCredentials
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'AuditorCredentials' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[AuditorCredentials] (
            [ID] INT NOT NULL,
            [Email] NVARCHAR (100) NOT NULL,
            [IsActive] BIT NULL,
            [AuditorId] INT NULL,
            [DefaultLangId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'AuditorCredentials'
        );
        PRINT '✓ External table SBSC.AuditorCredentials created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.AuditorCredentials: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.AuditorCredentials already exists.';

-- External Table: AuditorCustomerResponses
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'AuditorCustomerResponses' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[AuditorCustomerResponses] (
            [Id] INT NOT NULL,
            [CustomerResponseId] INT NULL,
            [AuditorId] INT NULL,
            [Response] NVARCHAR (MAX) NULL,
            [ResponseDate] DATETIME NOT NULL,
            [ResponseStatusId] INT NOT NULL,
            [IsApproved] BIT NOT NULL,
            [Comment] NVARCHAR (MAX) NULL,
            [CustomerBasicDocResponse] INT NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'AuditorCustomerResponses'
        );
        PRINT '✓ External table SBSC.AuditorCustomerResponses created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.AuditorCustomerResponses: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.AuditorCustomerResponses already exists.';

-- External Table: AuditorNotes
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'AuditorNotes' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[AuditorNotes] (
            [Id] INT NOT NULL,
            [RequirementId] INT NOT NULL,
            [AuditorId] INT NOT NULL,
            [Note] NVARCHAR (MAX) NULL,
            [AddedDate] DATETIME NOT NULL,
            [ModifiedDate] DATETIME NOT NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'AuditorNotes'
        );
        PRINT '✓ External table SBSC.AuditorNotes created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.AuditorNotes: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.AuditorNotes already exists.';

-- External Table: Certification
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Certification' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Certification] (
            [Id] INT NOT NULL,
            [CertificationNumber] NVARCHAR (50) NOT NULL,
            [Version] DECIMAL (5, 2) NOT NULL,
            [CategoryId] INT NOT NULL,
            [IsActiveForNewCustomer] BIT NOT NULL,
            [IsActiveForExistingCustomer] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL,
            [CertificateCode] NVARCHAR (500) NOT NULL,
            [CertificationValidYears] INT NULL,
            [LanguageId] INT NULL,
            [Status] BIT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Certification'
        );
        PRINT '✓ External table SBSC.Certification created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Certification: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Certification already exists.';

-- External Table: CertificationCategory
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CertificationCategory' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CertificationCategory] (
            [Id] INT NOT NULL,
            [CategoryName] NVARCHAR (500) NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL,
            [SortOrder] INT NULL,
            [LanguageId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CertificationCategory'
        );
        PRINT '✓ External table SBSC.CertificationCategory created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CertificationCategory: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CertificationCategory already exists.';

-- External Table: CertificationCategoryLanguage
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CertificationCategoryLanguage' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CertificationCategoryLanguage] (
            [Id] INT NOT NULL,
            [CertificationCategoryId] INT NOT NULL,
            [LanguageId] INT NOT NULL,
            [CategoryName] NVARCHAR (500) NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CertificationCategoryLanguage'
        );
        PRINT '✓ External table SBSC.CertificationCategoryLanguage created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CertificationCategoryLanguage: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CertificationCategoryLanguage already exists.';

-- External Table: CertificationLanguage
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CertificationLanguage' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CertificationLanguage] (
            [Id] INT NOT NULL,
            [CertificationId] INT NOT NULL,
            [LanguageId] INT NOT NULL,
            [CertificationNumber] NVARCHAR (50) NOT NULL,
            [CertificateCode] NVARCHAR (500) NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CertificationLanguage'
        );
        PRINT '✓ External table SBSC.CertificationLanguage created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CertificationLanguage: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CertificationLanguage already exists.';

-- External Table: Chapter
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Chapter' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Chapter] (
            [Id] INT NOT NULL,
            [ChapterName] NVARCHAR (500) NOT NULL,
            [ChapterNumber] NVARCHAR (50) NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL,
            [DisplayOrder] INT NULL,
            [LanguageId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Chapter'
        );
        PRINT '✓ External table SBSC.Chapter created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Chapter: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Chapter already exists.';

-- External Table: ChapterLanguage
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ChapterLanguage' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[ChapterLanguage] (
            [Id] INT NOT NULL,
            [ChapterId] INT NOT NULL,
            [LanguageId] INT NOT NULL,
            [ChapterName] NVARCHAR (500) NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'ChapterLanguage'
        );
        PRINT '✓ External table SBSC.ChapterLanguage created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.ChapterLanguage: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.ChapterLanguage already exists.';

-- External Table: Documents
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Documents' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Documents] (
            [Id] INT NOT NULL,
            [DocumentName] NVARCHAR (500) NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL,
            [DocumentType] INT NOT NULL,
            [DisplayOrder] INT NULL,
            [LanguageId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Documents'
        );
        PRINT '✓ External table SBSC.Documents created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Documents: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Documents already exists.';

-- External Table: DocumentsCertifications
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'DocumentsCertifications' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[DocumentsCertifications] (
            [DocumentId] INT NOT NULL,
            [CertificationId] INT NOT NULL,
            [IsActive] BIT NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'DocumentsCertifications'
        );
        PRINT '✓ External table SBSC.DocumentsCertifications created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.DocumentsCertifications: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.DocumentsCertifications already exists.';

-- External Table: Languages
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Languages' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Languages] (
            [Id] INT NOT NULL,
            [LanguageName] NVARCHAR (500) NOT NULL,
            [LanguageCode] NVARCHAR (10) NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Languages'
        );
        PRINT '✓ External table SBSC.Languages created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Languages: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Languages already exists.';

-- External Table: ReportCustomerCertifications
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'ReportCustomerCertifications' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[ReportCustomerCertifications] (
            [ReportBlockId] INT NOT NULL,
            [CustomerCertificationId] INT NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'ReportCustomerCertifications'
        );
        PRINT '✓ External table SBSC.ReportCustomerCertifications created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.ReportCustomerCertifications: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.ReportCustomerCertifications already exists.';

-- External Table: Requirement
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Requirement' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Requirement] (
            [Id] INT NOT NULL,
            [RequirementNumber] NVARCHAR (50) NOT NULL,
            [RequirementName] NVARCHAR (1000) NOT NULL,
            [RequirementDescription] NVARCHAR (MAX) NULL,
            [RequirementTypeId] INT NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL,
            [DisplayOrder] INT NULL,
            [LanguageId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Requirement'
        );
        PRINT '✓ External table SBSC.Requirement created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Requirement: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Requirement already exists.';

-- External Table: RequirementAnswerOptions
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'RequirementAnswerOptions' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[RequirementAnswerOptions] (
            [Id] INT NOT NULL,
            [RequirementId] INT NOT NULL,
            [OptionText] NVARCHAR (500) NOT NULL,
            [IsActive] BIT NOT NULL,
            [DisplayOrder] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'RequirementAnswerOptions'
        );
        PRINT '✓ External table SBSC.RequirementAnswerOptions created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.RequirementAnswerOptions: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.RequirementAnswerOptions already exists.';

-- External Table: RequirementChapters
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'RequirementChapters' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[RequirementChapters] (
            [RequirementId] INT NOT NULL,
            [ChapterId] INT NOT NULL,
            [IsActive] BIT NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'RequirementChapters'
        );
        PRINT '✓ External table SBSC.RequirementChapters created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.RequirementChapters: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.RequirementChapters already exists.';

-- External Table: RequirementLanguage
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'RequirementLanguage' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[RequirementLanguage] (
            [Id] INT NOT NULL,
            [RequirementId] INT NOT NULL,
            [LanguageId] INT NOT NULL,
            [RequirementName] NVARCHAR (1000) NOT NULL,
            [RequirementDescription] NVARCHAR (MAX) NULL
        )
        WITH (
            DATA_SOURCE = [SbscAuditDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'RequirementLanguage'
        );
        PRINT '✓ External table SBSC.RequirementLanguage created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.RequirementLanguage: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.RequirementLanguage already exists.';

PRINT 'External table creation process completed for sbscCustomer database.';
PRINT 'Script completion time: ' + CONVERT(VARCHAR, GETDATE(), 120); 