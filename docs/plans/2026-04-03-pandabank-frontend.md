# PandaBank Frontend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dark-themed chat UI backed by an Express proxy that forwards messages to a Redpanda ADP AI agent via the A2A protocol.

**Architecture:** A Node.js/Express server serves the static frontend and proxies `POST /chat` to the Redpanda agent, avoiding browser CORS restrictions. The frontend is a single HTML file — no framework, no build step.

**Tech Stack:** Node.js · Express 4 · plain HTML/CSS/JS

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `package.json` | Create | Dependencies + start script |
| `server.js` | Create | Express proxy server |
| `public/index.html` | Create | PandaBank chat UI |
| `.claude/launch.json` | Create | Dev server config |

---

## Task 1: Project scaffold

**Files:**
- Create: `package.json`
- Create: `.claude/launch.json`

- [ ] **Step 1: Create `package.json`**

```json
{
  "name": "pandabank",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": { "express": "^4.18.0" }
}
```

- [ ] **Step 2: Create `.claude/launch.json`**

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

- [ ] **Step 3: Install dependencies**

```bash
cd /Users/josh/adp-bank-demo
npm install
```

Expected: `node_modules/` created, `package-lock.json` written.

- [ ] **Step 4: Commit**

```bash
git add package.json package-lock.json .claude/launch.json
git commit -m "feat: scaffold pandabank project"
```

---

## Task 2: Express proxy server

**Files:**
- Create: `server.js`

- [ ] **Step 1: Create `server.js`**

```js
const express = require('express');
const path = require('path');

const app = express();
const PORT = 3000;
const AGENT_URL = 'https://d76o3ig5s2pc73bj5uag.ai-agents.d6kjl4h19241bg3ek3h0.clusters.rdpa.co';

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

let rpcId = 0;

app.post('/chat', async (req, res) => {
  const { message } = req.body;
  if (!message || typeof message !== 'string') {
    return res.json({ error: 'Invalid request: message is required.' });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);

  try {
    const response = await fetch(`${AGENT_URL}/message/send`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: ++rpcId,
        method: 'message/send',
        params: {
          message: {
            role: 'user',
            parts: [{ kind: 'text', text: message }]
          }
        }
      }),
      signal: controller.signal
    });

    const data = await response.json();
    const parts = data?.result?.parts ?? [];
    const text = parts.filter(p => p.kind === 'text').map(p => p.text).join('\n');

    if (!text) {
      return res.json({ error: 'No response received.' });
    }

    return res.json({ reply: text });

  } catch (err) {
    if (err.name === 'AbortError') {
      return res.json({ error: 'The agent is taking too long — please try again.' });
    }
    console.error('Agent fetch error:', err.message);
    return res.json({ error: 'Could not reach the agent.' });
  } finally {
    clearTimeout(timeout);
  }
});

app.listen(PORT, () => {
  console.log(`PandaBank running at http://localhost:${PORT}`);
});
```

- [ ] **Step 2: Smoke-test the server starts**

```bash
node server.js
```

Expected output: `PandaBank running at http://localhost:3000`

Stop with Ctrl+C.

- [ ] **Step 3: Smoke-test the `/chat` endpoint against the live agent**

```bash
node server.js &
curl -s -X POST http://localhost:3000/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Is Sarah Miller overdrawn?"}' | python3 -m json.tool
kill %1
```

Expected: JSON with a `reply` field containing text about Sarah Miller's accounts.

- [ ] **Step 4: Commit**

```bash
git add server.js
git commit -m "feat: add express proxy for A2A agent"
```

---

## Task 3: PandaBank chat UI

**Files:**
- Create: `public/index.html`

- [ ] **Step 1: Create `public/` directory**

```bash
mkdir -p /Users/josh/adp-bank-demo/public
```

