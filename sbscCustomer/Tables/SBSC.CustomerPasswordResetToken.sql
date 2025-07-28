CREATE TABLE [SBSC].[CustomerPasswordResetToken] (
  [Id] [int] IDENTITY,
  [Email] [nvarchar](255) NOT NULL,
  [Token] [nvarchar](500) NOT NULL,
  [IsUsed] [bit] NOT NULL DEFAULT (0),
  [ValidityDate] [datetime] NOT NULL,
  [TokenType] [nvarchar](50) NOT NULL CONSTRAINT [DF_PasswordResetTokens_TokenType] DEFAULT ('PasswordReset'),
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CustomerPasswordResetToken] WITH NOCHECK
  ADD CONSTRAINT [CK_PasswordResetTokens_TokenType] CHECK ([TokenType]='MfaActivation' OR [TokenType]='PasswordReset')
GO