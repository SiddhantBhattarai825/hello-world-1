CREATE MASTER KEY ENCRYPTION BY PASSWORD = '6wR5ggaidP24bhXw';

CREATE DATABASE SCOPED CREDENTIAL sbscDevCredential
WITH
    IDENTITY = 'certcore', 
    SECRET = 'rgOdLwxOVEQ86tuJ'; 

CREATE EXTERNAL DATA SOURCE SbscCustomerDataSource
WITH (
    TYPE = RDBMS,
    LOCATION = 'sbscnewdev.database.windows.net', 
    DATABASE_NAME = 'sbscCustomerTest-dev',
    CREDENTIAL = sbscDevCredential
);


