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


CREATE EXTERNAL TABLE [SBSC].[Customers] (
    [Id] INT NOT NULL,
    [CompanyName] NVARCHAR (200) NOT NULL,
    [CustomerName] NVARCHAR (500) NOT NULL,
    [CaseId] BIGINT NOT NULL,
    [OrgNo] NVARCHAR (50) NOT NULL,
    [CreatedDate] DATETIME NOT NULL,
    [DefaultAuditor] INT NULL,
    [UserType] VARCHAR (10) NULL,
    [RelatedCustomerId] INT NULL,
    [CaseNumber] NVARCHAR (MAX) NULL,
    [VATNo] NVARCHAR (MAX) NULL,
    [ContactNumber] NVARCHAR (100) NULL,
    [ContactCellPhone] NVARCHAR (100) NULL,
    [IsAnonymizes] BIT NOT NULL
)
    WITH (
    DATA_SOURCE = [SbscCustomerDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'Customers'
    );

CREATE EXTERNAL TABLE [SBSC].[CustomerSelectedAnswers] (
    [ID] INT NOT NULL,
    [CustomerResponseId] INT NULL,
    [AnswerOptionsId] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscCustomerDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'CustomerSelectedAnswers'
    );


CREATE EXTERNAL TABLE [SBSC].[DocumentCommentThread] (
    [Id] INT NOT NULL,
    [DocumentId] INT NULL,
    [CustomerId] INT NULL,
    [AuditorId] INT NULL,
    [ParentCommentId] INT NULL,
    [Comment] NVARCHAR (MAX) NULL,
    [CreatedDate] DATETIME NULL,
    [ModifiedDate] DATETIME NULL,
    [CustomerCommentTurn] BIT NULL,
    [ReadStatus] BIT NULL,
    [Recertification] INT NULL,
    [IsApproved] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscCustomerDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'DocumentCommentThread'
    );
