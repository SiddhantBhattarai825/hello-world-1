CREATE TABLE [SBSC].[AuditorNotes] (
  [Id] [int] IDENTITY,
  [AuditorCustomerResponseId] [int] NULL,
  [AuditorId] [int] NOT NULL,
  [Note] [nvarchar](max) NOT NULL,
  [CreatedDate] [datetime] NOT NULL CONSTRAINT [DF__AuditorNo__Creat__47A6A41B] DEFAULT (getutcdate()),
  [CustomerResponseId] [int] NULL,
  CONSTRAINT [PK_AuditorNotes] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AuditorNotes]
  ADD CONSTRAINT [FK_AuditorNotes_Auditors] FOREIGN KEY ([AuditorId]) REFERENCES [SBSC].[Auditor] ([Id])
GO