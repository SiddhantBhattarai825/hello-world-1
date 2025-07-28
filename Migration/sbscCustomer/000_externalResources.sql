CREATE MASTER KEY ENCRYPTION BY PASSWORD = '6wR5ggaidP24bhXw';

CREATE DATABASE SCOPED CREDENTIAL sbscDevCredential
WITH
    IDENTITY = 'certcore', 
    SECRET = 'rgOdLwxOVEQ86tuJ'; 

CREATE EXTERNAL DATA SOURCE SbscAuditDataSource
WITH (
    TYPE = RDBMS,
    LOCATION = 'sbscnewdev.database.windows.net', 
    DATABASE_NAME = 'sbscAuditTest-dev',
    CREDENTIAL = sbscDevCredential
);