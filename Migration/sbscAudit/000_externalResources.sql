CREATE MASTER KEY ENCRYPTION BY PASSWORD = '123456789012345';

CREATE DATABASE SCOPED CREDENTIAL sbscDevCredential
WITH
    IDENTITY = 'certcore', 
    SECRET = '123456789012345'; 

CREATE EXTERNAL DATA SOURCE SbscCustomerDataSource
WITH (
    TYPE = RDBMS,
    LOCATION = 'sbscnewdev.database.windows.net', 
    DATABASE_NAME = 'sbscCustomerTest-dev',
    CREDENTIAL = sbscDevCredential
);
