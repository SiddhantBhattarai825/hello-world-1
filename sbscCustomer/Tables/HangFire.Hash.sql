CREATE TABLE [HangFire].[Hash] (
  [Key] [nvarchar](100) NOT NULL,
  [Field] [nvarchar](100) NOT NULL,
  [Value] [nvarchar](max) NULL,
  [ExpireAt] [datetime2] NULL,
  CONSTRAINT [PK_HangFire_Hash] PRIMARY KEY CLUSTERED ([Key], [Field]) WITH (IGNORE_DUP_KEY = ON)
)
GO

CREATE INDEX [IX_HangFire_Hash_ExpireAt]
  ON [HangFire].[Hash] ([ExpireAt])
  WHERE ([ExpireAt] IS NOT NULL)
GO