CREATE TABLE [SBSC].[AuditorResponseStatusesLanguage] (
  [Id] [int] IDENTITY,
  [AuditorResponseStatusId] [int] NOT NULL,
  [LangId] [int] NOT NULL,
  [StatusName] [nvarchar](100) NULL,
  [Description] [nvarchar](max) NULL,
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AuditorResponseStatusesLanguage]
  ADD CONSTRAINT [FK_AuditorResponseStatusesLanguage_AuditorResponseStatuses] FOREIGN KEY ([AuditorResponseStatusId]) REFERENCES [SBSC].[AuditorResponseStatuses] ([Id])
GO

ALTER TABLE [SBSC].[AuditorResponseStatusesLanguage]
  ADD CONSTRAINT [FK_AuditorResponseStatusesLanguage_Languages] FOREIGN KEY ([LangId]) REFERENCES [SBSC].[Languages] ([Id])
GO