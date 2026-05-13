# GitHub Copilot Scaffolding Prompt
## DynamicsCon 2026 — MCP Server for Multi-Agent Orchestration Demo

---

## How to use this prompt

Open a new empty folder in VS Code, switch GitHub Copilot to **Agent Mode**, paste everything below the horizontal rule (starting at "# Task") into the chat, and let Copilot scaffold the project. The prompt is opinionated about structure, transport patterns, and SQL so the first generation is close to runnable.

**Critical**: This prompt uses the lower-level `Server` class from the MCP SDK (not `McpServer`) with stateless transport mode. This is required for compatibility with Microsoft Copilot Studio. The simpler `McpServer` class does not work with Copilot Studio's MCP connector.

---

# Task

Scaffold a TypeScript MCP (Model Context Protocol) server, running locally on the demo laptop, exposing read-only tools backed by a local Microsoft SQL Server database named `Cronus`. The server will be consumed by Microsoft Copilot Studio agents acting as specialists in a multi-agent orchestration demo. Copilot Studio reaches the local server through a VS Code Dev Tunnel (a persistent named tunnel that gives the laptop a public HTTPS URL).

# Context

The demo is "Multi-Agent Orchestration: Building an AI workforce with Copilot Studio" for DynamicsCon 2026. Three Copilot Studio specialist agents (Sales, Finance, Inventory) plus a generative orchestrator agent collaborate on a B2B order qualification scenario for a fictional company "CRONUS USA, Inc." All four agents read from a shared knowledge base: the local SQL Server database `Cronus`, containing mocked Business Central-shaped data. This MCP server is the bridge between Copilot Studio and SQL Server.

The server runs in a terminal on the demo laptop, listens on `localhost:8080`, and is exposed to Copilot Studio through a persistent VS Code Dev Tunnel. No cloud infrastructure is involved.

# Tech Stack and Conventions

- TypeScript, target Node 20+, ES2022 modules.
- Latest stable `@modelcontextprotocol/sdk` from npm. **Use the lower-level `Server` class from `@modelcontextprotocol/sdk/server/index.js`** (not the higher-level `McpServer` class). This is required for Copilot Studio compatibility.
- Use `StreamableHTTPServerTransport` from `@modelcontextprotocol/sdk/server/streamableHttp.js` configured in **stateless mode** (`sessionIdGenerator: undefined`). Create a fresh server and transport for each request. This pattern is required for Copilot Studio.
- `mssql` npm package for SQL Server connectivity, using a connection pool. Configure for **local SQL Server with SQL authentication** (encryption disabled, server certificate trusted; these settings are inappropriate for production but correct for a local default instance with no TLS configured).
- `express` v5 for HTTP routing.
- `cors` package configured to allow all origins (required for Copilot Studio).
- `zod` for runtime input validation of tool arguments. Every tool input must be validated.
- `dotenv` for environment variable loading.
- Strict TypeScript (`"strict": true` in `tsconfig.json`).
- **No API key authentication**. Copilot Studio's MCP connector does not support custom auth headers. The dev tunnel is protected with anonymous access enabled (see tunnel setup).

No Dockerfile. No Bicep. No deployment scripts. This server only runs locally.

# Project Structure

Generate exactly this structure:

```
mcp-cronus/
├── src/
│   ├── index.ts                       # Entry point: Express server, MCP handler, tool dispatch
│   ├── db/
│   │   └── connection.ts              # SQL connection pool and query helpers
│   └── tools/
│       ├── customers.ts               # handleSearchCustomer, handleGetCustomerDetails
│       ├── pricing.ts                 # handleGetCustomerPricing
│       ├── orders.ts                  # handleGetOrderHistory
│       ├── credit.ts                  # handleGetCreditProfile, handleCalculateCreditExposure
│       └── inventory.ts               # handleGetInventory, handleCheckAvailability
├── package.json
├── tsconfig.json
├── .env
└── README.md
```

