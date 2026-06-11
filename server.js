const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.static('.'));

// Load config.json
let config = JSON.parse(fs.readFileSync(path.join(__dirname, 'config.json'), 'utf8'));

// Extract credentials from config inbounds
const credentials = {
    vless: [],
    trojan: [],
    vmess: [],
    ss: []
};

// Parse config.json to extract all credentials
config.inbounds.forEach(inbound => {
    const protocol = inbound.protocol;
    if (protocol === 'vless' && inbound.settings.clients) {
        inbound.settings.clients.forEach(client => {
            if (client.id && !credentials.vless.includes(client.id)) {
                credentials.vless.push(client.id);
            }
        });
    }
    if (protocol === 'trojan' && inbound.settings.clients) {
        inbound.settings.clients.forEach(client => {
            if (client.password && !credentials.trojan.includes(client.password)) {
                credentials.trojan.push(client.password);
            }
        });
    }
    if (protocol === 'vmess' && inbound.settings.clients) {
        inbound.settings.clients.forEach(client => {
            if (client.id && !credentials.vmess.includes(client.id)) {
                credentials.vmess.push(client.id);
            }
        });
    }
    if (protocol === 'shadowsocks' && inbound.settings.clients) {
        inbound.settings.clients.forEach(client => {
            if (client.password && !credentials.ss.includes(client.password)) {
                credentials.ss.push(client.password);
            }
        });
    }
});

// Track claimed credentials
let claimedCredentials = {
    vless: [],
    trojan: [],
    vmess: [],
    ss: []
};

const claimsFile = path.join(__dirname, 'claims.json');
if (fs.existsSync(claimsFile)) {
    claimedCredentials = JSON.parse(fs.readFileSync(claimsFile, 'utf8'));
}

function saveClaims() {
    fs.writeFileSync(claimsFile, JSON.stringify(claimedCredentials, null, 2));
}

// Track active sessions and visitors
let activeSessions = {};
let visitorCount = 0;
let globalStartTime = Math.floor(Date.now() / 1000);

// API Endpoints
app.get('/api/credentials', (req, res) => {
    res.json({
        vless: credentials.vless,
        trojan: credentials.trojan,
        vmess: credentials.vmess,
        ss: credentials.ss,
        total: {
            vless: credentials.vless.length,
            trojan: credentials.trojan.length,
            vmess: credentials.vmess.length,
            ss: credentials.ss.length
        }
    });
});

app.post('/api/claim', (req, res) => {
    const { protocol, fingerprint } = req.body;
    
    if (!credentials[protocol] || credentials[protocol].length === 0) {
        return res.status(404).json({ success: false, error: 'No credentials available' });
    }
    
    // Find unused credential
    const available = credentials[protocol].filter(c => !claimedCredentials[protocol].includes(c));
    
    if (available.length === 0) {
        return res.status(404).json({ success: false, error: 'No available credentials for this protocol' });
    }
    
    const credential = available[0];
    claimedCredentials[protocol].push(credential);
    saveClaims();
    
    // Register session
    const sessionId = fingerprint + '_' + Date.now();
    activeSessions[sessionId] = {
        fingerprint,
        protocol,
        credential,
        claimedAt: Date.now()
    };
    
    visitorCount++;
    
    res.json({
        success: true,
        credential: credential,
        sessionId: sessionId,
        visitorCount: visitorCount,
        activeCount: Object.keys(activeSessions).length
    });
});

app.get('/api/stats', (req, res) => {
    res.json({
        visitors: visitorCount,
        activeUsers: Object.keys(activeSessions).length,
        uptime: Math.floor(Date.now() / 1000) - globalStartTime,
        claimedCount: {
            vless: claimedCredentials.vless.length,
            trojan: claimedCredentials.trojan.length,
            vmess: claimedCredentials.vmess.length,
            ss: claimedCredentials.ss.length
        },
        totalCredentials: {
            vless: credentials.vless.length,
            trojan: credentials.trojan.length,
            vmess: credentials.vmess.length,
            ss: credentials.ss.length
        }
    });
});

app.get('/api/runtime', (req, res) => {
    res.json({
        startTime: globalStartTime,
        currentTime: Math.floor(Date.now() / 1000)
    });
});

app.get('/health', (req, res) => {
    res.status(200).send('OK');
});

// WebSocket for real-time updates
const WebSocket = require('ws');
const server = app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Credentials loaded: VLESS:${credentials.vless.length}, TROJAN:${credentials.trojan.length}, VMESS:${credentials.vmess.length}, SS:${credentials.ss.length}`);
});

const wss = new WebSocket.Server({ server });

wss.on('connection', (ws) => {
    console.log('WebSocket client connected');
    
    const interval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({
                type: 'stats',
                visitors: visitorCount,
                activeUsers: Object.keys(activeSessions).length,
                uptime: Math.floor(Date.now() / 1000) - globalStartTime
            }));
        }
    }, 2000);
    
    ws.on('close', () => {
        clearInterval(interval);
        console.log('WebSocket client disconnected');
    });
});
