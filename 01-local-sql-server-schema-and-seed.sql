-- =====================================================================
-- DynamicsCon 2026 -- Multi-Agent Orchestration with Copilot Studio
-- Artifact #2: Local SQL Server schema and seed data (mocked CRONUS USA data)
--
-- Target environment:
--   Local SQL Server (default instance) on the demo laptop
--   Server name:    YOUR-SQL-SERVER-NAME
--   Instance:       MSSQLSERVER (default, connect with just the server name)
--   Authentication: SQL Server authentication (mixed mode)
--   Login:          sa
--   Password:       YourStrongPasswordHere
--   Database name:  Cronus
--
-- Purpose: Provides the data backing the MCP server that powers the
--          Sales, Finance, and Inventory specialist agents.
--
-- Narrative: CRONUS USA, Inc. order intake with credit hold scenario.
-- Triggering question: "Adatum Corporation wants 500 units of 1900-S
-- PARIS Guest Chair, black, shipping next Friday, on NET-30 terms.
-- Can we commit?"
--
-- Key demo numbers (these are the math the audience can verify on slide):
--   Adatum Corporation (10000): Credit limit 250,000, AR balance 116,000
--     -> 46.4% current utilization
--   Order: 500 units at negotiated 190.00/unit = 95,000.00
--     -> Projected exposure 211,000 = 84.4%, just under 85% CFO threshold
--   Inventory: 300 (MAIN) + 150 (EAST) on hand = 450, plus 50 inbound to
--     WEST in 3 business days. Drives split-shipment recommendation.
--
-- One-time SQL Server setup (if not already configured):
--   1. Enable mixed mode: in SSMS, right-click the server -> Properties
--      -> Security -> Server authentication = "SQL Server and Windows
--      Authentication mode". Restart the SQL Server service after changing.
--   2. Enable the sa login: in SSMS, Security -> Logins -> sa
--      -> Properties -> Status -> Login = Enabled. Set the password
--      to YourStrongPasswordHere on the General tab.
--   3. Verify connectivity: in SSMS, connect as
--      Server: YOUR-SQL-SERVER-NAME, Auth: SQL Server, Login: sa, Pwd: YourStrongPasswordHere
--
-- Run order: execute top to bottom in SSMS connected as sa.
-- Verification queries at the bottom mirror what the MCP server will do.
-- =====================================================================

-- =====================================================================
-- STEP 1: Create the [Cronus] database. Safe to re-run (no-op if exists).
--
-- Optional hard reset (uncomment to drop and recreate from scratch):
--   IF EXISTS (SELECT name FROM sys.databases WHERE name = N'Cronus')
--       DROP DATABASE [Cronus];
--   GO
-- =====================================================================

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'Cronus')
BEGIN
    CREATE DATABASE [Cronus];
END
GO

-- =====================================================================
-- STEP 2: Switch to the Cronus database.
-- On local SQL Server, USE works the way you expect (unlike Azure SQL).
-- =====================================================================

USE [Cronus];
GO

-- Drop existing tables in reverse dependency order (idempotent re-runs)
IF OBJECT_ID('dbo.OrderHistory', 'U')   IS NOT NULL DROP TABLE dbo.OrderHistory;
IF OBJECT_ID('dbo.Pricing', 'U')        IS NOT NULL DROP TABLE dbo.Pricing;
IF OBJECT_ID('dbo.Inventory', 'U')      IS NOT NULL DROP TABLE dbo.Inventory;
IF OBJECT_ID('dbo.CreditProfiles', 'U') IS NOT NULL DROP TABLE dbo.CreditProfiles;
IF OBJECT_ID('dbo.Products', 'U')       IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID('dbo.Customers', 'U')      IS NOT NULL DROP TABLE dbo.Customers;
GO