# Database Schema (Cronus)

The MCP server reads from these six tables. Do not write to them.

**Customers**(`CustomerNo` PK, `Name`, `Address`, `City`, `State`, `PostalCode`, `Country`, `PhoneNo`, `Email`, `PaymentTermsCode`, `CustomerPostingGroup`, `CurrencyCode`, `SalespersonCode`, `CreatedDate`, `LastModifiedDate`, `IsActive`)

**CreditProfiles**(`CustomerNo` PK FK, `CreditLimit`, `BalanceLCY`, `DaysPastDue`, `LastReviewDate`, `PaymentHistoryRating`, `OnHold`, `ReviewThresholdPct`)

**Products**(`ItemNo` PK, `Description`, `ItemCategoryCode`, `BaseUOM`, `UnitPrice`, `UnitCost`, `IsActive`)

**Inventory**(`InventoryId` PK identity, `ItemNo` FK, `LocationCode`, `QuantityOnHand`, `QuantityAllocated`, `QuantityInbound`, `InboundExpectedDate`, `LastUpdated`). Unique on `(ItemNo, LocationCode)`.

**Pricing**(`PricingId` PK identity, `CustomerNo` FK, `ItemNo` FK, `UnitPrice`, `MinimumQuantity`, `StartingDate`, `EndingDate`)

**OrderHistory**(`DocumentNo` PK, `CustomerNo` FK, `OrderDate`, `PostingDate`, `Amount`, `Status`, `SalespersonCode`)

# Tools to Expose

Each tool must be its own file in `src/tools/`, registered in `src/tools/index.ts`, and exposed through the MCP server. All inputs validated with zod. All return values shaped exactly as described. All SQL uses parameterized queries.

## 1. `search_customer`

**Description for the MCP client**: "Search for customers by name or partial name. Returns up to 25 matches. Use this when a customer is mentioned by name to disambiguate which exact record is meant."

**Input**:
```ts
{ query: string }  // 2-100 chars, trimmed
```

**SQL**:
```sql
SELECT TOP 25 CustomerNo, Name, City, [State], PaymentTermsCode,
              CreatedDate, LastModifiedDate, IsActive
FROM dbo.Customers
WHERE Name LIKE '%' + @query + '%'
ORDER BY CreatedDate ASC;  -- oldest record first; usually the canonical one
```

**Output**: array of customer rows. Empty array if no match. Never throws on empty.

## 2. `get_customer_details`

**Description**: "Get the full customer card for a specific customer number."

**Input**: `{ customer_no: string }` (regex `^[A-Z0-9-]{1,20}$`)

**SQL**:
```sql
SELECT * FROM dbo.Customers WHERE CustomerNo = @customer_no;
```

**Output**: single customer object, or `null` if not found.

## 3. `get_customer_pricing`

**Description**: "Get the negotiated unit price for a specific customer and item. Falls back to the product list price if no customer-specific pricing exists."

**Input**: `{ customer_no: string, item_no: string }`

**SQL** (one query, with fallback handled in code):
```sql
-- First: customer-specific pricing
SELECT TOP 1 UnitPrice, MinimumQuantity, StartingDate, EndingDate
FROM dbo.Pricing
WHERE CustomerNo = @customer_no
  AND ItemNo = @item_no
  AND StartingDate <= CAST(GETDATE() AS DATE)
  AND (EndingDate IS NULL OR EndingDate >= CAST(GETDATE() AS DATE))
ORDER BY StartingDate DESC;

-- Fallback: product list price
SELECT UnitPrice FROM dbo.Products WHERE ItemNo = @item_no;
```

**Output**:
```ts
{
  unitPrice: number,
  source: 'negotiated' | 'list',
  minimumQuantity?: number,
  startingDate?: string,
  endingDate?: string | null
}
```

## 4. `get_order_history`

**Description**: "Get recent orders for a customer, most recent first. Used to characterize purchasing patterns and trends."

