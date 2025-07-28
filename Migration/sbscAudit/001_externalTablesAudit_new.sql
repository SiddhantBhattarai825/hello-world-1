-- =====================================================================
-- External Tables Migration Script for sbscAudit Database
-- This script creates external tables with proper error handling
-- =====================================================================

PRINT 'Starting external table creation for sbscAudit database...';
PRINT 'Script execution time: ' + CONVERT(VARCHAR, GETDATE(), 120);

-- External Table: AssignmentCustomerCertification
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'AssignmentCustomerCertification' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[AssignmentCustomerCertification] (
            [ID] INT NOT NULL,
            [CustomerCertificationId] INT NULL,
            [Recertification] INT NULL,
            [AssignmentId] INT NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'AssignmentCustomerCertification'
        );
        PRINT '✓ External table SBSC.AssignmentCustomerCertification created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.AssignmentCustomerCertification: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.AssignmentCustomerCertification already exists.';

-- External Table: AssignmentOccasions
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'AssignmentOccasions' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[AssignmentOccasions] (
            [ID] INT NOT NULL,
            [FromDate] DATE NULL,
            [ToDate] DATE NULL,
            [AssignedTime] DATETIME NULL,
            [CustomerId] INT NULL,
            [Status] SMALLINT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'AssignmentOccasions'
        );
        PRINT '✓ External table SBSC.AssignmentOccasions created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.AssignmentOccasions: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.AssignmentOccasions already exists.';

-- External Table: AssignmentOccasionStatusHistory
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'AssignmentOccasionStatusHistory' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[AssignmentOccasionStatusHistory] (
            [Id] INT NULL,
            [AssignmentOccasionId] INT NULL,
            [Status] INT NULL,
            [StatusDate] DATETIME2 (7) NULL,
            [SubmittedByUserType] NVARCHAR (10) NULL,
            [SubmittedBy] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'AssignmentOccasionStatusHistory'
        );
        PRINT '✓ External table SBSC.AssignmentOccasionStatusHistory created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.AssignmentOccasionStatusHistory: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.AssignmentOccasionStatusHistory already exists.';

-- External Table: CommentThread
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CommentThread' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CommentThread] (
            [ID] INT NOT NULL,
            [RequirementId] INT NULL,
            [CustomerId] INT NULL,
            [AuditorId] INT NULL,
            [ParentCommentId] INT NULL,
            [Comment] NVARCHAR (MAX) NULL,
            [CreatedDate] DATETIME NULL,
            [ModifiedDate] DATETIME NULL,
            [CustomerCommentTurn] BIT NULL,
            [ReadStatus] BIT NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CommentThread'
        );
        PRINT '✓ External table SBSC.CommentThread created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CommentThread: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CommentThread already exists.';

-- External Table: Customer_Auditor_Departments
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Customer_Auditor_Departments' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Customer_Auditor_Departments] (
            [CustomerId] INT NOT NULL,
            [AuditorId] INT NOT NULL,
            [CertificateCode] NVARCHAR (500) NOT NULL,
            [Version] DECIMAL (5, 2) NOT NULL,
            [AddressId] INT NOT NULL,
            [DepartmentId] INT NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Customer_Auditor_Departments'
        );
        PRINT '✓ External table SBSC.Customer_Auditor_Departments created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Customer_Auditor_Departments: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Customer_Auditor_Departments already exists.';

-- External Table: Customer_Auditor_Lead
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Customer_Auditor_Lead' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Customer_Auditor_Lead] (
            [CustomerId] INT NOT NULL,
            [CertificateCode] NVARCHAR (500) NOT NULL,
            [AuditorId] INT NOT NULL,
            [Version] DECIMAL (5, 2) NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Customer_Auditor_Lead'
        );
        PRINT '✓ External table SBSC.Customer_Auditor_Lead created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Customer_Auditor_Lead: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Customer_Auditor_Lead already exists.';

-- External Table: Customer_Auditors
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Customer_Auditors' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Customer_Auditors] (
            [CustomerId] INT NOT NULL,
            [AuditorId] INT NOT NULL,
            [CertificateCode] NVARCHAR (500) NULL,
            [Version] DECIMAL (5, 2) NULL,
            [AddressId] INT NOT NULL,
            [IsLeadAuditor] BIT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Customer_Auditors'
        );
        PRINT '✓ External table SBSC.Customer_Auditors created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Customer_Auditors: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Customer_Auditors already exists.';

-- External Table: Customer_Certifications
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Customer_Certifications' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Customer_Certifications] (
            [CustomerCertificationId] INT NOT NULL,
            [CustomerId] INT NOT NULL,
            [CertificateId] INT NOT NULL,
            [CertificateNumber] NVARCHAR (50) NULL,
            [Validity] INT NULL,
            [AuditYears] NVARCHAR (255) NULL,
            [IssueDate] DATE NULL,
            [ExpiryDate] DATE NULL,
            [CreatedDate] DATETIME NOT NULL,
            [SubmissionStatus] SMALLINT NULL,
            [DeviationEndDate] DATETIME NULL,
            [Recertification] INT NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Customer_Certifications'
        );
        PRINT '✓ External table SBSC.Customer_Certifications created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Customer_Certifications: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Customer_Certifications already exists.';

-- External Table: CustomerBasicDocResponse
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CustomerBasicDocResponse' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CustomerBasicDocResponse] (
            [Id] INT NOT NULL,
            [BasicDocId] INT NOT NULL,
            [CustomerId] INT NOT NULL,
            [DisplayOrder] INT NULL,
            [FreeTextAnswer] NVARCHAR (MAX) NULL,
            [AddedDate] DATETIME NOT NULL,
            [ModifiedDate] DATETIME NOT NULL,
            [Comment] NVARCHAR (MAX) NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CustomerBasicDocResponse'
        );
        PRINT '✓ External table SBSC.CustomerBasicDocResponse created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CustomerBasicDocResponse: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CustomerBasicDocResponse already exists.';