- [ ] **Step 2: Create `public/index.html`**

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>PandaBank</title>
  <style>
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }

    body {
      background: #0c0c0c;
      color: #e5e5e5;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
    }

    /* ── Header ── */
    header {
      width: 100%;
      max-width: 720px;
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 16px 20px;
      border-bottom: 1px solid #1a1a1a;
    }
    .logo { font-size: 28px; line-height: 1; }
    .brand-name { font-size: 18px; font-weight: 700; color: #fff; letter-spacing: 0.3px; }
    .brand-sub { font-size: 11px; color: #555; text-transform: uppercase; letter-spacing: 1px; margin-top: 2px; }

    /* ── Chat area ── */
    #chat {
      flex: 1;
      width: 100%;
      max-width: 720px;
      overflow-y: auto;
      padding: 20px;
      display: flex;
      flex-direction: column;
      gap: 12px;
    }

    /* ── Suggestions ── */
    #suggestions { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 8px; }
    .suggestion {
      background: #1a1a1a;
      border: 1px solid #2a2a2a;
      color: #a1a1a1;
      font-size: 12px;
      padding: 6px 14px;
      border-radius: 20px;
      cursor: pointer;
      transition: border-color 0.15s, color 0.15s;
    }
    .suggestion:hover { border-color: #ff3e00; color: #fff; }
    .suggestion:disabled { opacity: 0.4; cursor: not-allowed; }

    /* ── Messages ── */
    .msg { display: flex; gap: 10px; max-width: 85%; }
    .msg.user { align-self: flex-end; flex-direction: row-reverse; }
    .msg.assistant { align-self: flex-start; }
    .msg-avatar { font-size: 20px; margin-top: 2px; flex-shrink: 0; }
    .msg-bubble {
      padding: 10px 14px;
      border-radius: 12px;
      font-size: 14px;
      line-height: 1.6;
      white-space: pre-wrap;
      word-break: break-word;
    }
    .msg.user .msg-bubble { background: #ff3e00; color: #fff; border-radius: 12px 12px 2px 12px; }
    .msg.assistant .msg-bubble { background: #1a1a1a; border: 1px solid #2a2a2a; border-radius: 2px 12px 12px 12px; }
    .msg.error .msg-bubble { background: #2a0a0a; border: 1px solid #7f1d1d; color: #fca5a5; border-radius: 12px; }

    /* ── Typing indicator ── */
    .typing-dots { display: flex; gap: 4px; align-items: center; padding: 4px 0; }
    .typing-dots span {
      width: 7px; height: 7px;
      background: #555;
      border-radius: 50%;
      animation: bounce 1.2s infinite;
    }
    .typing-dots span:nth-child(2) { animation-delay: 0.2s; }
    .typing-dots span:nth-child(3) { animation-delay: 0.4s; }
    @keyframes bounce {
      0%, 80%, 100% { transform: translateY(0); }
      40% { transform: translateY(-6px); }
    }

    /* ── Input bar ── */
    #input-bar {
      width: 100%;
      max-width: 720px;
      display: flex;
      gap: 8px;
      padding: 12px 20px 20px;
      border-top: 1px solid #1a1a1a;
    }
    #input {
      flex: 1;
      background: #1a1a1a;
      border: 1px solid #2a2a2a;
      border-radius: 8px;
      padding: 10px 14px;
      color: #e5e5e5;
      font-size: 14px;
      font-family: inherit;
      outline: none;
      transition: border-color 0.15s;
    }
    #input:focus { border-color: #ff3e00; }
    #input::placeholder { color: #444; }
    #send-btn {
      background: #ff3e00;
      border: none;
      border-radius: 8px;
      padding: 10px 18px;
      color: #fff;
      font-size: 14px;
      font-weight: 600;
      cursor: pointer;
      transition: background 0.15s;
    }
    #send-btn:hover { background: #e03500; }
    #send-btn:disabled, #input:disabled { opacity: 0.5; cursor: not-allowed; }
  </style>
</head>
<body>

  <header>
    <div class="logo">🦝</div>
    <div>
      <div class="brand-name">PandaBank</div>
      <div class="brand-sub">Internal Assistant</div>
    </div>
  </header>

  <div id="chat">
    <div id="suggestions">
      <button class="suggestion" onclick="sendSuggestion(this)">Is Sarah Miller overdrawn?</button>
      <button class="suggestion" onclick="sendSuggestion(this)">Why is Bob Martinez overdrawn?</button>
      <button class="suggestion" onclick="sendSuggestion(this)">Look up Alice Johnson and show me her accounts</button>
      <button class="suggestion" onclick="sendSuggestion(this)">Show the last 5 transactions on account 7</button>
      <button class="suggestion" onclick="sendSuggestion(this)">What is the balance on account 3?</button>
    </div>
  </div>

  <div id="input-bar">
    <input id="input" type="text" placeholder="Ask about a customer or account..." />
    <button id="send-btn" onclick="sendMessage()">Send</button>
  </div>

  <script>
    const chat = document.getElementById('chat');
    const input = document.getElementById('input');
    const sendBtn = document.getElementById('send-btn');
    const suggestions = document.getElementById('suggestions');
    let suggestionsHidden = false;

    input.addEventListener('keydown', e => {
      if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); sendMessage(); }
    });

    function sendSuggestion(btn) {
      input.value = btn.textContent;
      sendMessage();
    }

    async function sendMessage() {
      const text = input.value.trim();
      if (!text) return;

      setLoading(true);
      hideSuggestions();

      appendMessage('user', text);
      input.value = '';

      const typingEl = appendTyping();

      try {
        const res = await fetch('/chat', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: text })
        });
        const data = await res.json();
        typingEl.remove();

        if (data.reply) {
          appendMessage('assistant', data.reply);
        } else {
          appendMessage('error', data.error || 'Something went wrong.');
        }
      } catch (err) {
        typingEl.remove();
        appendMessage('error', 'Could not reach the server.');
      } finally {
        setLoading(false);
      }
    }

    function appendMessage(role, text) {
      const wrapper = document.createElement('div');
      wrapper.className = `msg ${role}`;

      if (role === 'assistant') {
        const avatar = document.createElement('div');
        avatar.className = 'msg-avatar';
        avatar.textContent = '🦝';
        wrapper.appendChild(avatar);
      }

      const bubble = document.createElement('div');
      bubble.className = 'msg-bubble';
      bubble.textContent = text;
      wrapper.appendChild(bubble);

      chat.appendChild(wrapper);
      chat.scrollTop = chat.scrollHeight;
    }

    function appendTyping() {
      const wrapper = document.createElement('div');
      wrapper.className = 'msg assistant';
      const avatar = document.createElement('div');
      avatar.className = 'msg-avatar';
      avatar.textContent = '🦝';
      wrapper.appendChild(avatar);
      const bubble = document.createElement('div');
      bubble.className = 'msg-bubble';
      bubble.innerHTML = '<div class="typing-dots"><span></span><span></span><span></span></div>';
      wrapper.appendChild(bubble);
      chat.appendChild(wrapper);
      chat.scrollTop = chat.scrollHeight;
      return wrapper;
    }

    function hideSuggestions() {
      if (!suggestionsHidden) {
        suggestions.style.display = 'none';
        suggestionsHidden = true;
      }
    }

    function setLoading(loading) {
      input.disabled = loading;
      sendBtn.disabled = loading;
      document.querySelectorAll('.suggestion').forEach(b => b.disabled = loading);
    }
  </script>