**Input**: `{ customer_no: string, limit?: number }` (limit default 10, max 50)

**SQL**:
```sql
SELECT TOP (@limit) DocumentNo, OrderDate, PostingDate, Amount, [Status], SalespersonCode
FROM dbo.OrderHistory
WHERE CustomerNo = @customer_no
ORDER BY OrderDate DESC;
```

**Output**: array of order rows. Compute and include a `trend` field at the top of the response with `recentAverage`, `priorAverage`, and `direction: 'up' | 'down' | 'flat'` derived from the last 3 vs the prior 3 orders.

## 5. `get_credit_profile`

**Description**: "Get the current credit profile for a customer, including limit, outstanding balance, days past due, and current utilization percentage."

**Input**: `{ customer_no: string }`

**SQL**:
```sql
SELECT CustomerNo, CreditLimit, BalanceLCY, DaysPastDue,
       LastReviewDate, PaymentHistoryRating, OnHold, ReviewThresholdPct
FROM dbo.CreditProfiles
WHERE CustomerNo = @customer_no;
```

**Output**: credit profile object including a computed `utilizationPct` (BalanceLCY / CreditLimit * 100), rounded to 2 decimals. Return `null` if no credit profile exists for the customer (this is intentional for the disambiguation demo: the duplicate Adatum at customer 10095 has a sparse profile).

## 6. `calculate_credit_exposure`

**Description**: "Given a customer and a proposed new order amount, calculate the projected credit exposure and recommend whether the order is within automatic approval or requires CFO review based on the customer's threshold."

**This is the headline tool for Demo 3.** The Finance agent uses this to produce the final recommendation.

**Input**: `{ customer_no: string, order_amount: number }` (order_amount > 0)

**SQL**:
```sql
DECLARE @OrderAmount DECIMAL(18,2) = @order_amount;
SELECT
    cp.CustomerNo,
    cp.CreditLimit,
    cp.BalanceLCY,
    @OrderAmount AS NewOrderAmount,
    cp.BalanceLCY + @OrderAmount AS ProjectedExposure,
    CAST(cp.BalanceLCY / NULLIF(cp.CreditLimit,0) * 100 AS DECIMAL(5,2))
        AS CurrentUtilizationPct,
    CAST((cp.BalanceLCY + @OrderAmount) / NULLIF(cp.CreditLimit,0) * 100
        AS DECIMAL(5,2)) AS ProjectedUtilizationPct,
    cp.ReviewThresholdPct,
    cp.PaymentHistoryRating,
    cp.DaysPastDue
FROM dbo.CreditProfiles cp
WHERE cp.CustomerNo = @customer_no;
```

**Output**:
```ts
{
  customerNo: string,
  creditLimit: number,
  currentBalance: number,
  newOrderAmount: number,
  projectedExposure: number,
  currentUtilizationPct: number,
  projectedUtilizationPct: number,
  cfoReviewThresholdPct: number,
  recommendation: 'AUTOMATIC_APPROVAL' | 'REQUIRES_CFO_REVIEW' | 'EXCEEDS_LIMIT' | 'INSUFFICIENT_PROFILE',
  rationale: string  // one-sentence human-readable explanation
}
```

Recommendation logic (compute in code, not in SQL):
- `INSUFFICIENT_PROFILE` if no credit profile row exists (covers the Adatum Holdings case)
- `EXCEEDS_LIMIT` if projected > limit
- `REQUIRES_CFO_REVIEW` if projected utilization >= threshold (and not over limit)
- `AUTOMATIC_APPROVAL` otherwise

## 7. `get_inventory`

**Description**: "Get inventory levels for a specific item across all warehouse locations, including on-hand quantities, allocated quantities, available quantities (on-hand minus allocated), and any inbound stock with expected dates."

**Input**: `{ item_no: string }`

