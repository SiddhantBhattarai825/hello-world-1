CREATE TABLE [HangFire].[List] (
  [Id] [bigint] IDENTITY,
  [Key] [nvarchar](100) NOT NULL,
  [Value] [nvarchar](max) NULL,
  [ExpireAt] [datetime] NULL,
  CONSTRAINT [PK_HangFire_List] PRIMARY KEY CLUSTERED ([Key], [Id])
)
GO

CREATE INDEX [IX_HangFire_List_ExpireAt]
  ON [HangFire].[List] ([ExpireAt])
  WHERE ([ExpireAt] IS NOT NULL)
GO