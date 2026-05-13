# Session Agenda
## Multi-Agent Orchestration: Building an AI workforce with Copilot Studio

**Conference**: DynamicsCon 2026, Las Vegas
**Speaker**: Mariano Gomez, Microsoft Business Applications MVP, CPTO at Mekorma
**Duration**: 60 minutes
**Format**: Live demonstrations with architectural narration

---

## Audience-Facing Description

Organizations are moving beyond single-purpose agents to create entire AI workforces that collaborate like human teams. In this practical, code-forward session, we will design, build, and stress-test a four-agent system that handles real B2B order qualification on Business Central data: a generative orchestrator coordinating Sales, Finance, and Inventory specialists, all sharing knowledge through an MCP server backed by SQL Server. Three live demonstrations escalate from a single agent failing on a duplicate customer record, to a two-agent handoff with honest lane discipline, to the full workforce returning a synthesized order recommendation with concrete credit math and a split-shipment plan. You will walk away with a working architectural pattern, a clear decision framework for when multi-agent is the right answer (and when it is not), and the underlying code and prompts you can adapt on Monday.

---

## Timed Outline

| Time         | Beat                          | Key Takeaway                                                              |
|--------------|-------------------------------|---------------------------------------------------------------------------|
| 0:00 to 0:05 | **Provocation**               | Maria's three-window problem. The single-agent trap. The conductor reframe. |
| 0:05 to 0:10 | **Foundations**               | Agent vs multi-agent. Orchestration vs choreography. Where this lives in Copilot Studio. |
| 0:10 to 0:15 | **Decision Framework**        | Three signals for multi-agent. Three counter-signals. Most teams should start with one agent. |
| 0:15 to 0:22 | **Demo 1: The Limitation**    | Single agent with every tool fails on a duplicate customer record. The architecture, not the model, is the problem. |
| 0:22 to 0:34 | **Demo 2: Specialization**    | Sales plus Finance with explicit handoff. Lane discipline in the Copilot Studio designer. Orchestration vs choreography in practice. |
| 0:34 to 0:50 | **Demo 3: The Workforce**     | Full four-agent system. Headline credit math (46.40% to 84.40%). Split-shipment plan. Curtain pull on MCP server and local SQL Server. |
| 0:50 to 0:55 | **Patterns and Production**   | Four reusable architectural patterns. Cross-platform AI extension. Governance, cost, latency, audit. |
| 0:55 to 1:00 | **The Mindset and Close**     | Conductor not coder. Four concrete Monday-morning actions. Q&A. |

---

## Three Things Attendees Walk Away With

1. **A working architecture**: a four-agent design pattern they can copy on Monday. Orchestrator plus three specialists plus a shared knowledge layer through MCP, with each piece doing exactly one job.
2. **A decision framework**: clear signals for when multi-agent is the right answer, and when one agent or a Power Automate flow is the honest choice. Most teams in the room should not build multi-agent yet, and the session is explicit about that.
3. **A live build, end-to-end**: three demos showing the architecture under load on Business Central-shaped data, with the curtain pulled back on the MCP server code, the SQL Server database, and the Copilot Studio orchestration trace.

---

## What is Different About This Session

Most multi-agent sessions stop at the conceptual diagram. This one builds the thing on stage, against a database the audience can read, with prompts they can copy. The audience leaves with running code patterns, not slideware.

Most multi-agent sessions are also evangelistic. This one is explicit that most enterprise scenarios should be a single well-prompted agent or a Power Automate flow. The decision framework beat takes five full minutes and includes three reasons to NOT build this. That honesty is the session's strongest credibility move.

---

## Demo Architecture (Quick Reference)

- **Scenario**: Maria, an Inside Sales Manager at CRONUS USA, qualifying a $95K order from Adatum Corporation for 500 units of 1900-S PARIS Guest Chair, shipping next Friday, on NET-30 terms.
- **Agents**: Order Conductor (orchestrator, generative) + Sales Specialist + Finance Specialist + Inventory Specialist, plus one deliberately naive Order Assistant used only in Demo 1.
- **Data**: Mocked BC-shaped data in a local SQL Server database `Cronus` on the demo laptop (Customers, CreditProfiles, Products, Inventory, Pricing, OrderHistory). Built-in disambiguation trap: Adatum Corporation at 10000 plus a duplicate Adatum Holdings, Inc. at 10095.
- **MCP server**: TypeScript, running locally on the demo laptop and exposed to Copilot Studio through a persistent VS Code Dev Tunnel. Exposes 8 read-only tools across customer, credit, and inventory domains.
- **Surface**: Order Conductor published to Microsoft Teams, specialists internal-only.

---

## Speaker Bio (50 words)

Mariano Gomez is Chief Product and Technology Officer at Mekorma and a Microsoft Business Applications MVP. He builds and ships AI-first development practices across Dynamics 365 and Power Platform, focused on agent architecture, MCP integration, and helping enterprise teams make sound trade-offs between cutting-edge AI patterns and operational reality.

---

## Companion Materials

This session ships with a complete artifact set available at the speaker's GitHub repository:

- SQL Server schema and seed data script
- GitHub Copilot scaffolding prompt for the MCP server
- Copilot Studio agent design specs (four agents)
- Minute-by-minute demo scripts with recovery plans
- This slide deck

All materials are licensed for reuse and adaptation.
