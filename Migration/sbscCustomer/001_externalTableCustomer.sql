CREATE EXTERNAL DATA SOURCE [SbscAuditDataSource]
    WITH (
    TYPE = RDBMS,
    LOCATION = N'sbscnewdev.database.windows.net',
    DATABASE_NAME = N'sbscAudit',
    CREDENTIAL = [sbscDevCredential]
    );


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
    [ApprovalDate] DATETIME NULL,
    [CreatedDate] DATETIME NULL,
    [ModifiedDate] DATETIME NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'AuditorCustomerResponses'
    );


CREATE EXTERNAL TABLE [SBSC].[AuditorNotes] (
    [Id] INT NOT NULL,
    [AuditorCustomerResponseId] INT NULL,
    [AuditorId] INT NULL,
    [Note] NVARCHAR (MAX) NULL,
    [CreatedDate] DATETIME NOT NULL,
    [CustomerResponseId] INT NOT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'AuditorNotes'
    );


CREATE EXTERNAL TABLE [SBSC].[Certification] (
    [Id] INT NOT NULL,
    [CertificateTypeId] INT NOT NULL,
    [CertificateCode] NVARCHAR (500) NULL,
    [Validity] INT NULL,
    [IsVisible] INT NULL,
    [IsActive] INT NULL,
    [AddedDate] DATETIME NULL,
    [AddedBy] INT NULL,
    [ModifiedDate] DATETIME NULL,
    [ModifiedBy] INT NULL,
    [AuditYears] NVARCHAR (255) NULL,
    [Published] INT NOT NULL,
    [Version] DECIMAL (5, 2) NULL,
    [IsAuditorInitiated] SMALLINT NULL,
    [ParentCertificationId] INT NULL,
    [IsDeleted] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'Certification'
    );


CREATE EXTERNAL TABLE [SBSC].[CertificationCategory] (
    [Id] INT NOT NULL,
    [Title] NVARCHAR (100) NULL,
    [IsVisible] INT NULL,
    [IsActive] INT NULL,
    [AddedDate] DATE NULL,
    [AddedBy] INT NULL,
    [ModifiedDate] DATE NULL,
    [ModifiedBy] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'CertificationCategory'
    );


CREATE EXTERNAL TABLE [SBSC].[CertificationCategoryLanguage] (
    [Id] INT NOT NULL,
    [CertificationcategoryId] INT NOT NULL,
    [CertificationCategoryTitle] NVARCHAR (500) NULL,
    [Languageid] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'CertificationCategoryLanguage'
    );


CREATE EXTERNAL TABLE [SBSC].[CertificationLanguage] (
    [Id] INT NOT NULL,
    [CertificationId] INT NOT NULL,
    [LangId] INT NOT NULL,
    [CertificationName] NVARCHAR (255) NULL,
    [Description] NVARCHAR (MAX) NULL,
    [Published] INT NOT NULL,
    [PublishedDate] DATETIME NULL,
    [IsDeleted] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'CertificationLanguage'
    );


CREATE EXTERNAL TABLE [SBSC].[Chapter] (
    [Id] INT NOT NULL,
    [Title] NVARCHAR (100) NOT NULL,
    [IsVisible] BIT NULL,
    [IsWarning] BIT NULL,
    [AddedDate] DATE NULL,
    [AddedBy] INT NULL,
    [ModifiedDate] DATE NULL,
    [ModifiedBy] INT NULL,
    [CertificationId] INT NOT NULL,
    [DisplayOrder] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'Chapter'
    );


CREATE EXTERNAL TABLE [SBSC].[ChapterLanguage] (
    [Id] INT NOT NULL,
    [ChapterId] INT NOT NULL,
    [ChapterTitle] NVARCHAR (MAX) NULL,
    [ChapterDescription] NVARCHAR (MAX) NULL,
    [LanguageId] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'ChapterLanguage'
    );