**SQL**:
```sql
SELECT ItemNo, LocationCode, QuantityOnHand, QuantityAllocated,
       (QuantityOnHand - QuantityAllocated) AS QuantityAvailable,
       QuantityInbound, InboundExpectedDate, LastUpdated
FROM dbo.Inventory
WHERE ItemNo = @item_no
ORDER BY LocationCode;
```

**Output**: array of inventory rows plus a summary at the top with `totalOnHand`, `totalAvailable`, `totalInbound`, `nextInboundDate`.

## 8. `check_availability`

**Description**: "Given an item, a requested quantity, and an optional required-by date, determine whether the request can be fulfilled and produce a fulfillment plan. If on-hand stock is insufficient, considers inbound stock that arrives by the required date and recommends a split shipment."

**This is the headline tool for the Inventory agent in Demo 3.**

**Input**: `{ item_no: string, quantity: number, required_by_date?: string }` (ISO date format if provided)

**Logic**:
1. Query inventory across all locations for the item.
2. Compute total available (sum of `QuantityOnHand - QuantityAllocated`).
3. If `quantity` <= total available, return a single-shipment plan from the locations with the most stock first.
4. If `quantity` > total available, check `QuantityInbound` rows where `InboundExpectedDate <= required_by_date` (or any inbound if no date provided).
5. If on-hand + qualifying inbound >= quantity, return a split-shipment plan: ship available now from on-hand locations, then ship the rest from the inbound location on its expected date.
6. If still insufficient, return a `cannot_fulfill` status with the shortfall amount and the next inbound date.

**Output**:
```ts
{
  itemNo: string,
  requestedQuantity: number,
  status: 'fulfillable_now' | 'fulfillable_with_split_shipment' | 'cannot_fulfill',
  totalAvailableNow: number,
  shipmentPlan: Array<{
    sourceLocation: string,
    quantity: number,
    shippingDate: string,  // today or InboundExpectedDate
    isInbound: boolean
  }>,
  shortfall?: number,  // only if cannot_fulfill
  nextInboundDate?: string  // only if cannot_fulfill but inbound exists later
}
```

For the demo, the canonical run is `{ item_no: '1900-S', quantity: 500, required_by_date: <next Friday> }`. Expected output: status `fulfillable_with_split_shipment`, 300 from MAIN today, 150 from EAST today, 50 from WEST in 3 business days.

# Configuration

Use environment variables, loaded with `dotenv`. Generate a `.env` file populated with the demo values below so the server runs immediately after scaffold.

Required vars and their demo values:

```env
# Server
MCP_HTTP_PORT=8080
MCP_SERVER_NAME=mcp-cronus
MCP_SERVER_VERSION=1.0.0

# Database
DB_SERVER=YOUR-SQL-SERVER-NAME
DB_DATABASE=Cronus
DB_USER=sa
DB_PASSWORD=YourStrongPasswordHere
DB_PORT=1433
DB_ENCRYPT=false
DB_TRUST_SERVER_CERTIFICATE=true
```

Important notes for the `mssql` connection config:
- `DB_SERVER` is the bare server name (`YOUR-SQL-SERVER-NAME`), the default instance, so no `\\INSTANCE` suffix.
- `DB_ENCRYPT=false` and `DB_TRUST_SERVER_CERTIFICATE=true` are correct for a local SQL Server that has not been configured with a certificate. These settings would be wrong for production; document this in the README.

# MCP Server Implementation Pattern

**This is critical for Copilot Studio compatibility.**

The server MUST use this pattern in `src/index.ts`:

