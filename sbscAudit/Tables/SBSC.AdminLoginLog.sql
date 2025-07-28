CREATE TABLE [SBSC].[AdminLoginLog] (
  [Id] [int] IDENTITY,
  [LoginDateTime] [datetime] NOT NULL,
  [Browser] [nvarchar](255) NULL,
  [Ipaddress] [nvarchar](20) NOT NULL,
  [LoginAttemptsCount] [tinyint] NULL,
  [LoginStatus] [nvarchar](50) NULL,
  [Email] [nvarchar](500) NULL,
  [UserId] [int] NULL,
  [OS] [nvarchar](100) NULL,
  CONSTRAINT [PK_AdminLoginLog] PRIMARY KEY CLUSTERED ([Id])
)
GO