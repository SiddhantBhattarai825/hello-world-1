CREATE TABLE [SBSC].[Menu] (
  [Id] [int] IDENTITY,
  [ParentMenuId] [int] NULL DEFAULT (NULL),
  [LabelTextId] [int] NOT NULL,
  [Url] [varchar](255) NULL,
  [IsActive] [bit] NULL DEFAULT (1),
  [MenuOrder] [int] NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[Menu] WITH NOCHECK
  ADD CONSTRAINT [FK_Menu_LabelTexts] FOREIGN KEY ([LabelTextId]) REFERENCES [SBSC].[LabelTexts] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[Menu] WITH NOCHECK
  ADD CONSTRAINT [FK_Menu_ParentMenu] FOREIGN KEY ([ParentMenuId]) REFERENCES [SBSC].[Menu] ([Id])
GO