CREATE TABLE [SBSC].[CustomerCredentials] (
  [Id] [int] IDENTITY,
  [Email] [nvarchar](100) NOT NULL,
  [Password] [nvarchar](500) NULL,
  [IsPasswordChanged] [bit] NULL CONSTRAINT [DF_CustomerCredentials_IsPasswordChanged] DEFAULT (0),
  [PasswordChangedDate] [datetime] NULL,
  [MfaStatus] [int] NULL,
  [DefaultLangId] [int] NULL DEFAULT (1),
  [SessionId] [nvarchar](255) NULL,
  [SessionIdValidityTime] [datetime] NULL,
  [CustomerId] [int] NULL,
  [RefreshToken] [nvarchar](255) NULL,
  [RefreshTokenValidityDate] [datetime] NULL,
  [RefreshTokenRevokedDate] [datetime] NULL,
  [IsActive] [bit] NULL,
  [LockoutEndTime] [datetime] NULL,
  [ReaminingLoginAttempts] [int] NULL,
  [UserName] [nvarchar](100) NULL,
  [CustomerType] [smallint] NULL,
  CONSTRAINT [PK_CustomerCredentials] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_CustomerCredentials_Email] UNIQUE ([Email])
)
GO