-- =====================================================================
-- TABLE: Customers  (BC-style customer master)
-- =====================================================================
CREATE TABLE dbo.Customers (
    CustomerNo            NVARCHAR(20)    NOT NULL,
    Name                  NVARCHAR(100)   NOT NULL,
    Address               NVARCHAR(200)   NULL,
    City                  NVARCHAR(50)    NULL,
    [State]               NVARCHAR(20)    NULL,
    PostalCode            NVARCHAR(20)    NULL,
    Country               NVARCHAR(50)    NULL,
    PhoneNo               NVARCHAR(30)    NULL,
    Email                 NVARCHAR(100)   NULL,
    PaymentTermsCode      NVARCHAR(20)    NULL,
    CustomerPostingGroup  NVARCHAR(20)    NULL,
    CurrencyCode          NVARCHAR(10)    NOT NULL DEFAULT 'USD',
    SalespersonCode       NVARCHAR(20)    NULL,
    CreatedDate           DATE            NOT NULL,
    LastModifiedDate      DATE            NULL,
    IsActive              BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_Customers PRIMARY KEY (CustomerNo)
);
GO

-- =====================================================================
-- TABLE: CreditProfiles  (limits, balances, risk indicators)
-- =====================================================================
CREATE TABLE dbo.CreditProfiles (
    CustomerNo            NVARCHAR(20)    NOT NULL,
    CreditLimit           DECIMAL(18,2)   NOT NULL DEFAULT 0,
    BalanceLCY            DECIMAL(18,2)   NOT NULL DEFAULT 0,
    DaysPastDue           INT             NOT NULL DEFAULT 0,
    LastReviewDate        DATE            NULL,
    PaymentHistoryRating  NVARCHAR(10)    NULL,
    OnHold                BIT             NOT NULL DEFAULT 0,
    ReviewThresholdPct    DECIMAL(5,2)    NOT NULL DEFAULT 85.00,
    CONSTRAINT PK_CreditProfiles PRIMARY KEY (CustomerNo),
    CONSTRAINT FK_CreditProfiles_Customers FOREIGN KEY (CustomerNo)
        REFERENCES dbo.Customers(CustomerNo)
);
GO

-- =====================================================================
-- TABLE: Products  (item master)
-- =====================================================================
CREATE TABLE dbo.Products (
    ItemNo                NVARCHAR(20)    NOT NULL,
    [Description]         NVARCHAR(200)   NOT NULL,
    ItemCategoryCode      NVARCHAR(20)    NULL,
    BaseUOM               NVARCHAR(10)    NOT NULL DEFAULT 'PCS',
    UnitPrice             DECIMAL(18,2)   NOT NULL,
    UnitCost              DECIMAL(18,2)   NULL,
    IsActive              BIT             NOT NULL DEFAULT 1,
    CONSTRAINT PK_Products PRIMARY KEY (ItemNo)
);
GO

-- =====================================================================
-- TABLE: Inventory  (on-hand, allocated, inbound per item per location)
-- =====================================================================
CREATE TABLE dbo.Inventory (
    InventoryId           INT             IDENTITY(1,1) NOT NULL,
    ItemNo                NVARCHAR(20)    NOT NULL,
    LocationCode          NVARCHAR(20)    NOT NULL,
    QuantityOnHand        DECIMAL(18,2)   NOT NULL DEFAULT 0,
    QuantityAllocated     DECIMAL(18,2)   NOT NULL DEFAULT 0,
    QuantityInbound       DECIMAL(18,2)   NOT NULL DEFAULT 0,
    InboundExpectedDate   DATE            NULL,
    LastUpdated           DATETIME2       NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_Inventory PRIMARY KEY (InventoryId),
    CONSTRAINT FK_Inventory_Products FOREIGN KEY (ItemNo)
        REFERENCES dbo.Products(ItemNo),
    CONSTRAINT UQ_Inventory_ItemLocation UNIQUE (ItemNo, LocationCode)
);
GO

-- =====================================================================
-- TABLE: Pricing  (customer-specific item pricing agreements)
-- =====================================================================
CREATE TABLE dbo.Pricing (
    PricingId             INT             IDENTITY(1,1) NOT NULL,
    CustomerNo            NVARCHAR(20)    NOT NULL,
    ItemNo                NVARCHAR(20)    NOT NULL,
    UnitPrice             DECIMAL(18,2)   NOT NULL,
    MinimumQuantity       DECIMAL(18,2)   NOT NULL DEFAULT 0,
    StartingDate          DATE            NOT NULL,
    EndingDate            DATE            NULL,
    CONSTRAINT PK_Pricing PRIMARY KEY (PricingId),
    CONSTRAINT FK_Pricing_Customers FOREIGN KEY (CustomerNo)
        REFERENCES dbo.Customers(CustomerNo),
    CONSTRAINT FK_Pricing_Products FOREIGN KEY (ItemNo)
        REFERENCES dbo.Products(ItemNo)
);
GO

