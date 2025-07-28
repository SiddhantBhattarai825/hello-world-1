CREATE TABLE [SBSC].[CustomerResponse] (
  [Id] [int] NOT NULL,
  [RequirementId] [int] NOT NULL,
  [CustomerId] [int] NOT NULL,
  [DisplayOrder] [int] NULL,
  [FreeTextAnswer] [nvarchar](max) NULL,
  [AddedDate] [datetime] NOT NULL,
  [ModifiedDate] [datetime] NOT NULL,
  [Comment] [nvarchar](max) NULL,
  [Recertification] [int] NOT NULL,
  [CustomerCertificationDetailsId] [int] NULL
)
GO