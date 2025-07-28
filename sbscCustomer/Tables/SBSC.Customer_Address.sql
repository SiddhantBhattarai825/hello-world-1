CREATE TABLE [SBSC].[Customer_Address] (
  [Id] [int] IDENTITY,
  [CustomerId] [int] NOT NULL,
  [PlaceName] [nvarchar](500) NULL,
  [StreetAddress] [nvarchar](500) NULL,
  [PostalCode] [nvarchar](20) NULL,
  [City] [nvarchar](100) NOT NULL,
  CONSTRAINT [PK_Customer_Address] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[Customer_Address]
  ADD CONSTRAINT [FK_Customer_Address_Customers] FOREIGN KEY ([CustomerId]) REFERENCES [SBSC].[Customers] ([Id])
GO