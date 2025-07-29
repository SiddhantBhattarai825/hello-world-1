-- Create MASTER KEY only if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = '6wR5ggaidP24bhXw';
    PRINT 'MASTER KEY created successfully.';
END
ELSE
BEGIN
    PRINT 'MASTER KEY already exists. Skipping creation.';
END

-- Create DATABASE SCOPED CREDENTIAL only if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.database_credentials WHERE name = 'sbscDevCredential')
BEGIN
    CREATE DATABASE SCOPED CREDENTIAL sbscDevCredential
    WITH
        IDENTITY = 'certcore', 
        SECRET = 'rgOdLwxOVEQ86tuJ';
    PRINT 'DATABASE SCOPED CREDENTIAL sbscDevCredential created successfully.';
END
ELSE
BEGIN
    PRINT 'DATABASE SCOPED CREDENTIAL sbscDevCredential already exists. Skipping creation.';
END

-- Create EXTERNAL DATA SOURCE only if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.external_data_sources WHERE name = 'SbscAuditDataSource')
BEGIN
    CREATE EXTERNAL DATA SOURCE SbscAuditDataSource
    WITH (
        TYPE = RDBMS,
        LOCATION = 'sbscnewdev.database.windows.net', 
        DATABASE_NAME = 'sbscAuditTest-dev',
        CREDENTIAL = sbscDevCredential
    );
    PRINT 'EXTERNAL DATA SOURCE SbscAuditDataSource created successfully.';
END
ELSE
BEGIN
    PRINT 'EXTERNAL DATA SOURCE SbscAuditDataSource already exists. Skipping creation.';
END