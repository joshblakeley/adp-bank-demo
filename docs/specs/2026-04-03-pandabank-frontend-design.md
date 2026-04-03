# PandaBank Frontend Design

## Goal

A simple web chat interface that lets conference attendees interact with the Redpanda ADP "Bank Internal Assistant" AI agent using natural language, via the A2A protocol.

## Architecture

A minimal Node.js/Express server acts as a proxy between the browser and the Redpanda agent (required to avoid CORS restrictions on direct browser-to-agent calls). The frontend is a single HTML file with no framework dependencies.

**Tech stack:** Node.js · Express · plain HTML/CSS/JS

---

## File Structure

```
adp-bank-demo/
├── server.js                 — Express proxy server
├── public/
│   └── index.html            — PandaBank chat UI
├── package.json              — dependencies: express only
└── .claude/
    └── launch.json           — dev server configuration
```

---

## Components

### `server.js` — Proxy Server

- Serves `public/` as static files
- Exposes `POST /chat` endpoint:
  - Accepts `{ message: string }`
  - Wraps in A2A JSON-RPC envelope and POSTs to the Redpanda agent
  - Always returns HTTP 200 with either `{ reply: string }` or `{ error: string }`
  - Uses a 30-second fetch timeout; on timeout returns `{ error: "The agent is taking too long — please try again." }`
- Uses a per-request incrementing counter for JSON-RPC `id` (avoids duplicate IDs on rapid submissions)
- Listens on port 3000

**A2A request envelope:**
```json
{
  "jsonrpc": "2.0",
  "id": <incrementing integer>,
  "method": "message/send",
  "params": {
    "message": {
      "role": "user",
      "parts": [{ "kind": "text", "text": "<user message>" }]
    }
  }
}
```

**A2A response shape** (extract reply from `result.parts`):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "role": "agent",
    "parts": [{ "kind": "text", "text": "<assistant reply>" }]
  }
}
```

Extraction path: `response.result.parts.filter(p => p.kind === "text").map(p => p.text).join("\n")`. If parts are empty or missing, return `{ error: "No response received." }`.

**Agent URL:** `https://d76o3ig5s2pc73bj5uag.ai-agents.d6kjl4h19241bg3ek3h0.clusters.rdpa.co`

Each call is stateless — no session ID is tracked. The agent handles tool calls internally for each message independently.

### `public/index.html` — Chat UI

Single-page app. No build step, no framework.

**Visual style:**
- Dark background (`#0c0c0c`) with Redpanda orange (`#ff3e00`) accents
- 🦝 emoji as logo
- Header: "PandaBank" + "Internal Assistant" subtitle (no connection status indicator — cosmetic only)
- User messages: right-aligned, orange background
- Assistant messages: left-aligned, dark card with 🦝 prefix
- Suggested query pills shown on load, hidden after first message is sent
- Typing indicator (animated dots) shown while awaiting a response

**Suggested queries:**
1. Is Sarah Miller overdrawn?
2. Why is Bob Martinez overdrawn?
3. Look up Alice Johnson and show me her accounts
4. Show the last 5 transactions on account 7
5. What is the balance on account 3?

**Behaviour:**
- Clicking a suggestion fills the input and submits immediately
- Enter key submits the input
- Input, Send button, and suggestion pills are all disabled while a request is in-flight (prevents concurrent submissions)
- On `{ error }` response, display a red error bubble in chat

### `package.json`

```json
{
  "name": "pandabank",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.0" }
}
```

### `.claude/launch.json`

```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "PandaBank",
      "runtimeExecutable": "node",
      "runtimeArgs": ["server.js"],
      "port": 3000
    }
  ]
}
```

---

## Data Flow

```
User types / clicks suggestion
        │
        ▼
public/index.html
  POST /chat  { message: "..." }
        │
        ▼
server.js  (Express proxy, 30s timeout)
  POST https://<agent-url>/message/send
  A2A JSON-RPC envelope
        │
        ▼
Redpanda "Bank Internal Assistant" agent
  → calls MCP tools (get_customer, get_account_balance, get_recent_transactions)
  → returns A2A response
        │
        ▼
server.js  extracts text from result.parts
  returns  { reply: "..." }  or  { error: "..." }
        │
        ▼
public/index.html  appends message bubble to chat
```

---

## Error Handling

| Situation | Server returns | UI shows |
|---|---|---|
| Agent responds normally | `{ reply: "..." }` | Assistant bubble |
| Agent returns empty parts | `{ error: "No response received." }` | Red error bubble |
| Agent fetch fails (network) | `{ error: "Could not reach the agent." }` | Red error bubble |
| Agent takes > 30 seconds | `{ error: "The agent is taking too long — please try again." }` | Red error bubble |

All `/chat` responses are HTTP 200 — the UI always handles the payload, never the status code.

---

## Out of Scope

- Authentication / login screen (open access, demo only)
- Conversation history persistence (in-memory only, resets on page refresh)
- Markdown rendering in responses (plain text only)
- Session tracking across messages (each call is independent)
