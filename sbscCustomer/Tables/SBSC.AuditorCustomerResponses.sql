CREATE TABLE [SBSC].[AuditorCustomerResponses] (
  [Id] [int] NOT NULL,
  [CustomerResponseId] [int] NULL,
  [AuditorId] [int] NULL,
  [Response] [nvarchar](max) NULL,
  [ResponseDate] [datetime] NOT NULL,
  [ResponseStatusId] [int] NOT NULL,
  [IsApproved] [bit] NOT NULL,
  [Comment] [nvarchar](max) NULL,
  [CustomerBasicDocResponse] [int] NULL,
  [ApprovalDate] [datetime] NULL,
  [CreatedDate] [datetime] NULL,
  [ModifiedDate] [datetime] NULL
)
GO