</body>
</html>
```

- [ ] **Step 3: Start the server and open in browser**

```bash
node server.js
open http://localhost:3000
```

Expected: PandaBank UI loads with dark theme, 🦝 logo, 5 suggestion pills visible.

- [ ] **Step 4: Test a suggestion click**

Click "Is Sarah Miller overdrawn?" — expected:
- Suggestion pills disappear
- User bubble "Is Sarah Miller overdrawn?" appears right-aligned in orange
- Typing indicator (three bouncing dots) appears
- After ~5–15 seconds, assistant response bubble appears with Sarah's account details

- [ ] **Step 5: Test free-text input**

Type "What is the balance on account 3?" and press Enter.
Expected: same flow as above, response shows account 3 balance and status.

- [ ] **Step 6: Commit**

```bash
git add public/index.html
git commit -m "feat: add pandabank chat UI"
```

---

## Task 4: Wire up launch.json and final commit

- [ ] **Step 1: Update README to mention the frontend**

Add to the **What's in this repo** table in `README.md`:

```markdown
| `server.js` + `public/` | PandaBank web chat UI — run with `npm start`, open http://localhost:3000 |
```

- [ ] **Step 2: Add `node_modules` to `.gitignore`**

Create `/Users/josh/adp-bank-demo/.gitignore`:
```
node_modules/
.superpowers/
```

- [ ] **Step 3: Final commit and push**

```bash
git add README.md .gitignore
git commit -m "chore: update readme and add gitignore"
git push
```

- [ ] **Step 4: Verify end-to-end**

```bash
npm start
open http://localhost:3000
```

Run all 5 demo queries. Confirm each returns a meaningful response from the agent.