CREATE EXTERNAL TABLE [SBSC].[Documents] (
    [Id] INT NOT NULL,
    [DisplayOrder] INT NULL,
    [IsVisible] BIT NOT NULL,
    [AddedDate] DATETIME NOT NULL,
    [RequirementTypeId] INT NULL,
    [AddedBy] INT NULL,
    [UserRole] INT NULL,
    [ModifiedDate] DATETIME NULL,
    [ModifiedBy] INT NULL,
    [Version] DECIMAL (6, 2) NULL,
    [IsFileUploadRequired] BIT NULL,
    [IsFileUploadable] BIT NULL,
    [IsCommentable] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'Documents'
    );


CREATE EXTERNAL TABLE [SBSC].[DocumentsCertifications] (
    [Id] INT NOT NULL,
    [DocId] INT NOT NULL,
    [CertificationId] INT NOT NULL,
    [DisplayOrder] INT NULL,
    [IsWarning] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'DocumentsCertifications'
    );


CREATE EXTERNAL TABLE [SBSC].[Languages] (
    [Id] INT NOT NULL,
    [LanguageCode] NVARCHAR (10) NOT NULL,
    [LanguageName] NVARCHAR (50) NULL,
    [IsActive] BIT NULL,
    [IsDefault] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'Languages'
    );


CREATE EXTERNAL TABLE [SBSC].[ReportCustomerCertifications] (
    [Id] INT NOT NULL,
    [CustomerCertificationId] INT NULL,
    [ReportBlockId] INT NULL,
    [Details] NVARCHAR (MAX) NULL,
    [CreatedDate] DATETIME NULL,
    [AuditorId] INT NULL,
    [Recertification] INT NULL,
    [ModifiedDate] DATETIME NULL,
    [CustomerCertificationDetailsId] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'ReportCustomerCertifications'
    );


CREATE EXTERNAL TABLE [SBSC].[Requirement] (
    [Id] INT NOT NULL,
    [RequirementTypeId] INT NOT NULL,
    [IsCommentable] BIT NOT NULL,
    [IsFileUploadRequired] BIT NOT NULL,
    [IsFileUploadAble] BIT NOT NULL,
    [DisplayOrder] INT NULL,
    [IsVisible] BIT NULL,
    [IsActive] INT NULL,
    [AuditYears] NVARCHAR (50) NULL,
    [AddedDate] DATE NULL,
    [AddedBy] INT NULL,
    [ModifiedDate] DATE NULL,
    [ModifiedBy] INT NULL,
    [ParentRequirementId] INT NULL,
    [Version] DECIMAL (6, 2) NULL,
    [IsChanged] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'Requirement'
    );


CREATE EXTERNAL TABLE [SBSC].[RequirementAnswerOptions] (
    [Id] INT NOT NULL,
    [RequirementId] INT NOT NULL,
    [DisplayOrder] INT NULL,
    [Value] INT NULL,
    [RequirementTypeOptionId] INT NULL,
    [IsCritical] BIT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'RequirementAnswerOptions'
    );


CREATE EXTERNAL TABLE [SBSC].[RequirementChapters] (
    [Id] INT NOT NULL,
    [RequirementId] INT NULL,
    [ChapterId] INT NULL,
    [ReferenceNo] NVARCHAR (50) NULL,
    [IsWarning] BIT NULL,
    [DispalyOrder] INT NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'RequirementChapters'
    );


CREATE EXTERNAL TABLE [SBSC].[RequirementLanguage] (
    [ID] INT NOT NULL,
    [RequirementId] INT NOT NULL,
    [LangId] INT NOT NULL,
    [Headlines] NVARCHAR (MAX) NULL,
    [Description] NVARCHAR (MAX) NULL,
    [Notes] NVARCHAR (MAX) NULL
)
    WITH (
    DATA_SOURCE = [SbscAuditDataSource],
    SCHEMA_NAME = N'SBSC',
    OBJECT_NAME = N'RequirementLanguage'
    );


