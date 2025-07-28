CREATE TABLE [SBSC].[CommentThread] (
  [ID] [int] NOT NULL,
  [RequirementId] [int] NULL,
  [CustomerId] [int] NULL,
  [AuditorId] [int] NULL,
  [ParentCommentId] [int] NULL,
  [Comment] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NULL,
  [ModifiedDate] [datetime] NULL,
  [CustomerCommentTurn] [bit] NULL,
  [ReadStatus] [bit] NULL,
  [CustomerCertificationDetailsId] [int] NULL
)
GO