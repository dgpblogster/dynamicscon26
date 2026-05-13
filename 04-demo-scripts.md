# Demo Scripts
## DynamicsCon 2026 — Multi-Agent Orchestration with Copilot Studio

---

## Pre-Session Checklist

Have these open and tested before you walk on stage. Numbers are tab/window positions, left to right. Keep them in this order so you can swipe through predictably.

**Local services running on the demo laptop (start these first):**

- **SQL Server** service running on `YOUR-SQL-SERVER-NAME` (default instance, MSSQLSERVER). Verify in SSMS that you can connect as `sa` / `YourStrongPasswordHere` and run `SELECT COUNT(*) FROM Cronus.dbo.Customers` (expect 6).
- **Terminal 1: MCP server**. Inside the `mcp-cronus` folder, run `npm run build && npm start`. Server log lines should scroll on startup ("Connected to SQL Server", "MCP server listening on port 8080"). Leave this terminal visible; you will reference it during Demo 3.
- **Terminal 2: Dev Tunnel**. Run `devtunnel host mcp-cronus`. The tunnel URL prints on connect (`https://<tunnel-id>-8080.usw3.devtunnels.ms` or similar). Smoke test it: `curl https://<tunnel>/health` returns `{"status":"ok","server":"mcp-cronus"}`. Leave this terminal running.

**Tabs and windows:**

