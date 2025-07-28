CREATE TABLE [SBSC].[SystemAccessSettings] (
  [Id] [bigint] IDENTITY,
  [RemainingAttemptCount] [tinyint] NULL,
  [LockoutEndTime] [time] NULL,
  CONSTRAINT [PK_SystemAccessSettings] PRIMARY KEY CLUSTERED ([Id])
)
GO