-- =====================================================================
-- TABLE: OrderHistory  (posted sales orders, simplified for demo)
-- =====================================================================
CREATE TABLE dbo.OrderHistory (
    DocumentNo            NVARCHAR(20)    NOT NULL,
    CustomerNo            NVARCHAR(20)    NOT NULL,
    OrderDate             DATE            NOT NULL,
    PostingDate           DATE            NULL,
    Amount                DECIMAL(18,2)   NOT NULL,
    [Status]              NVARCHAR(20)    NOT NULL,
    SalespersonCode       NVARCHAR(20)    NULL,
    CONSTRAINT PK_OrderHistory PRIMARY KEY (DocumentNo),
    CONSTRAINT FK_OrderHistory_Customers FOREIGN KEY (CustomerNo)
        REFERENCES dbo.Customers(CustomerNo)
);
GO

-- =====================================================================
-- Indexes for read-heavy agent queries
-- =====================================================================
CREATE INDEX IX_Customers_Name        ON dbo.Customers(Name);
CREATE INDEX IX_OrderHistory_Customer ON dbo.OrderHistory(CustomerNo, OrderDate DESC);
CREATE INDEX IX_Inventory_Item        ON dbo.Inventory(ItemNo);
CREATE INDEX IX_Pricing_CustomerItem  ON dbo.Pricing(CustomerNo, ItemNo);
GO

-- =====================================================================
-- SEED: Customers
--   10000 Adatum Corporation  -- the real one, target of the demo
--   10095 Adatum Holdings, Inc. -- the duplicate, sparse, misleads Demo 1
--   20000 Trey Research        -- warm-up / rehearsal customer
--   30000 School of Fine Art   -- realism
--   40000 Alpine Ski House     -- realism
--   50000 Relecloud            -- realism
-- =====================================================================
INSERT INTO dbo.Customers
    (CustomerNo, Name, Address, City, [State], PostalCode, Country,
     PhoneNo, Email, PaymentTermsCode, CustomerPostingGroup,
     CurrencyCode, SalespersonCode, CreatedDate, LastModifiedDate, IsActive)
VALUES
    ('10000', 'Adatum Corporation',     '192 Market Square',        'Atlanta', 'GA', '31772', 'US',
     '+1-404-555-0100', 'orders@adatum-corp.com',     'NET30', 'DOMESTIC', 'USD', 'MO',
     '2019-03-14', '2026-09-15', 1),

    ('10095', 'Adatum Holdings, Inc.',  NULL,                       'Atlanta', 'GA', NULL,    'US',
     NULL,              NULL,                          'NET15', 'DOMESTIC', 'USD', NULL,
     '2023-11-08', '2023-11-08', 1),

    ('20000', 'Trey Research',          '153 Thomas Drive',         'Chicago', 'IL', '61236', 'US',
     '+1-312-555-0140', 'ap@treyresearch.com',        'NET30', 'DOMESTIC', 'USD', 'PS',
     '2020-07-22', '2026-08-30', 1),

    ('30000', 'School of Fine Art',     '2300 University Lane',     'Miami',   'FL', '37125', 'US',
     '+1-305-555-0180', 'accounts@sfa.edu',           'NET45', 'EDUCATION','USD', 'JR',
     '2018-09-01', '2026-07-12', 1),

    ('40000', 'Alpine Ski House',       '4452 Mountain View Road',  'Denver',  'CO', '80014', 'US',
     '+1-303-555-0145', 'orders@alpineski.com',       'NET30', 'DOMESTIC', 'USD', 'PS',
     '2021-01-18', '2026-09-05', 1),

    ('50000', 'Relecloud',              '989 Cloud Avenue',         'Seattle', 'WA', '98101', 'US',
     '+1-206-555-0190', 'procurement@relecloud.com',  'NET30', 'DOMESTIC', 'USD', 'MO',
     '2022-05-30', '2026-09-22', 1);
GO

