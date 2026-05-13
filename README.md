# Multi-Agent Orchestration: Building an AI workforce with Copilot Studio

Session materials for DynamicsCon 2026, Las Vegas.

**Speaker**: Mariano Gomez, Microsoft Business Applications MVP, CPTO at Mekorma

This repository contains the complete artifact set behind the session: data scripts, the MCP server scaffolding prompt, Copilot Studio agent specs, minute-by-minute demo scripts, the session agenda, and slides. Everything you saw on stage is here, and everything you need to rebuild it on your own machine is documented end-to-end.

## What's in this repo

| File | What it is |
|---|---|
| `01-local-sql-server-schema-and-seed.sql` | Creates the `Cronus` database and seeds the six tables that drive every demo. CRONUS USA, Inc. shaped data including the Adatum duplicate trap and the inventory state that produces the 300+150+50 split shipment. |
| `02-mcp-server-scaffolding-prompt.md` | The exact prompt to paste into GitHub Copilot Agent Mode to scaffold a working TypeScript MCP server with 8 tools, backed by the local SQL Server, hardened for Copilot Studio compatibility. |
| `03-copilot-studio-agent-specs.md` | Configuration for the four agents in the workforce: Sales Specialist, Finance Specialist, Inventory Specialist, and Order Conductor. System instructions, tool registrations, and connected-agent descriptions for each. |
| `04-demo-scripts.md` | Minute-by-minute scripts for all three live demos including narration, pre-session checklist, and recovery plans. |
| `05-session-agenda.md` | One-page conference companion: audience description, timed outline, three takeaways, scenario quick reference. |
| `06-slide-deck-dynamicscon-template.pptx` | The deck as presented at DynamicsCon 2026, on the official conference template. |
| `06-slide-deck.pptx` | Same content on a neutral dark/amber template, suitable for reuse at other conferences. |
| `07-order-assistant-naive-build.md` | Build guide for the deliberately-naive single agent used in Demo 1 to demonstrate why architectural discipline matters. |

## Replicating the demo

You will need:

- Microsoft SQL Server, any edition (Developer or Express work fine) on a local machine
- Node.js 20 or higher
- GitHub Copilot (for scaffolding the MCP server) or any agent-capable IDE
- VS Code with the Dev Tunnels CLI installed
- Microsoft Copilot Studio access in a tenant where you can publish agents to Teams

Order of operations:

1. Run the SQL script to create the `Cronus` database and seed the data.
2. Paste the scaffolding prompt into GitHub Copilot Agent Mode to generate the MCP server.
3. Configure your `.env` file with your SQL Server name and credentials. **Use a real password; the artifacts show `YourStrongPasswordHere` as a placeholder.**
4. Create a persistent VS Code Dev Tunnel and host it.
5. Register the MCP server in Copilot Studio using the tunnel URL plus `/mcp` as the path.
6. Build the four workforce agents from the specs in artifact #3.
7. Build the naive Order Assistant from artifact #7.
8. Walk through the demo scripts in artifact #4.

Total build time from a clean machine: about 3-4 hours, most of it spent on the agent system instructions and rehearsing the demo flow.

## Placeholders to replace

Several files contain placeholders that you need to replace with values from your own environment:

| Placeholder | Replace with |
|---|---|
| `YOUR-SQL-SERVER-NAME` | The name of your local SQL Server machine (e.g., your laptop's hostname for a default instance) |
| `YourStrongPasswordHere` | A strong password for the `sa` login (or use Windows auth and adjust the MCP server's connection config) |
| `<tunnel-id>` in the example dev tunnel URLs | Your actual VS Code Dev Tunnel ID |
| `[your-repo]` on slide 23 | Your fork of this repository |
| `[your-handle]` on slide 23 | Your LinkedIn handle |

## License and reuse

These materials are provided for educational use. Feel free to fork, adapt, and present variations of this session at your own conferences and meetups. Attribution is appreciated but not required.

If you build something interesting on top of this, I would love to hear about it.

## Contact

https://www.linkedin.com/in/marianogomezbent/ 
