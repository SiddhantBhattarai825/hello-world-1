CREATE TABLE [SBSC].[CustomerLoginLogs] (
  [Id] [int] IDENTITY,
  [UserId] [int] NULL,
  [LoginDateTime] [datetime] NOT NULL,
  [Browser] [nvarchar](100) NOT NULL,
  [Ipaddress] [nvarchar](20) NOT NULL,
  [LoginAttemptsCount] [tinyint] NULL,
  [LoginStatus] [nvarchar](50) NULL,
  [Email] [nvarchar](255) NULL,
  [OS] [nvarchar](100) NULL,
  [UserType] [nvarchar](50) NULL,
  CONSTRAINT [PK_UserLoginLog] PRIMARY KEY CLUSTERED ([Id])
)
GO