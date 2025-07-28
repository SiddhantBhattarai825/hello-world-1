CREATE TABLE [SBSC].[CustomerSelectedAnswers] (
  [Id] [int] IDENTITY,
  [CustomerResponseId] [int] NOT NULL,
  [AnswerOptionsId] [int] NOT NULL,
  [AddedDate] [datetime] NOT NULL DEFAULT (getutcdate()),
  PRIMARY KEY CLUSTERED ([Id])
)
GO

ALTER TABLE [SBSC].[CustomerSelectedAnswers] WITH NOCHECK
  ADD CONSTRAINT [FK_CustomerSelectedAnswers_CustomerResponse] FOREIGN KEY ([CustomerResponseId]) REFERENCES [SBSC].[CustomerResponse] ([Id]) ON DELETE CASCADE
GO