-- =====================================================================
-- SEED: CreditProfiles
-- KEY DEMO ROWS:
--   10000 Adatum Corp: 250k limit, 116k balance (46.4% utilization).
--                      Order pushes to 211k (84.4%), just under threshold.
--   10095 Adatum Holdings: 50k default limit, 0 balance, no rating,
--                          no review history. Looks deceptively safe to
--                          a single agent that picks the wrong record.
-- =====================================================================
INSERT INTO dbo.CreditProfiles
    (CustomerNo, CreditLimit, BalanceLCY, DaysPastDue,
     LastReviewDate, PaymentHistoryRating, OnHold, ReviewThresholdPct)
VALUES
    ('10000', 250000.00, 116000.00,  0, '2026-09-01', 'A',  0, 85.00),
    ('10095',  50000.00,      0.00,  0, NULL,         NULL, 0, 85.00),
    ('20000', 100000.00,  32000.00,  0, '2026-08-15', 'A',  0, 85.00),
    ('30000',  75000.00,  18500.00, 15, '2026-07-20', 'B',  0, 85.00),
    ('40000', 150000.00,  89000.00,  0, '2026-08-25', 'A',  0, 85.00),
    ('50000', 200000.00, 142000.00,  0, '2026-09-10', 'A',  0, 85.00);
GO

-- =====================================================================
-- SEED: Products
-- 1900-S PARIS Guest Chair, black -- demo star
-- =====================================================================
INSERT INTO dbo.Products
    (ItemNo, [Description], ItemCategoryCode, BaseUOM, UnitPrice, UnitCost, IsActive)
VALUES
    ('1900-S', 'PARIS Guest Chair, black',     'CHAIR', 'PCS',  200.00, 110.00, 1),
    ('1896-S', 'ATHENS Desk',                  'DESK',  'PCS',  800.00, 480.00, 1),
    ('1908-S', 'LONDON Swivel Chair, blue',    'CHAIR', 'PCS',  220.00, 120.00, 1),
    ('1920-S', 'ANTWERP Conference Table',     'TABLE', 'PCS', 1200.00, 720.00, 1),
    ('1928-S', 'AMSTERDAM Lamp',               'LAMP',  'PCS',   90.00,  50.00, 1),
    ('1936-S', 'BERLIN Guest Chair, yellow',   'CHAIR', 'PCS',  210.00, 115.00, 1);
GO

-- =====================================================================
-- SEED: Inventory
-- 1900-S PARIS Guest Chair stocking pattern:
--   MAIN: 300 on hand
--   EAST: 150 on hand
--   WEST:   0 on hand, 50 inbound, expected in 3 business days
-- Total on-hand 450 + 50 inbound = 500, matching the 500-unit order.
-- =====================================================================
INSERT INTO dbo.Inventory
    (ItemNo, LocationCode, QuantityOnHand, QuantityAllocated,
     QuantityInbound, InboundExpectedDate)
VALUES
    -- 1900-S: the demo star
    ('1900-S', 'MAIN', 300,  0,  0, NULL),
    ('1900-S', 'EAST', 150,  0,  0, NULL),
    ('1900-S', 'WEST',   0,  0, 50, DATEADD(day, 3, CAST(GETDATE() AS DATE))),

    -- Background inventory for realism
    ('1896-S', 'MAIN',  45,  5, 20, DATEADD(day,  7, CAST(GETDATE() AS DATE))),
    ('1896-S', 'EAST',  22,  0,  0, NULL),
    ('1908-S', 'MAIN', 180, 12,  0, NULL),
    ('1908-S', 'WEST',  60,  0,  0, NULL),
    ('1920-S', 'MAIN',   8,  2,  4, DATEADD(day, 14, CAST(GETDATE() AS DATE))),
    ('1928-S', 'EAST',  64,  0,  0, NULL),
    ('1936-S', 'WEST',  95,  5,  0, NULL);
GO

-- =====================================================================
-- SEED: Pricing
-- Adatum Corporation's negotiated price for 1900-S is 190.00/unit
-- (vs list 200.00). 500 units x 190.00 = 95,000.00 order total.
-- =====================================================================
INSERT INTO dbo.Pricing
    (CustomerNo, ItemNo, UnitPrice, MinimumQuantity, StartingDate, EndingDate)
