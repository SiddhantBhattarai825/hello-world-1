CREATE TABLE [SBSC].[EmailTemplate] (
  [Id] [int] IDENTITY,
  [Title] [nvarchar](100) NOT NULL,
  [Description] [nvarchar](500) NOT NULL,
  [EmailCode] [nvarchar](500) NOT NULL,
  [IsActive] [bit] NOT NULL,
  [Tags] [nvarchar](500) NULL,
  [AddedDate] [datetime] NOT NULL,
  [AddedBy] [int] NOT NULL,
  [ExpiryTime] [float] NULL,
  CONSTRAINT [PK_EmailTemplate] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_EmailTemplate_EmailCode] UNIQUE ([EmailCode])
)
GO

ALTER TABLE [SBSC].[EmailTemplate] WITH NOCHECK
  ADD CONSTRAINT [FK_EmailTemplate_AdminUser] FOREIGN KEY ([AddedBy]) REFERENCES [SBSC].[AdminUser] ([Id])
GO