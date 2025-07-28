CREATE TABLE [HangFire].[State] (
  [Id] [bigint] IDENTITY,
  [JobId] [bigint] NOT NULL,
  [Name] [nvarchar](20) NOT NULL,
  [Reason] [nvarchar](100) NULL,
  [CreatedAt] [datetime] NOT NULL,
  [Data] [nvarchar](max) NULL,
  CONSTRAINT [PK_HangFire_State] PRIMARY KEY CLUSTERED ([JobId], [Id])
)
GO

CREATE INDEX [IX_HangFire_State_CreatedAt]
  ON [HangFire].[State] ([CreatedAt])
GO

ALTER TABLE [HangFire].[State]
  ADD CONSTRAINT [FK_HangFire_State_Job] FOREIGN KEY ([JobId]) REFERENCES [HangFire].[Job] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE
GO