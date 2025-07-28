CREATE TABLE [SBSC].[Documents] (
  [Id] [int] IDENTITY,
  [DisplayOrder] [int] NULL,
  [IsVisible] [bit] NOT NULL CONSTRAINT [DF__Documents__IsVis__62458BBE] DEFAULT (1),
  [AddedDate] [datetime] NOT NULL CONSTRAINT [DF__Documents__Added__7740A8A4] DEFAULT (getdate()),
  [RequirementTypeId] [int] NULL,
  [AddedBy] [int] NULL,
  [UserRole] [int] NULL,
  [ModifiedDate] [datetime] NULL,
  [ModifiedBy] [int] NULL,
  [Version] [decimal](6, 2) NULL,
  [IsFileUploadRequired] [bit] NULL,
  [IsFileUploadable] [bit] NULL,
  [IsCommentable] [bit] NULL,
  CONSTRAINT [PK__Document__3214EC074FA1A68B] PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[Documents] WITH NOCHECK
  ADD CONSTRAINT [FK_Documents_RequirementTypes] FOREIGN KEY ([RequirementTypeId]) REFERENCES [SBSC].[RequirementType] ([Id])
GO