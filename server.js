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
