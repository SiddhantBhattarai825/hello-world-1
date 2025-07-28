CREATE TABLE [SBSC].[Documents] (
  [Id] [int] NOT NULL,
  [DisplayOrder] [int] NULL,
  [IsVisible] [bit] NOT NULL,
  [AddedDate] [datetime] NOT NULL,
  [RequirementTypeId] [int] NULL,
  [AddedBy] [int] NULL,
  [UserRole] [int] NULL,
  [ModifiedDate] [datetime] NULL,
  [ModifiedBy] [int] NULL,
  [Version] [decimal](6, 2) NULL,
  [IsFileUploadRequired] [bit] NULL,
  [IsFileUploadable] [bit] NULL,
  [IsCommentable] [bit] NULL
)
GO