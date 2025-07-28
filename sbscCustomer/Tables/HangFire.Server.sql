CREATE TABLE [HangFire].[Server] (
  [Id] [nvarchar](200) NOT NULL,
  [Data] [nvarchar](max) NULL,
  [LastHeartbeat] [datetime] NOT NULL,
  CONSTRAINT [PK_HangFire_Server] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_HangFire_Server_LastHeartbeat]
  ON [HangFire].[Server] ([LastHeartbeat])
GO