```typescript
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";

// Define tools array with MCP Tool schema
const TOOLS: Tool[] = [
  {
    name: "tool_name",
    description: "Tool description",
    inputSchema: {
      type: "object",
      properties: { /* ... */ },
      required: ["param1"],
    },
  },
  // ... more tools
];

// Create server function (called fresh for each request)
function createServer(): Server {
  const server = new Server(
    { name: "mcp-cronus", version: "1.0.0" },
    { capabilities: { tools: {} } }
  );

  // Register tool listing handler
  server.setRequestHandler(ListToolsRequestSchema, async () => {
    return { tools: TOOLS };
  });

  // Register tool execution handler
  server.setRequestHandler(CallToolRequestSchema, async (request) => {
    const { name, arguments: args } = request.params;
    // Dispatch to appropriate handler based on name
    // Return { content: [{ type: "text", text: JSON.stringify(result) }] }
  });

  return server;
}

// MCP endpoint handler (stateless - new server per request)
app.all("/mcp", async (req: Request, res: Response) => {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,  // STATELESS MODE - required for Copilot Studio
  });

  const server = createServer();
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});
```

**Why stateless mode?** Copilot Studio does not maintain MCP sessions. Each request must be self-contained. Setting `sessionIdGenerator: undefined` disables session tracking.

# Running and Exposing the Server

This is a local-only server. There is no Dockerfile, Bicep, or deployment script. To make the server reachable from Copilot Studio, expose it through a **VS Code Dev Tunnel**.

One-time setup (presenter does this once, before any rehearsal):

1. Install the Dev Tunnels CLI: `winget install Microsoft.devtunnel` on Windows.
2. Sign in: `devtunnel user login` (uses your Microsoft account).
3. Create a persistent named tunnel: `devtunnel create mcp-cronus`.
4. Add a port mapping: `devtunnel port create mcp-cronus -p 8080`.
5. **Enable anonymous access**: `devtunnel access create mcp-cronus --anonymous`. This is required for Copilot Studio to connect.
6. Note the tunnel's stable URL. It looks like `https://<tunnel-id>-8080.usw3.devtunnels.ms`. The tunnel ID is assigned by Azure.

**Important**: The `--anonymous` flag is critical. Without it, Copilot Studio cannot connect to the MCP server and you will see "Unauthorized" errors in Copilot Studio when adding the MCP connector.

Day-of-demo startup (one terminal per process):

1. Terminal 1: `cd mcp-cronus && npm start`. Server logs show tool calls in real-time. Keep this visible during Demo 3.
2. Terminal 2: `devtunnel host mcp-cronus`. The tunnel attaches to the local port 8080 and stays up until you Ctrl+C.

The README should make all of this clear, including a one-line smoke test:

```bash
# Health check
curl https://<your-tunnel-url>/health
# expects: {"status":"ok","server":"mcp-cronus"}

# MCP tools list (initialize first, then list)
curl -X POST https://<your-tunnel-url>/mcp \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}'
```

# Quality Requirements

