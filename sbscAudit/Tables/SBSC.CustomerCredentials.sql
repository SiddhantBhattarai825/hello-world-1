CREATE TABLE [SBSC].[CustomerCredentials] (
  [Id] [int] NOT NULL,
  [Email] [nvarchar](100) NOT NULL,
  [Password] [nvarchar](500) NOT NULL,
  [IsPasswordChanged] [bit] NOT NULL,
  [PasswordChangedDate] [datetime] NOT NULL,
  [MfaStatus] [int] NOT NULL,
  [DefaultLangId] [int] NULL,
  [SessionId] [nvarchar](255) NULL,
  [SessionIdValidityTime] [datetime] NULL,
  [CustomerId] [int] NULL,
  [RefreshToken] [nvarchar](255) NULL,
  [RefreshTokenValidityDate] [datetime] NULL,
  [RefreshTokenRevokedDate] [datetime] NULL,
  [IsActive] [bit] NULL
)
GO