CREATE TABLE [SBSC].[AuditorCredentials] (
  [Id] [int] IDENTITY,
  [Email] [nvarchar](100) NOT NULL,
  [Password] [nvarchar](500) NULL,
  [IsActive] [bit] NULL CONSTRAINT [DF_AuditorCredentials_IsActive] DEFAULT (0),
  [IsPasswordChanged] [bit] NULL CONSTRAINT [DF_AuditorCredentials_IsPasswordChanged] DEFAULT (0),
  [PasswordChangedDate] [datetime] NULL,
  [MfaStatus] [int] NULL,
  [DefaultLangId] [int] NULL DEFAULT (1),
  [SessionId] [nvarchar](255) NULL,
  [SessionIdValidityTime] [datetime] NULL,
  [AuditorId] [int] NULL,
  [RefreshToken] [nvarchar](255) NULL,
  [RefreshTokenValidityDate] [datetime] NULL,
  [RefreshTokenRevokedDate] [datetime] NULL,
  [LockoutEndTime] [datetime] NULL,
  [ReaminingLoginAttempts] [int] NULL,
  CONSTRAINT [PK_AuditorCredentials] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_AuditorCredentials_Email] UNIQUE ([Email])
)
GO

ALTER TABLE [SBSC].[AuditorCredentials] WITH NOCHECK
  ADD CONSTRAINT [FK_AuditorCredentials_Auditor] FOREIGN KEY ([AuditorId]) REFERENCES [SBSC].[Auditor] ([Id])
GO

ALTER TABLE [SBSC].[AuditorCredentials] WITH NOCHECK
  ADD CONSTRAINT [FK_AuditorCredentials_Languages] FOREIGN KEY ([DefaultLangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE SET DEFAULT
GO