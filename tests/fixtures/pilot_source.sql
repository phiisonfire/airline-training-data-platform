-- Synthetic lab only. Owner must apply explicitly to a test SQL Server.
CREATE SCHEMA devops;
GO
CREATE TABLE devops.pilot_source (
    source_id INT NOT NULL PRIMARY KEY,
    display_name NVARCHAR(100) NOT NULL,
    is_active BIT NOT NULL,
    employmentdate DATE NOT NULL
);
INSERT INTO devops.pilot_source VALUES
(1, N'Example Pilot A', 1, '2022-11-17'),
(2, N'Example Pilot B', 0, '2020-02-29');
-- Grant the ingestion principal SELECT on this table only; provision login separately.
