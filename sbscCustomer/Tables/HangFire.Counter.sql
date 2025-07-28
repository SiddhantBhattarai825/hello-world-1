CREATE TABLE [HangFire].[Counter] (
  [Key] [nvarchar](100) NOT NULL,
  [Value] [int] NOT NULL,
  [ExpireAt] [datetime] NULL,
  [Id] [bigint] IDENTITY,
  CONSTRAINT [PK_HangFire_Counter] PRIMARY KEY CLUSTERED ([Key], [Id])
)
GO