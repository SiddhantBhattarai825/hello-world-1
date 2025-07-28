SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SBSC].[sp_Dashboard]
    @Action NVARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    CREATE TABLE #RemoteCustomers (
        Id INT,
        CompanyName NVARCHAR(255),
        Email NVARCHAR(255),
        CustomerName NVARCHAR(255),
        CaseId BIGINT,
        CaseNumber NVARCHAR(MAX),
        OrgNo NVARCHAR(50),
        VATNo NVARCHAR(MAX),
        ContactNumber NVARCHAR(100),
		[ContactCellPhone] NVARCHAR(100),
        DefaultAuditor INT NULL,
        CreatedDate DATETIME,
        IsAnonymizes BIT,                    -- Added column
        Certifications NVARCHAR(MAX),
        AssignedAuditors NVARCHAR(MAX),
        CertificateNumbers NVARCHAR(MAX),
        CustomerCertificationIds NVARCHAR(MAX),
        MfaStatus INT,
        IsActive BIT,
		ANSWERS NVARCHAR(MAX),
        IsPasswordChanged BIT,
        PasswordChangedDate DATETIME,
		DefaultLangId INT,
		ChildUsers NVARCHAR(MAX),
        [$ShardName] NVARCHAR(MAX)
    );

    -- Fetch data from remote database
    BEGIN
        INSERT INTO #RemoteCustomers
        EXEC sp_execute_remote
            @data_source_name = N'SbscCustomerDataSource',
            @stmt = N'
                EXEC [SBSC].[sp_Customers_CRUD]
                    @Action = @Action,
                    @PageSize = @PageSize,
                    @SortColumn = @SortColumn,
                    @SortDirection = @SortDirection',
            @params = N'@Action NVARCHAR(10),
                        @PageSize INT,
                        @SortColumn NVARCHAR(50),
                        @SortDirection NVARCHAR(4)',
            @Action = N'LIST',
            @PageSize = 10,
            @SortColumn = N'Id',
            @SortDirection = N'DESC';
    END

    -- Convert customer data into JSON format
    DECLARE @CustomersJson NVARCHAR(MAX);
    SELECT @CustomersJson = 
    (SELECT Id, 
            CompanyName, 
            CustomerName, 
            OrgNo, 
            Email, 
            CreatedDate, 
            DefaultAuditor, 
            CaseId,
            CaseNumber,          -- Added field
            VATNo,              -- Added field
            ContactNumber,      -- Added field
			ContactCellPhone,
            IsAnonymizes,       -- Added field
            MfaStatus, 
            IsActive, 
            IsPasswordChanged, 
            PasswordChangedDate, 
            Certifications, 
            AssignedAuditors, 
            CertificateNumbers, 
            CustomerCertificationIds,
			Answers,
			ChildUsers,
            [$ShardName]        -- Added field
     FROM #RemoteCustomers
	 ORDER BY Id DESC
     FOR JSON PATH);

    -- Drop the temporary table
    DROP TABLE #RemoteCustomers;

    -- Combine counts and customer JSON into the result
    SELECT 
        (SELECT COUNT(*) FROM SBSC.Certification WHERE IsActive = 1) AS TotalCertifications,
        (SELECT COUNT(*) FROM SBSC.Customers WHERE IsAnonymizes = 0) AS TotalCustomers,
        (SELECT COUNT(*) FROM SBSC.Auditor) AS TotalAuditors,
        @CustomersJson AS CustomersJson;
END;

GO