VALUES
    ('10000', '1900-S',   190.00, 100, '2025-01-01', '2026-12-31'),
    ('10000', '1896-S',   760.00,  10, '2025-01-01', '2026-12-31'),
    ('20000', '1900-S',   195.00,  50, '2025-01-01', '2026-12-31'),
    ('40000', '1908-S',   210.00,  25, '2025-06-01', '2026-12-31'),
    ('50000', '1920-S',  1140.00,   5, '2025-03-01', '2026-12-31');
GO

-- =====================================================================
-- SEED: OrderHistory
-- Adatum Corporation: 12 orders over the last 18 months, trending up.
-- Last three orders show clear growth. Sales agent uses this in Demo 3.
--
-- Note: BalanceLCY in CreditProfiles is a snapshot (mirrors what BC
-- exposes from Customer Ledger Entries). It is intentionally not a
-- direct sum of OrderHistory rows; payments and credits are abstracted.
-- =====================================================================
INSERT INTO dbo.OrderHistory
    (DocumentNo, CustomerNo, OrderDate, PostingDate, Amount, [Status], SalespersonCode)
VALUES
    -- Adatum Corporation (10000) -- 12 orders trending up
    ('SO-101001', '10000', '2025-04-12', '2025-04-15',  2800.00, 'Invoiced', 'MO'),
    ('SO-101015', '10000', '2025-06-08', '2025-06-12',  4200.00, 'Invoiced', 'MO'),
    ('SO-101032', '10000', '2025-08-15', '2025-08-19',  5100.00, 'Invoiced', 'MO'),
    ('SO-101054', '10000', '2025-10-03', '2025-10-07',  6800.00, 'Invoiced', 'MO'),
    ('SO-101078', '10000', '2025-12-14', '2025-12-18',  8500.00, 'Invoiced', 'MO'),
    ('SO-101105', '10000', '2026-01-22', '2026-01-27', 11200.00, 'Invoiced', 'MO'),
    ('SO-101138', '10000', '2026-03-18', '2026-03-23', 14600.00, 'Invoiced', 'MO'),
    ('SO-101171', '10000', '2026-05-09', '2026-05-13', 19400.00, 'Invoiced', 'MO'),
    ('SO-101204', '10000', '2026-06-25', '2026-06-30', 25800.00, 'Invoiced', 'MO'),
    ('SO-101244', '10000', '2026-07-30', '2026-08-04', 38200.00, 'Invoiced', 'MO'),
    ('SO-101284', '10000', '2026-08-22', '2026-08-27', 51400.00, 'Invoiced', 'MO'),
    ('SO-101324', '10000', '2026-09-15', NULL,         26600.00, 'Open',     'MO'),

    -- Adatum Holdings (10095) -- duplicate record, no order history.
    -- The "sparse" data is the point. Misleads Demo 1.

    -- Trey Research (20000)
    ('SO-102003', '20000', '2026-04-08', '2026-04-12', 12500.00, 'Invoiced', 'PS'),
    ('SO-102045', '20000', '2026-06-22', '2026-06-26', 18900.00, 'Invoiced', 'PS'),
    ('SO-102089', '20000', '2026-08-14', '2026-08-19',  9800.00, 'Invoiced', 'PS'),
    ('SO-102110', '20000', '2026-09-05', NULL,         32000.00, 'Open',     'PS'),

    -- School of Fine Art (30000)
    ('SO-103022', '30000', '2026-05-18', '2026-05-22',  6200.00, 'Invoiced', 'JR'),
    ('SO-103044', '30000', '2026-07-12', '2026-07-16', 12300.00, 'Invoiced', 'JR'),
    ('SO-103056', '30000', '2026-08-30', NULL,         18500.00, 'Open',     'JR'),

    -- Alpine Ski House (40000)
    ('SO-104011', '40000', '2026-03-25', '2026-03-29', 28500.00, 'Invoiced', 'PS'),
    ('SO-104034', '40000', '2026-06-14', '2026-06-18', 35200.00, 'Invoiced', 'PS'),
    ('SO-104067', '40000', '2026-08-22', '2026-08-26', 25300.00, 'Invoiced', 'PS'),
    ('SO-104088', '40000', '2026-09-05', NULL,         89000.00, 'Open',     'PS'),

    -- Relecloud (50000)
    ('SO-105025', '50000', '2026-05-30', '2026-06-03', 42500.00, 'Invoiced', 'MO'),
    ('SO-105056', '50000', '2026-07-18', '2026-07-22', 55600.00, 'Invoiced', 'MO'),
    ('SO-105089', '50000', '2026-09-12', NULL,         44000.00, 'Open',     'MO');
