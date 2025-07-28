﻿CREATE TABLE [HangFire].[Job] (
  [Id] [bigint] IDENTITY,
  [StateId] [bigint] NULL,
  [StateName] [nvarchar](20) NULL,
  [InvocationData] [nvarchar](max) NOT NULL,
  [Arguments] [nvarchar](max) NOT NULL,
  [CreatedAt] [datetime] NOT NULL,
  [ExpireAt] [datetime] NULL,
  CONSTRAINT [PK_HangFire_Job] PRIMARY KEY CLUSTERED ([Id])
)
GO

CREATE INDEX [IX_HangFire_Job_ExpireAt]
  ON [HangFire].[Job] ([ExpireAt])
  INCLUDE ([StateName])
  WHERE ([ExpireAt] IS NOT NULL)
GO

CREATE INDEX [IX_HangFire_Job_StateName]
  ON [HangFire].[Job] ([StateName])
  WHERE ([StateName] IS NOT NULL)
GO