- All tool inputs validated with zod before any DB call.
- All DB queries use parameterized inputs (the `mssql` package's `.input()` method). Never string-concatenate user input into SQL.
- The connection pool is created once at startup and reused.
- Every tool returns a JSON object with `success: true/false` and either the data or an `error` message.
- Errors thrown by tool handlers are caught at the dispatcher level and converted to MCP error responses; the server never crashes on a bad tool call.
- A `/health` endpoint that returns `{"status":"ok","server":"mcp-cronus"}`. Use this to verify the server is running before the live demo.
- CORS enabled for all origins (required for Copilot Studio).

# package.json

Generate a `package.json` with these dependencies:

```json
{
  "name": "mcp-cronus",
  "version": "1.0.0",
  "type": "module",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^5.0.0",
    "mssql": "^10.0.2",
    "zod": "^3.23.8"
  },
  "devDependencies": {
    "@types/cors": "^2.8.17",
    "@types/express": "^5.0.0",
    "@types/node": "^20.11.0",
    "typescript": "^5.3.3"
  }
}
```

# README Content

Generate a README.md covering:
- One-paragraph overview of what the server is for
- Prerequisites: Node 20+, local SQL Server with the `Cronus` database seeded, mixed-mode auth enabled, `sa` login enabled with password `YourStrongPasswordHere`
- Local development setup (`npm install`, `npm run build`, `npm start`)
- How to test a tool call locally with curl (include a curl example for the MCP endpoint)
- VS Code Dev Tunnel setup (mirror the one-time and day-of steps from the section above)
- **Important**: Emphasize that `devtunnel access create mcp-cronus --anonymous` is required for Copilot Studio connectivity
- How to configure Copilot Studio to register this MCP server as a custom connector, using the tunnel URL + `/mcp` as the endpoint
- A short "Tools reference" section listing all 8 tools
- A "Production caveats" callout listing what you would change for a non-demo deployment: re-enable encryption, use a non-`sa` login with least-privilege grants, add authentication, host the server somewhere persistent

# Acceptance Criteria

After scaffolding, the project should:
1. Build cleanly with `npm install && npm run build` with zero TypeScript errors.
2. Start locally with `npm start`. With SQL Server running and the `Cronus` database seeded, the `/health` endpoint returns `{"status":"ok","server":"mcp-cronus"}`.
3. Pass a smoke test against localhost: `curl -X POST http://localhost:8080/mcp -H "Content-Type: application/json" -H "Accept: application/json, text/event-stream" -d '{"jsonrpc":"2.0","id":1,"method":"initialize",...}'` returns the server info.
4. Pass the same smoke test against the dev tunnel URL once the tunnel is hosting with anonymous access enabled.
5. Execute the canonical demo queries against the seeded `Cronus` database:
   - `search_customer({query: "Adatum"})` returns 2 results: Adatum Corporation (10000) and Adatum Holdings, Inc. (10095).
   - `get_customer_details({customer_no: "10000"})` returns full customer card.
   - `get_credit_profile({customer_no: "10000"})` returns credit profile with utilization percentage.
   - `calculate_credit_exposure({customer_no: "10000", order_amount: 15000})` returns projected exposure and recommendation.

# What NOT to generate

- Do not implement write operations on any of the six tables. This server is read-only.
- Do not generate unit test scaffolding in this pass (we will add tests in a follow-up).
- Do not generate front-end code. There is no UI.
- Do not generate any Dockerfile, container build script, Bicep, Terraform, or Azure CLI deployment script. This server runs locally only.
- Do not use the `McpServer` class from the SDK - it does not work with Copilot Studio. Use the lower-level `Server` class with `setRequestHandler`.
- Do not implement API key authentication - Copilot Studio's MCP connector does not support custom headers.
- Do not embed credentials anywhere except the `.env` file. The `.env` file should be added to `.gitignore`.

---

# Key Learnings for Copilot Studio MCP Integration

These patterns were discovered through trial and error and are critical for success:

1. **Use `Server` class, not `McpServer`**: The higher-level `McpServer` class does not expose tools correctly to Copilot Studio. Use the lower-level `Server` class with explicit `setRequestHandler(ListToolsRequestSchema, ...)` and `setRequestHandler(CallToolRequestSchema, ...)`.

2. **Stateless transport mode**: Set `sessionIdGenerator: undefined` when creating `StreamableHTTPServerTransport`. Copilot Studio does not maintain MCP sessions.

3. **Fresh server per request**: Create a new `Server` instance and `StreamableHTTPServerTransport` for each incoming request to `/mcp`. Do not share transport instances.

4. **Anonymous tunnel access required**: The `devtunnel access create <name> --anonymous` command is required. Without it, Copilot Studio receives "Unauthorized" errors when trying to add the MCP connector.

5. **No API key auth**: Copilot Studio's MCP connector cannot send custom headers. Remove any API key middleware.

6. **CORS required**: Enable CORS for all origins. Copilot Studio needs this.

7. **MCP endpoint path**: The endpoint should be at `/mcp` (e.g., `https://<tunnel-url>/mcp`).

---

Once scaffolding completes, verify `npm install && npm run build` succeeds with zero errors before testing.