GO

-- =====================================================================
-- VERIFICATION QUERIES
-- Run these after seeding to confirm the data is set up correctly.
-- These mirror the kinds of queries the MCP server will execute.
-- =====================================================================

-- (1) The disambiguation moment: searching "Adatum" returns two records.
-- The Sales agent must pick 10000, not 10095.
SELECT CustomerNo, Name, City, PaymentTermsCode, CreatedDate, LastModifiedDate
FROM dbo.Customers
WHERE Name LIKE '%Adatum%'
ORDER BY CustomerNo;

-- (2) Adatum Corporation full profile (the real one)
SELECT c.CustomerNo, c.Name, c.PaymentTermsCode, c.SalespersonCode,
       cp.CreditLimit, cp.BalanceLCY,
       CAST(cp.BalanceLCY / NULLIF(cp.CreditLimit,0) * 100 AS DECIMAL(5,2)) AS UtilizationPct,
       cp.PaymentHistoryRating, cp.DaysPastDue, cp.ReviewThresholdPct
FROM dbo.Customers c
JOIN dbo.CreditProfiles cp ON cp.CustomerNo = c.CustomerNo
WHERE c.CustomerNo = '10000';

-- (3) Adatum Holdings profile (the duplicate). Note nulls and zero balance.
SELECT c.CustomerNo, c.Name, c.PaymentTermsCode,
       cp.CreditLimit, cp.BalanceLCY, cp.PaymentHistoryRating, cp.LastReviewDate
FROM dbo.Customers c
LEFT JOIN dbo.CreditProfiles cp ON cp.CustomerNo = c.CustomerNo
WHERE c.CustomerNo = '10095';

-- (4) Inventory availability for 1900-S PARIS Guest Chair
SELECT ItemNo, LocationCode, QuantityOnHand, QuantityAllocated,
       QuantityInbound, InboundExpectedDate
FROM dbo.Inventory
WHERE ItemNo = '1900-S'
ORDER BY LocationCode;

-- (5) Adatum Corp's negotiated price for 1900-S
SELECT p.CustomerNo, c.Name, p.ItemNo, p.UnitPrice, p.MinimumQuantity,
       p.StartingDate, p.EndingDate
FROM dbo.Pricing p
JOIN dbo.Customers c ON c.CustomerNo = p.CustomerNo
WHERE p.CustomerNo = '10000' AND p.ItemNo = '1900-S';

-- (6) Adatum Corp's order history, most recent first.
-- Sales agent uses this to characterize the trend.
SELECT DocumentNo, OrderDate, Amount, [Status]
FROM dbo.OrderHistory
WHERE CustomerNo = '10000'
ORDER BY OrderDate DESC;

-- (7) The headline calculation that the Finance agent returns in Demo 3.
DECLARE @OrderAmount DECIMAL(18,2) = 500 * 190.00;  -- 95,000.00
SELECT
    cp.CustomerNo,
    cp.CreditLimit,
    cp.BalanceLCY                                                 AS CurrentBalance,
    @OrderAmount                                                  AS NewOrderAmount,
    cp.BalanceLCY + @OrderAmount                                  AS ProjectedExposure,
    CAST(cp.BalanceLCY / cp.CreditLimit * 100 AS DECIMAL(5,2))    AS CurrentUtilizationPct,
    CAST((cp.BalanceLCY + @OrderAmount) / cp.CreditLimit * 100
         AS DECIMAL(5,2))                                         AS ProjectedUtilizationPct,
    cp.ReviewThresholdPct                                         AS CFOReviewThresholdPct,
    CASE
        WHEN (cp.BalanceLCY + @OrderAmount) / cp.CreditLimit * 100
             >= cp.ReviewThresholdPct
        THEN 'REQUIRES CFO REVIEW'
        ELSE 'WITHIN AUTOMATIC APPROVAL'
    END                                                            AS Recommendation
FROM dbo.CreditProfiles cp
WHERE cp.CustomerNo = '10000';
GO
