SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SBSC].[vw_AdminUserDetails]
AS
SELECT        au.Id, au.Email, au.IsActive, au.IsPasswordChanged, au.PasswordChangedDate, aud.FullName, aud.DateOfBirth, aud.AddedDate, aud.AddedBy, aud.ModifiedBy, aud.ModifiedDate, au.MfaStatus, au.DefaultLangId
FROM            SBSC.AdminUser AS au INNER JOIN
                         SBSC.AdminUserDetail AS aud ON au.Id = aud.AdminUserId
GO