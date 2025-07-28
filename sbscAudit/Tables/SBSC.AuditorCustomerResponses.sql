CREATE TABLE [SBSC].[AuditorCustomerResponses] (
  [Id] [int] IDENTITY,
  [CustomerResponseId] [int] NULL,
  [AuditorId] [int] NOT NULL,
  [Response] [nvarchar](max) NULL,
  [ResponseDate] [datetime] NOT NULL CONSTRAINT [DF__AuditorCu__Respo__46B27FE2] DEFAULT (getutcdate()),
  [ResponseStatusId] [int] NOT NULL,
  [IsApproved] [bit] NOT NULL CONSTRAINT [DF_AuditorCustomerResponses_IsApproved] DEFAULT (0),
  [Comment] [nvarchar](max) NULL,
  [CustomerBasicDocResponse] [int] NULL,
  [ApprovalDate] [datetime] NULL,
  [CreatedDate] [datetime] NULL,
  [ModifiedDate] [datetime] NULL,
  CONSTRAINT [PK_AuditorCustomerResponses] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [CK_AuditorId_NotNull] CHECK ([AuditorId] IS NOT NULL)
)
GO

CREATE INDEX [IX_AuditorCustomerResponses_CustomerResponseId_Approved]
  ON [SBSC].[AuditorCustomerResponses] ([CustomerResponseId], [IsApproved])
GO

ALTER TABLE [SBSC].[AuditorCustomerResponses]
  ADD CONSTRAINT [FK_AuditorCustomerResponses_ResponseStatusId] FOREIGN KEY ([ResponseStatusId]) REFERENCES [SBSC].[AuditorResponseStatuses] ([Id])
GO