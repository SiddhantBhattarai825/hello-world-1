CREATE TABLE [SBSC].[AuditorResponseStatuses] (
  [Id] [int] IDENTITY,
  [StatusName] [nvarchar](100) NOT NULL,
  [Description] [nvarchar](255) NULL,
  [LanguageId] [int] NULL,
  [DisplayOrder] [int] NOT NULL DEFAULT (0),
  [Score] [int] NOT NULL DEFAULT (0),
  CONSTRAINT [PK_AuditorResponseStatuses] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[AuditorResponseStatuses]
  ADD CONSTRAINT [FK_AuditorResponseStatuses_Languages] FOREIGN KEY ([LanguageId]) REFERENCES [SBSC].[Languages] ([Id])
GO