CREATE TABLE [SBSC].[LabelTexts] (
  [Id] [int] IDENTITY,
  [Code] [nvarchar](50) NOT NULL,
  [LabelTitle] [nvarchar](50) NOT NULL,
  [LabelDescription] [nvarchar](500) NULL,
  [PageCode] [nvarchar](50) NOT NULL,
  [Section] [nvarchar](50) NOT NULL,
  CONSTRAINT [PK_LabelTexts] PRIMARY KEY CLUSTERED ([Id]),
  CONSTRAINT [UQ_LabelTexts_PageCode_Section_Code] UNIQUE ([PageCode], [Section], [Code])
)
GO