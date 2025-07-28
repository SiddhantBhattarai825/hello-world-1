CREATE TABLE [SBSC].[AdminUser] (
  [Id] [int] IDENTITY,
  [Email] [nvarchar](500) NOT NULL,
  [Password] [nvarchar](500) NULL,
  [IsActive] [bit] NULL CONSTRAINT [DF__AdminUser__Is_Ac__756D6ECB] DEFAULT (0),
  [IsPasswordChanged] [bit] NULL CONSTRAINT [DF__AdminUser__Is_Pa__76619304] DEFAULT (0),
  [PasswordChangedDate] [datetime] NULL,
  [MfaStatus] [int] NOT NULL CONSTRAINT [DF__AdminUser__MfaSta__NEWID] DEFAULT (0),
  [DefaultLangId] [int] NULL DEFAULT (1),
  [SessionId] [nvarchar](255) NULL,
  [SessionIdValidityTime] [datetime] NULL,
  [RefreshToken] [nvarchar](255) NULL,
  [RefreshTokenValidityDate] [datetime] NULL,
  [RefreshTokenRevokedDate] [datetime] NULL,
  [LockoutEndTime] [datetime2] NULL,
  [ReaminingLoginAttempts] [int] NOT NULL DEFAULT (3),
  CONSTRAINT [PK_Admin_User] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_AdminUser_Email] UNIQUE ([Email])
)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[trg_AdminUserDelete]
ON [SBSC].[AdminUser]
INSTEAD OF DELETE
AS
BEGIN
    DECLARE @FirstAdminId INT;

    -- Get the first admin user by ascending order of Id
    SELECT TOP 1 @FirstAdminId = Id
    FROM SBSC.AdminUser
    ORDER BY Id ASC;

    -- Update the EmailTemplate table to set AddedBy to the first admin
    UPDATE EmailTemplate
    SET AddedBy = @FirstAdminId
    WHERE AddedBy IN (SELECT Id FROM deleted);

    -- Delete the admin user
    DELETE FROM SBSC.AdminUser
    WHERE Id IN (SELECT Id FROM deleted);
END;
GO

ALTER TABLE [SBSC].[AdminUser] WITH NOCHECK
  ADD CONSTRAINT [FK_AdminUser_Languages] FOREIGN KEY ([DefaultLangId]) REFERENCES [SBSC].[Languages] ([Id]) ON DELETE SET DEFAULT
GO