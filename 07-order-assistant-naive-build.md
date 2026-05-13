# Artifact #7: Order Assistant (Naive Agent for Demo 1)

A standalone build guide for the deliberately-naive single agent used in Demo 1. This agent is separate from the four-agent workforce (Sales Specialist, Finance Specialist, Inventory Specialist, Order Conductor) and is only ever used during Demo 1. After Demo 1 ends, you never invoke this agent again.

The design is intentional. Its purpose is to fail in front of the audience in a way that justifies the architecture you build in Demos 2 and 3. Resist any urge to make it "better."

---

## Purpose in the Session Architecture

Demo 1's job is to make the audience feel the fragility of single-agent designs. Not hear about it. Feel it. The Order Assistant exists for exactly one prompt during the live session, produces a visibly flawed answer, and is then replaced by the multi-agent workforce for Demos 2 and 3.

The contrast is the whole point. If the Order Assistant succeeds, Demo 1 fails as a teaching moment. If it fails confidently and visibly, Demo 1 lands and the architectural pitch in Demos 2 and 3 has earned its setup.

---

## Agent Configuration

Build this in Copilot Studio as a separate agent from the four specialists. It must be its own agent, not a variation of the Order Conductor or any specialist.

- **Display name**: Order Assistant
- **Description** (shown in the agent picker, optional): "Helps the CRONUS USA sales team qualify orders."
- **Generative orchestration**: enabled (so the agent can choose tools at runtime)
- **Knowledge sources**: none
- **Connected agents**: none (this agent is alone; no Sales, no Finance, no Inventory)
- **Published to**: Microsoft Teams

### Tools

All 8 MCP tools from the Cronus MCP Server, registered on this single agent:

1. search_customer
2. get_customer_details
3. get_customer_pricing
4. get_order_history
5. get_credit_profile
6. calculate_credit_exposure
7. get_inventory
8. check_availability

This is the architectural mistake the demo is showing: a single agent with broad tool access and no domain discipline. Do not omit any tool. The agent's failure mode depends on having all of them available.

### System Instructions

Paste verbatim, deliberately thin:

```
You help the CRONUS USA sales team qualify orders. You have access
to customer, credit, inventory, and pricing data. Answer questions
about whether we can commit to orders.
```

That is the entire prompt. No disambiguation rules. No tool preferences. No output format. No "always use this for that." This is close to what many teams ship in their first internal pilot, which is exactly the demo's point.

### Topics

Leave all system topics at defaults. No custom conversation starter is needed.

---

## The Test Prompt

This is the exact prompt you will paste into the Teams chat during Demo 1:

```
Adatum wants 500 units of 1900-S PARIS Guest Chair, black,
shipping next Friday, on NET-30 terms. Can we commit?
```

Note that the question deliberately uses "Adatum" without specifying which one. The Cronus database has two Adatum records (10000 Adatum Corporation, 10095 Adatum Holdings Inc.) and the absence of disambiguation is part of what trips the agent up.

---

## Expected Failure Modes

The agent's response will vary run-to-run. The three most likely failure modes are all good for the demo. Each has narration in `04-demo-scripts.md`.

**A: Wrong customer (most likely)**

The agent picks Adatum Holdings (10095, the duplicate with sparse fields) instead of Adatum Corporation (10000, the canonical record) and proceeds confidently. Models often pick the newer record because newer feels fresher. The customer it picks has no credit history and no order pattern, so the resulting recommendation is built on missing data.

**B: Wrong tool**

The agent calls `get_inventory` (raw stock numbers by location) when it should have called `check_availability` (a fulfillment plan that accounts for the required-by date). The answer about whether you can ship by Friday is incomplete because the agent never checked the date constraint.

**C: Confident incomplete answer**

The agent synthesizes a recommendation without consulting one or more domains (e.g., reports inventory but never checks credit, or vice versa), or it fabricates a piece of information that no tool actually returned. The answer looks reasonable on first read but falls apart on inspection.

You don't need to know in advance which failure mode you'll get. The demo script has narration for all three. Whichever shows up, the architectural lesson is the same: one agent with all the tools and no discipline is not enough.

---

## Counterintuitive Build Notes

The hardest thing about building this agent is resisting the urge to improve it. If it returns a clean answer on the first try during rehearsal, the prompt is too tight, the tools are too narrow, or you got lucky. Make the instructions looser, not tighter. Specifically:

- If you find yourself wanting to add "always disambiguate when customer name is ambiguous," do not.
- If you find yourself wanting to add "for date-sensitive questions, use check_availability," do not.
- If you find yourself wanting to add an output format, do not.

The whole point is to show what naive looks like.

That said, naive is not the same as nonsensical. The instructions you have above ARE giving the agent everything it needs to attempt the task: domain context (CRONUS USA sales), tool access (all 8), and use case (qualify orders). What it is missing is lane discipline, and lane discipline is precisely what most first-pilot teams do not add because they do not yet know they need it.

---

## Pre-empting the "Strawman" Objection

A skeptical audience member may raise their hand: "That prompt is too short. No one ships an agent with two sentences of instructions."

This is a fair objection and worth pre-empting in your narration. Add roughly 15 seconds at the start of Demo 1 that names the elephant:

> "Before someone in the back raises their hand: yes, this prompt is short. I could make it 400 words. The failure modes you're about to see don't go away when I do that. They go away when I split this into specialists. The prompt isn't the problem. The architecture is. Let me prove it."

Three reasons this defense is honest, not spin:

1. Copilot Studio's default template for a new agent starts with one or two sentences. Most teams add their own context but not much architectural discipline.
2. The instructions ARE giving the agent everything it needs to know about the domain and use case. What is missing is structural separation, which a longer prompt does not provide.
3. The failure modes are not artifacts of prompt thinness. They are artifacts of single-agent design with broad tool access. A 400-word version of the same instructions would still fail, just more eloquently. You could prove this by running both side by side; the point would land the same way.

The deeper version of this objection is: "Are you stacking the deck by giving the naive agent a hard problem?" The answer is yes, but on purpose. The hard problem (a duplicate customer, a date-sensitive availability question, a credit math threshold) is exactly the kind of problem multi-agent orchestration is designed for. Easy problems do not need it. If you can articulate that during Q&A, the deeper objection is answered too.

---

## Pre-Session Verification

Before showtime, run the test prompt against the Order Assistant at least twice during rehearsal. You are looking for two things:

1. **It fails.** Any of the three failure modes is acceptable. If it succeeds, loosen the instructions further.
2. **It fails recognizably.** The audience needs to be able to identify the failure when you point it out. If the response is so muddled that even you cannot tell what went wrong, you may need to rephrase the prompt slightly so the failure surface is clearer.

If the agent stubbornly succeeds across multiple rehearsals, the most reliable lever is to remove the use-case framing entirely:

```
You help the CRONUS USA sales team. Answer their questions.
```

That version almost always fails in interesting ways.

---

## After Demo 1

Order Assistant is done after Demo 1's wrap. You will not invoke it again during Demos 2 or 3. The Teams tab for Order Assistant can stay open, but the focus shifts to the Order Conductor tab for the rest of the session.

The transition narration from Demo 1 to Demo 2 sets up the architecture you are about to build:

> "The problem was not the model. The problem was asking one entity to be expert at three different domains with no discipline about which tool fits which question. Let me add some lane discipline."

That line is what makes Demo 1's failure productive rather than discouraging.