1. **Microsoft Teams**, logged in as the demo tenant, with a chat already opened to Order Assistant (Demo 1's naive agent).
2. **Microsoft Teams** (second tab or second window), with a chat already opened to Order Conductor (Demo 2 and Demo 3's orchestrator).
3. **Copilot Studio**, opened to the Sales Specialist agent in the designer view. Topics and tools panel visible.
4. **Copilot Studio** (second tab), opened to the Order Conductor agent, with the Connected Agents panel visible.
5. **VS Code**, with the MCP server project open, `src/tools/check_availability.ts` already visible in the editor. Terminal 1 (the running MCP server) should be the active terminal pane so you can switch to it with one click during Demo 3.
6. **SQL Server Management Studio**, connected to `YOUR-SQL-SERVER-NAME` as `sa`. The query window has query #7 from the seed script pasted in (the credit exposure calculation), but not yet executed. Database context set to `Cronus`.
7. **Slide deck**, on the slide that opens Demo 1.

Run through all tabs and terminals once before going live. If the dev tunnel went idle, restart `devtunnel host mcp-cronus`. If `npm start` shows a SQL connection error, the most common cause is SQL Server not running on the laptop (`net start MSSQLSERVER` from an elevated cmd fixes it).

---

## Quick-Reference Timeline

| Time   | Beat            | Demo / Activity                                          |
|--------|-----------------|----------------------------------------------------------|
| 0:00   | Provocation     | Open story, single-agent trap                            |
| 0:05   | Foundations     | Definitions, topology, where in Copilot Studio           |
| 0:10   | Decision frame  | When NOT to use multi-agent                              |
| 0:15   | Demo 1          | The limitation: single agent fails                       |
| 0:22   | Demo 2          | Sales plus Finance, with handoff                         |
| 0:34   | Demo 3          | Full workforce plus MCP curtain pull                     |
| 0:50   | Patterns        | Architectural recap, Claude tangent, production notes    |
| 0:55   | Close           | Mindset, Monday morning ask, Q&A                         |

Demos start at 0:15 and run for 35 minutes through 0:50.

---

# Demo 1 — The Limitation (7 minutes, 0:15 to 0:22)

## What This Demo Has To Land

A single Copilot Studio agent with every tool available is fragile. Not because the model is dumb, but because there's no architectural discipline keeping it inside lanes. The audience needs to feel the fragility, not just hear about it.

## The Setup Agent: "Order Assistant"

A deliberately-naive single agent that you build solely for this demo. Its design is the point.

- **Display name**: Order Assistant
- **Published to**: Microsoft Teams
- **Tools registered**: all 8 MCP tools (search_customer, get_customer_details, get_customer_pricing, get_order_history, get_credit_profile, calculate_credit_exposure, get_inventory, check_availability)
- **Knowledge sources**: none
- **System instructions** (paste this verbatim, deliberately thin):

```
You help the CRONUS USA sales team qualify orders. You have access
to customer, credit, inventory, and pricing data. Answer questions
about whether we can commit to orders.
```

That is the entire prompt. No disambiguation guidance. No tool preferences. No output format. No "always use this for that." This is exactly what most teams ship in their first internal pilot.

## Demo 1 Script

### 0:15:00 — Open the demo (60 seconds)

Tab to Teams (tab 1), Order Assistant chat is empty and waiting.

> **Narration**: "Before I show you the workforce, let me show you what most teams build first and ship to production thinking they're done. I built this agent yesterday. It has access to every tool we just talked about. Customers, credit, inventory, pricing. Watch what happens when Maria, our Sales Manager, asks the qualifying question she asks ten times a day."

### 0:16:00 — Type the canonical question (60 seconds)

In the Order Assistant chat, type this prompt exactly:

```
Adatum wants 500 units of 1900-S PARIS Guest Chair, black,
shipping next Friday, on NET-30 terms. Can we commit?
```

Hit send. Let it think.

> **Narration while it's thinking**: "There are two Adatums in our customer master. One is the real account. One is a duplicate someone created in 2023 and never cleaned up. Most BC tenants have this exact problem. Watch how the agent handles it."

### 0:17:00 — Walk through the response (2 minutes)

The agent's response will vary run-to-run. Here are the three most likely failure modes. Be ready to narrate whichever one shows up.

**Failure mode A: agent picks the wrong Adatum (10095) and proceeds confidently.**

If the response talks about Adatum at customer 10095 with no credit history, or says something like "Adatum Holdings has plenty of available credit," this is the wrong-customer trap.

> **Narration**: "Notice it didn't ask which Adatum. It picked one and moved on. And it picked the duplicate, the one with no credit profile and no order history, because the duplicate is newer and the model treats newer as fresher. So now Maria has a green light from the agent on a customer record that should have been merged out of existence months ago."

**Failure mode B: agent picks the right Adatum (10000) but uses the wrong inventory tool.**

If the response correctly identifies 10000 and gives some credit answer, but for inventory says something like "We have 300 units in MAIN, 150 in EAST, and 50 inbound to WEST," that's get_inventory output, not check_availability output. Raw data without a plan.

> **Narration**: "It identified the customer correctly this time, but look at inventory. It's reading me the raw stock numbers from each warehouse. That's not what Maria asked. Maria asked if we can commit. The agent has a tool that produces a shipment plan, but it picked the simpler tool and dumped data instead of giving an answer."

**Failure mode C: agent gives a confident but incomplete answer.**

If the response sounds clean but is missing one of the three domains, or stitches together inconsistent pieces (right credit math but wrong customer name, for instance), use this narration.

> **Narration**: "Look at this confidently. It's giving Maria a recommendation. But notice what's missing: it never disambiguated the customer, the credit math is for one Adatum and the order history is for the other, and the inventory plan doesn't account for the required ship date. Every individual step succeeded. The system as a whole produced something dangerous to act on."

### 0:19:00 — Try a clarifying follow-up (90 seconds)

Type this to expose another failure mode:

```
Which Adatum did you check? And can we actually ship 500 units
by next Friday?
```

The agent will scramble. It may apologize, swap to the other Adatum, give a different answer, or contradict its first response.

> **Narration**: "And here's what happens when Maria pushes back. The agent recovers, sort of, but its second answer doesn't match its first. Which one does she trust? She can't. She still has to open three windows."

### 0:20:30 — Land the lesson (90 seconds)

Tab to slide deck (tab 7). Advance to the Demo 1 wrap slide.

> **Narration**: "This is not a bad agent. This is a generalist with every tool, no architectural discipline, and a permissive prompt. It will succeed often enough in testing to ship to production, and then it will fail visibly in front of the CFO. The issue isn't the model. The issue is that we asked one entity to be expert at three different domains. Let me show you the alternative."

Transition to Demo 2.

## Demo 1 Recovery Plan

If the agent gets the answer mostly right (which happens roughly one in five runs), pivot to:

> "And sometimes you get lucky. This is what makes single-agent systems so insidious. They work eight times out of ten in testing, and then on demo day in front of the CFO they fall apart. Predictability is what separates demos from production."

Then move on. Do not re-run the prompt hoping for a failure. Once you've narrated the "sometimes you get lucky" angle, the lesson is landed.

---

# Demo 2 — Sales Plus Finance, With Handoff (12 minutes, 0:22 to 0:34)

## What This Demo Has To Land

Splitting work across specialist agents gives you predictability and lane discipline. The orchestrator pattern (one conductor invoking many specialists) is a real architectural choice with tradeoffs versus peer-to-peer handoff. The audience sees the mechanics in the Copilot Studio designer, not just in chat.

## Pre-State

- Sales Specialist built, tools registered, tested.
- Finance Specialist built, tools registered, tested.
- Order Conductor built with **only two** connected agents: Sales and Finance. Inventory is **not yet connected**.
- Teams chat with Order Conductor is open and empty (tab 2).

## Demo 2 Script

### 0:22:00 — Transition narration (45 seconds)

Tab to slide deck. Advance to the Demo 2 setup slide showing two agents and a conductor.

> **Narration**: "What if we split the work the way a real team would? Sales does what Sales knows. Finance does what Finance knows. A conductor coordinates. Let's see what changes."

### 0:22:45 — Open Order Conductor and type the prompt (90 seconds)

Tab to Teams Order Conductor (tab 2). Type:

```
Adatum Corporation wants 500 units of 1900-S PARIS Guest Chair,
black, shipping next Friday, on NET-30 terms. Can we commit?
```

> **Narration while it's thinking**: "Same question. Same data. Different architecture. Watch what comes back."

### 0:24:15 — Walk through the response (90 seconds)

The orchestrator should route to Sales first (which disambiguates to 10000), then to Finance (which returns AUTOMATIC_APPROVAL with the math). It cannot route to Inventory because Inventory is not connected yet. The synthesized response will look something like:

> "I have the customer and credit picture for you, but I can't confirm inventory yet because I don't have an Inventory specialist connected. Adatum Corporation (10000) is a Gold-tier customer with orders trending up sharply. Credit is clean: current utilization 46.40%, projected 84.40% after this order, just under your 85% CFO review threshold. To confirm we can ship 500 units by next Friday, I need to check inventory."

Point at the screen.

> **Narration**: "Notice three things. First, it disambiguated to Adatum Corporation 10000 with no help from me, because Sales has explicit disambiguation logic baked into its instructions. Second, the credit math is concrete and explained: 46.40, 84.40, 85.00. Maria can verify on the slide. Third, and this is the honest part, it didn't make up an inventory answer. It told me what it doesn't know. That's a feature of lane discipline."

### 0:25:45 — Pull the curtain on the Sales Specialist (2 minutes)

Tab to Copilot Studio (tab 3), Sales Specialist designer view.

> **Narration**: "Let me show you what's actually happening. This is the Sales Specialist. Look at its tools."

Point to the tools panel. The four tools are visible: search_customer, get_customer_details, get_customer_pricing, get_order_history.

> **Narration**: "Four tools. Customer-shaped tools only. No credit tools. No inventory tools. This agent literally cannot answer a credit question because it doesn't have the capability registered. That's the discipline."

Click into the agent's instructions field. Scroll to the disambiguation logic.

> **Narration**: "And here's the disambiguation logic. Plain English. If multiple matches, look at created date, look at modified date, look at which fields are populated. That's what produced the Adatum Corporation answer. Not magic. Not a model upgrade. Just clear instructions to a specialized agent."

### 0:27:45 — Show the Order Conductor topology (2 minutes)

Tab to Copilot Studio (tab 4), Order Conductor designer view, Connected Agents panel.

> **Narration**: "Now this is the conductor. Look at its tools panel: zero MCP tools. The conductor doesn't talk to the database at all. Look at its Connected Agents: Sales Specialist, Finance Specialist. The conductor's job is to decide who to ask and how to combine the answers. That's it."

Open the orchestration history or trace from the previous run (Copilot Studio shows recent reasoning steps).

> **Narration**: "And here's what the conductor actually did just now. It read the prompt, decided this question needs customer identity and credit assessment, called Sales, got a customer number, called Finance with that customer number and the order amount Sales calculated from the negotiated price, got a recommendation, and synthesized. Generative orchestration. No hardcoded routing."

### 0:29:45 — The architectural decision (2 minutes)

Tab back to slide deck. Advance to the slide comparing orchestrator pattern versus peer-to-peer handoff.

> **Narration**: "We made an architectural decision here that's worth naming. We chose an orchestrator pattern. One conductor, many specialists, conductor synthesizes. The alternative is peer-to-peer handoff: Sales finishes its work and hands off directly to Finance, Finance hands off to Inventory, the last specialist returns to the user."

Walk through the tradeoff visually on the slide.

> **Narration**: "Orchestrator pattern is easier to reason about, easier to debug, and concentrates the synthesis logic in one place. Peer-to-peer is more flexible and can handle dynamic workflows, but you lose the single source of truth for what just happened. For order qualification, where the question is always shaped the same way, the orchestrator is the right call. For something like customer service triage where the path branches unpredictably, peer-to-peer is often better. Use the framework on the slide to decide."

### 0:31:45 — Wrap Demo 2 and tee up Demo 3 (90 seconds)

> **Narration**: "We've got customer and credit. We're missing inventory. Let's add the third specialist and see what the complete workforce produces."

Tab to slide deck. Advance to the Demo 3 setup slide.

## Demo 2 Recovery Plan

If the orchestrator does not route correctly (e.g., it tries to call Finance before Sales has resolved the customer), narrate the issue and run it again. The recovery posture is "this is generative orchestration, it's probabilistic, and the playbook is to constrain the instructions until it routes the same way every time."

If Sales returns the wrong Adatum, narrate it as "the instructions aren't tight enough yet, this is exactly the kind of tuning you do during the build." Then move to the curtain-pull. The audience learns just as much from a near-miss as from a clean run.

---

# Demo 3 — The Full Workforce With MCP (16 minutes, 0:34 to 0:50)

## What This Demo Has To Land

The complete workforce produces a single coherent answer with all three domains covered. The MCP server makes this possible by providing structured tools that the agents share. Pulling the curtain back on the MCP server and the database is the architectural payoff of the whole session.

## Pre-State

- All three specialists built and connected to Order Conductor.
- MCP server running locally in Terminal 1 (`npm start`), connected to SQL Server.
- Dev tunnel hosting in Terminal 2 (`devtunnel host mcp-cronus`), URL reachable.
- Cronus database populated with the seed data.
- Teams Order Conductor chat is fresh (clear the previous turn or open a new conversation).

## Demo 3 Script

### 0:34:00 — Transition narration (45 seconds)

> **Narration**: "I've connected the Inventory Specialist. Same conductor, same Sales, same Finance, plus one more agent who knows stock and shipment planning. Let's run the question one more time."

### 0:34:45 — Type the canonical question (90 seconds)

Tab to Teams Order Conductor (tab 2). Type:

```
Adatum Corporation wants 500 units of 1900-S PARIS Guest Chair,
black, shipping next Friday, on NET-30 terms. Can we commit?
```

> **Narration while it's thinking**: "Same prompt. Same data. Full workforce. Listen for the headline first, then the supporting math."

### 0:36:15 — Walk through the synthesized response (2 minutes)

Expected response, paraphrased:

> "Yes, commit. Adatum Corporation (10000) is a Gold-tier customer with orders trending up sharply over the last six months. Credit is clean: current utilization 46.40%, projected 84.40% after this order, just under your 85% CFO review threshold. Inventory plan: 300 units from MAIN today, 150 units from EAST today, and 50 units from WEST in 3 business days when inbound stock arrives. Recommend confirming the order with a split shipment."

Read it slowly. Let it land.

> **Narration**: "Yes, commit. Customer identified. Credit math explained. Inventory plan with three concrete shipment legs. One question, one coherent answer, 120 words, three domains. This is what Maria needed and couldn't get from her three windows. The conductor did the synthesis. Each specialist contributed its expertise. Nobody made anything up."

### 0:38:15 — Pull the curtain on the Inventory Specialist (90 seconds)

Tab to Copilot Studio. Navigate to the Inventory Specialist agent.

> **Narration**: "Two tools. get_inventory, check_availability. That's it. And the instructions tell it: if there's a date involved, always use check_availability, because check_availability returns a plan, not just numbers. Same discipline as Sales and Finance."

### 0:39:45 — Pull the BIG curtain: the MCP server (3 minutes)

Tab to VS Code (tab 5). `src/tools/check_availability.ts` should be visible. Glance at Terminal 1 inside VS Code: log lines from the most recent tool calls are scrolling there.

> **Narration**: "Here's where the real work happens. This is check_availability, the tool the Inventory Specialist called. It's TypeScript running on this laptop, right here, in this VS Code window. It queries the local SQL Server I have running underneath, looks at on-hand stock by location, looks at inbound stock with expected dates, builds a split shipment plan."

Point at Terminal 1 logs scrolling at the bottom of the screen.

> **Narration**: "Those log lines you see there, that's every tool call the agents just made, with timing. Copilot Studio reached this laptop through a dev tunnel: the orchestrator made a routing decision, called the Inventory Specialist, the Inventory Specialist called check_availability, this MCP server queried SQL Server, came back with the plan. The whole round trip is in those logs."

Scroll through the function. Pause on the split-shipment logic.

> **Narration**: "This is where the 300 plus 150 today plus 50 in three days comes from. Not from the agent. From this code. The agent is calling a smart tool. That's the architectural pattern: smart tools, simple agents. The more capability you push into the MCP server, the more predictable your agents become, because the heavy lifting is deterministic TypeScript instead of probabilistic prompting."

Scroll to the top of the file, show the tool's schema definition (zod input, output type).

> **Narration**: "And every tool has a schema. Inputs validated. Outputs typed. The agent can't pass garbage to the database and get garbage back. That's the second piece: discipline at the tool boundary."

### 0:42:45 — Show the database (2 minutes)

Tab to SSMS (tab 6). Query editor is open with the credit exposure query already pasted, database context `Cronus`.

> **Narration**: "And here's our database. Local SQL Server on this laptop, CRONUS USA shaped data. Six tables. Customers, credit profiles, inventory, pricing, products, order history. Let me run the headline calculation directly."

Press F5 to execute. The result grid shows CurrentUtilizationPct 46.40, ProjectedUtilizationPct 84.40, Recommendation AUTOMATIC_APPROVAL.

> **Narration**: "There's the math the Finance Specialist returned. 46.40, 84.40, 85.00 threshold. The agent didn't compute this. The database did. The Finance Specialist's job is to know when to ask the database the right question, not to do arithmetic in a prompt."

### 0:44:45 — Topology recap (2 minutes)

Tab to slide deck. Advance to the topology slide (the diagram from the agent specs).

> **Narration**: "Let me recap what you just saw. User talks to the Order Conductor in Teams. Conductor decides which specialists to invoke. Specialists call MCP tools through a dev tunnel into this laptop. MCP tools query the local SQL Server. Three layers: orchestration, specialization, shared knowledge. Each layer has one job. Each layer can be tested independently. Each layer can be replaced without rewriting the others."

Pause. Let the diagram settle.

> **Narration**: "If you remember one thing from this session, remember the three layers. The temptation when you're building this is to flatten them. To put credit math in the agent prompt. To let the agent talk to the database directly. To skip the conductor and have agents call each other directly. All of those flattening moves work in demos and fail in production. Keep the layers."

### 0:46:45 — Generative orchestration moment (2 minutes)

Tab back to Copilot Studio Order Conductor view.

> **Narration**: "One more thing worth showing. The conductor uses generative orchestration. Look at its topics list. There's no topic that says 'when the user asks about an order, call Sales first.' That decision is made by the model at runtime, using the descriptions on the connected agents and the conductor's instructions. This is different from how Copilot Studio worked even a year ago. You used to have to draw the routing logic explicitly. Now you describe what each agent does in plain English and the orchestrator picks."

> **Narration**: "The tradeoff is predictability. Hardcoded routing is more deterministic and easier to debug. Generative routing is more flexible and handles unanticipated questions better. For new builds I would default to generative. For production-critical flows where the routing has to be the same every time, mix in explicit topics for the critical paths and let generative handle the rest."

### 0:48:45 — Production considerations preview (75 seconds)

Tab to slide deck. Advance to the production considerations slide.

> **Narration**: "Before we close I want to flag four things you have to think about before shipping multi-agent systems to production. Governance: who owns each specialist, who can change its prompt, who reviews its tools. Cost: every specialist call is a model call, and orchestrators multiply your calls. Latency: three specialists in series can easily double your response time, so design for parallel where possible. And audit: when a recommendation produces a bad business outcome, can you reconstruct which specialist returned what? Copilot Studio's tracing helps. Make sure you turn it on."

> **Narration**: "We'll come back to these in the close."

## Demo 3 Recovery Plan

If the synthesized response is significantly off (wrong split, wrong customer, missing math), pivot to a curtain-pull immediately. The audience learns just as much from seeing the architecture as from a perfect chat output. Narrate: "Live agents are probabilistic. Let me show you what's underneath so you can see why this works in aggregate even when individual runs vary."

If Teams fails (auth issue, network), pivot to the Copilot Studio test pane on tab 3 or 4 and run the same prompt there. Acknowledge the pivot: "Teams is being stubborn, let me run it from the designer pane, same orchestrator." The audience won't mind. They will mind a long silence while you reload Teams.

If the MCP server is down (terminal crashed, tunnel disconnected, SQL Server stopped), open the VS Code tab and walk through the code as if the live call didn't happen: "Imagine this just ran. Here's what produced that answer." the presenter's voice will carry it. Do not try to restart anything on stage. If recovery time permits between demos, the fix sequence is: SQL Server running first (`net start MSSQLSERVER` if needed), then `npm start` in Terminal 1, then `devtunnel host mcp-cronus` in Terminal 2, then re-test with the curl health-check before re-engaging Copilot Studio.

---

# Post-Demo Handoff to Beat 5

After the production considerations slide closes Demo 3, tab to slide deck and advance to the beat 5 opener.

> **Narration**: "Let's pull back and talk about patterns, where this goes next, and what to do on Monday morning."

Beat 5 follows: architectural patterns recap (with the Claude tangent), production considerations in detail, mindset shift, Monday morning ask, Q&A. Out of scope for this artifact.

---

# Rehearsal Protocol

This is the artifact you use during dress rehearsal. Run the demos at least three times before the conference, in this protocol:

**Rehearsal 1: clean run.** Type the canonical prompts, narrate everything, and see how close the agents come to the expected responses. Note any drift in the responses. Tune the agent instructions if needed.

**Rehearsal 2: failure injection.** Deliberately break things to test your recovery posture. Disconnect Inventory mid-Demo-3. Type a malformed customer name. Pass a quantity larger than total inventory. Make sure your "talk through it" recovery actually works.

**Rehearsal 3: full run with a timer.** Start a 35-minute timer at the beginning of Demo 1 and run all three demos back to back. Get under time on every demo, with two minutes of buffer total. If you're over, your narration is too long; tighten it.

**Day-of warm-up.** Two hours before the session, run the canonical Demo 3 prompt in Teams to verify everything is live. If it works, leave it alone. Do not "improve" anything on the day.

---

# What's Locked

Three demo scripts with exact prompts, expected responses, narration, curtain-pull sequence, and recovery plans. The Demo 1 single agent spec is included since it's not part of the production architecture. Rehearsal protocol is set.

# What's Next

Artifact #6: the full agenda plus slide deck. The agenda is straightforward once everything else is locked. The slide deck applies DynamicsCon visual branding to the structure we've built: provocation, foundations, decision framework, three demo intros and wrap slides, patterns recap, production considerations, close.
