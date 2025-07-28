CREATE TABLE [SBSC].[Certification_Assignment] (
  [AssignmentId] [int] IDENTITY,
  [CustomerCertificationId] [int] NOT NULL,
  [AuditorId] [int] NOT NULL,
  [AddressId] [int] NULL,
  [DepartmentId] [int] NULL,
  [IsLeadAuditor] [bit] NOT NULL DEFAULT (0),
  [FromDate] [date] NULL DEFAULT (getdate()),
  [AssignedTime] [time](0) NULL,
  [ToDate] [date] NULL,
  CONSTRAINT [PK_CertificationAssignment] PRIMARY KEY CLUSTERED ([AssignmentId])
)
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE TRIGGER [SBSC].[trg_LeadAuditor]
ON [SBSC].[Certification_Assignment]
AFTER INSERT, UPDATE
AS
BEGIN
    DECLARE @CustomerCertificationId INT;
    DECLARE @AuditorId INT;
    DECLARE @IsLeadAuditor BIT;

    -- Get the inserted/updated values
    SELECT @CustomerCertificationId = CustomerCertificationId,
           @AuditorId = AuditorId,
           @IsLeadAuditor = IsLeadAuditor
    FROM inserted;

    -- If the row is marked as lead auditor (IsLeadAuditor = 1)
    IF @IsLeadAuditor = 1
    BEGIN
        -- Update all rows for the same CustomerCertificationId, making IsLeadAuditor = 0
        UPDATE SBSC.Certification_Assignment
        SET IsLeadAuditor = 0
        WHERE CustomerCertificationId = @CustomerCertificationId
        AND AuditorId != @AuditorId;

        -- Ensure only one row for the given CustomerCertificationId and AuditorId has IsLeadAuditor = 1
        UPDATE SBSC.Certification_Assignment
        SET IsLeadAuditor = 1
        WHERE CustomerCertificationId = @CustomerCertificationId
        AND AuditorId = @AuditorId;
    END
END
GO

ALTER TABLE [SBSC].[Certification_Assignment] WITH NOCHECK
  ADD CONSTRAINT [FK_Certification_Assignment_Address] FOREIGN KEY ([AddressId]) REFERENCES [SBSC].[Customer_Address] ([Id]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[Certification_Assignment]
  ADD CONSTRAINT [FK_Certification_Assignment_Customer_Certification] FOREIGN KEY ([CustomerCertificationId]) REFERENCES [SBSC].[Customer_Certifications] ([CustomerCertificationId]) ON DELETE CASCADE
GO

ALTER TABLE [SBSC].[Certification_Assignment] WITH NOCHECK
  ADD CONSTRAINT [FK_Certification_Assignment_Department] FOREIGN KEY ([DepartmentId]) REFERENCES [SBSC].[Customer_Department] ([Id]) ON DELETE CASCADE
GO