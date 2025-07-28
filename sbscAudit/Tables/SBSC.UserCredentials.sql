CREATE TABLE [SBSC].[UserCredentials] (
  [Id] [int] IDENTITY,
  [Email] [nvarchar](255) NOT NULL,
  [Password] [nvarchar](255) NULL,
  [UserType] [nvarchar](50) NOT NULL,
  [AuditorId] [int] NULL,
  [CustomerId] [int] NULL,
  [MfaStatus] [int] NULL CONSTRAINT [DF_UserCredentials_MfaStatus] DEFAULT (0),
  [IsActive] [bit] NULL DEFAULT (0),
  [IsPasswordChanged] [bit] NULL DEFAULT (0),
  [PasswordChangedDate] [datetime] NULL,
  [DefaultLangId] [int] NULL DEFAULT (1),
  [SessionId] [nvarchar](255) NULL,
  [SessionIdValidityTime] [datetime] NULL,
  [RefreshToken] [nvarchar](255) NULL,
  [RefreshTokenValidityDate] [datetime] NULL,
  [RefreshTokenRevokedDate] [datetime] NULL,
  PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_UserCredentials_Email] UNIQUE ([Email])
)
GO

ALTER TABLE [SBSC].[UserCredentials] WITH NOCHECK
  ADD FOREIGN KEY ([AuditorId]) REFERENCES [SBSC].[Auditor] ([Id])
GO

ALTER TABLE [SBSC].[UserCredentials] WITH NOCHECK
  ADD CONSTRAINT [FK_UserCredentials_Auditor] FOREIGN KEY ([AuditorId]) REFERENCES [SBSC].[Auditor] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[UserCredentials] WITH NOCHECK
  ADD CONSTRAINT [FK_UserCredentials_Languages] FOREIGN KEY ([DefaultLangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE SET DEFAULT
GO