CREATE TABLE [HangFire].[JobQueue] (
  [Id] [bigint] IDENTITY,
  [JobId] [bigint] NOT NULL,
  [Queue] [nvarchar](50) NOT NULL,
  [FetchedAt] [datetime] NULL,
  CONSTRAINT [PK_HangFire_JobQueue] PRIMARY KEY CLUSTERED ([Queue], [Id])
)
GO