-- External Table: CustomerCertificationDetails
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CustomerCertificationDetails' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CustomerCertificationDetails] (
            [Id] INT NOT NULL,
            [CustomerCertificationId] INT NOT NULL,
            [AddressId] INT NULL,
            [DepartmentId] INT NULL,
            [Recertification] SMALLINT NOT NULL,
            [Status] SMALLINT NULL,
            [DeviationEndDate] DATETIME NULL,
            [CreatedDate] DATETIME NOT NULL,
            [IssueDate] DATETIME NULL,
            [ExpiryDate] DATETIME NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CustomerCertificationDetails'
        );
        PRINT '✓ External table SBSC.CustomerCertificationDetails created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CustomerCertificationDetails: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CustomerCertificationDetails already exists.';

-- External Table: CustomerCredentials
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CustomerCredentials' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CustomerCredentials] (
            [Id] INT NOT NULL,
            [Email] NVARCHAR (100) NOT NULL,
            [Password] NVARCHAR (500) NOT NULL,
            [IsPasswordChanged] BIT NOT NULL,
            [PasswordChangedDate] DATETIME NOT NULL,
            [MfaStatus] INT NOT NULL,
            [DefaultLangId] INT NULL,
            [SessionId] NVARCHAR (255) NULL,
            [SessionIdValidityTime] DATETIME NULL,
            [CustomerId] INT NULL,
            [RefreshToken] NVARCHAR (255) NULL,
            [RefreshTokenValidityDate] DATETIME NULL,
            [RefreshTokenRevokedDate] DATETIME NULL,
            [IsActive] BIT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CustomerCredentials'
        );
        PRINT '✓ External table SBSC.CustomerCredentials created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CustomerCredentials: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CustomerCredentials already exists.';

-- External Table: CustomerDocuments
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CustomerDocuments' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CustomerDocuments] (
            [Id] INT NOT NULL,
            [CustomerResponseId] INT NOT NULL,
            [DocumentName] NVARCHAR (255) NOT NULL,
            [DocumentType] NVARCHAR (100) NULL,
            [AddedDate] DATETIME NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CustomerDocuments'
        );
        PRINT '✓ External table SBSC.CustomerDocuments created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CustomerDocuments: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CustomerDocuments already exists.';

-- External Table: CustomerResponse
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CustomerResponse' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CustomerResponse] (
            [Id] INT NOT NULL,
            [RequirementId] INT NOT NULL,
            [CustomerId] INT NOT NULL,
            [DisplayOrder] INT NULL,
            [FreeTextAnswer] NVARCHAR (MAX) NULL,
            [AddedDate] DATETIME NOT NULL,
            [ModifiedDate] DATETIME NOT NULL,
            [Comment] NVARCHAR (MAX) NULL,
            [Recertification] INT NOT NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CustomerResponse'
        );
        PRINT '✓ External table SBSC.CustomerResponse created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CustomerResponse: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CustomerResponse already exists.';

-- External Table: Customers
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'Customers' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[Customers] (
            [Id] INT NOT NULL,
            [CompanyName] NVARCHAR (500) NOT NULL,
            [CompanyCode] NVARCHAR (500) NOT NULL,
            [IsActive] BIT NOT NULL,
            [CreatedDate] DATETIME NOT NULL,
            [LanguageId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'Customers'
        );
        PRINT '✓ External table SBSC.Customers created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.Customers: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.Customers already exists.';

-- External Table: CustomerSelectedAnswers
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'CustomerSelectedAnswers' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[CustomerSelectedAnswers] (
            [CustomerResponseId] INT NOT NULL,
            [AnswerOptionId] INT NOT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'CustomerSelectedAnswers'
        );
        PRINT '✓ External table SBSC.CustomerSelectedAnswers created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.CustomerSelectedAnswers: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.CustomerSelectedAnswers already exists.';

-- External Table: DocumentCommentThread
IF NOT EXISTS (SELECT * FROM sys.external_tables WHERE name = 'DocumentCommentThread' AND schema_id = SCHEMA_ID('SBSC'))
BEGIN
    BEGIN TRY
        CREATE EXTERNAL TABLE [SBSC].[DocumentCommentThread] (
            [ID] INT NOT NULL,
            [DocumentId] INT NOT NULL,
            [CustomerId] INT NULL,
            [AuditorId] INT NULL,
            [ParentCommentId] INT NULL,
            [Comment] NVARCHAR (MAX) NULL,
            [CreatedDate] DATETIME NULL,
            [ModifiedDate] DATETIME NULL,
            [CustomerCommentTurn] BIT NULL,
            [ReadStatus] BIT NULL,
            [CustomerCertificationDetailsId] INT NULL
        )
        WITH (
            DATA_SOURCE = [SbscCustomerDataSource],
            SCHEMA_NAME = N'SBSC',
            OBJECT_NAME = N'DocumentCommentThread'
        );
        PRINT '✓ External table SBSC.DocumentCommentThread created successfully.';
    END TRY
    BEGIN CATCH
        PRINT '✗ Error creating SBSC.DocumentCommentThread: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT '• External table SBSC.DocumentCommentThread already exists.';

PRINT 'External table creation process completed for sbscAudit database.';
PRINT 'Script completion time: ' + CONVERT(VARCHAR, GETDATE(), 120); 