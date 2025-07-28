CREATE TABLE [SBSC].[DocumentCommentThread] (
  [Id] [int] NOT NULL,
  [DocumentId] [int] NULL,
  [CustomerId] [int] NULL,
  [AuditorId] [int] NULL,
  [ParentCommentId] [int] NULL,
  [Comment] [nvarchar](max) NULL,
  [CreatedDate] [datetime] NULL,
  [ModifiedDate] [datetime] NULL,
  [CustomerCommentTurn] [bit] NULL,
  [ReadStatus] [bit] NULL,
  [Recertification] [int] NULL,
  [IsApproved] [bit] NULL
)
GO