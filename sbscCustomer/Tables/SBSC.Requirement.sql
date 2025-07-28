CREATE TABLE [SBSC].[Requirement] (
  [Id] [int] NOT NULL,
  [RequirementTypeId] [int] NOT NULL,
  [IsCommentable] [bit] NOT NULL,
  [IsFileUploadRequired] [bit] NOT NULL,
  [IsFileUploadAble] [bit] NOT NULL,
  [DisplayOrder] [int] NULL,
  [IsVisible] [bit] NULL,
  [IsActive] [int] NULL,
  [AuditYears] [nvarchar](50) NULL,
  [AddedDate] [date] NULL,
  [AddedBy] [int] NULL,
  [ModifiedDate] [date] NULL,
  [ModifiedBy] [int] NULL,
  [ParentRequirementId] [int] NULL,
  [Version] [decimal](6, 2) NULL,
  [IsChanged] [bit] NULL
)
GO