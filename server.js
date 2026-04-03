const express = require('express');
const path = require('path');

// Load .env if present
try { require('fs').readFileSync('.env').toString().split('\n').forEach(l => { const [k,...rest] = l.split('='); const v = rest.join('='); if (k && v) process.env[k.trim()] = v.trim(); }); } catch {}

const app = express();
const PORT = 3000;
const AGENT_URL = 'https://d76o3ig5s2pc73bj5uag.ai-agents.d6kjl4h19241bg3ek3h0.clusters.rdpa.co';
const TOKEN_URL = 'https://auth.prd.cloud.redpanda.com/oauth/token';

if (!process.env.REDPANDA_CLIENT_ID || !process.env.REDPANDA_CLIENT_SECRET) {
  console.error('FATAL: REDPANDA_CLIENT_ID and REDPANDA_CLIENT_SECRET must be set. Copy .env.example to .env and fill in credentials.');
  process.exit(1);
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

let rpcId = 0;
let cachedToken = null;
let tokenExpiresAt = 0;

async function getToken() {
  if (cachedToken && Date.now() < tokenExpiresAt - 30000) return cachedToken;

  const params = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: process.env.REDPANDA_CLIENT_ID,
    client_secret: process.env.REDPANDA_CLIENT_SECRET,
  });

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: params.toString(),
  });

  if (!res.ok) throw new Error(`Token fetch failed: ${res.status}`);
  const data = await res.json();
  cachedToken = data.access_token;
  tokenExpiresAt = Date.now() + (data.expires_in ?? 3600) * 1000;
  return cachedToken;
}

app.post('/chat', async (req, res) => {
  const { message } = req.body;
  if (!message || typeof message !== 'string') {
    return res.json({ error: 'Invalid request: message is required.' });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 30000);

  try {
    const token = await getToken();
    const messageId = crypto.randomUUID();

    const response = await fetch(`${AGENT_URL}/message/send`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`,
      },
      body: JSON.stringify({
        jsonrpc: '2.0',
        id: ++rpcId,
        method: 'message/send',
        params: {
          message: {
            messageId,
            role: 'user',
            parts: [{ kind: 'text', text: message }]
          }
        }
      }),
      signal: controller.signal
    });

    const data = await response.json();

    // Response arrives as result.artifacts[0].parts (streaming tokens joined)
    const parts = data?.result?.artifacts?.[0]?.parts ?? data?.result?.parts ?? [];
    const text = parts.filter(p => p.kind === 'text').map(p => p.text).join('');

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
