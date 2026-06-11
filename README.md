# 404-Deployer

🚀 **Advanced GCP Cloud Run Deployment System with Security Authentication**

## Features

✅ **Security System**
- Random UUID generation per session
- Security quiz authentication (3 attempts)
- Admin access code: `saeka-admin`
- Session management and tracking
- One user per generated UUID

✅ **Multiple Protocols**
- TROJAN (WebSocket, HTTP Upgrade, XHTTP)
- VMESS (WebSocket, HTTP Upgrade, XHTTP)
- VLESS (WebSocket, HTTP Upgrade, XHTTP)
- Shadowsocks (WebSocket, HTTP Upgrade, XHTTP)

✅ **Error Handling & Resilience**
- Context deadline exceeded protection
- Connection timeout recovery
- Port closed/refused handling
- No internet connection fallbacks
- EOF error recovery
- Automatic retry logic (up to 3 attempts)

✅ **Performance**
- Connection pooling
- Keep-alive management
- TCP Fast Open support
- Zero-copy proxy buffering
- Upstream health checks

## Quick Start

### Prerequisites
- Google Cloud SDK installed
- GCP project configured
- Docker installed (for local testing)

### Deployment

```bash
bash deploy.sh
```

Follow the interactive prompts to:
1. Configure service name
2. Select performance tier (BROWSING/STREAMING/GAMING/ULTRA/CUSTOM)
3. Choose instance count

### Access Portal

After deployment, visit your service URL. You'll see:

1. **Authentication Screen**
   - Automatic UUID generation
   - Security quiz with 5 random tech questions
   - Admin access code option
   - Generate new session anytime

2. **Configuration Portal** (after authentication)
   - Address selector
   - SNI selector
   - Protocol selector (VLESS/TROJAN/VMESS/SS)
   - Transport selector (WebSocket/HTTP Upgrade/XHTTP)
   - Real-time network monitoring
   - Configuration generator
   - One-click copy

## Security Quiz Questions

1. What does 404 represent in HTTP status codes?
2. Which protocol is used for secure web communication?
3. What does VPN stand for?
4. Which layer does TLS operate on?
5. What is the default HTTPS port?

## Configuration Files

### Dockerfile
- OpenResty + Nginx as reverse proxy
- Xray core for protocol support
- Health checks enabled
- Error handling and timeouts
- Retry logic for failed operations

### config.json
- 12 inbound ports (10000-10011)
- Protocol configurations with fallbacks
- DNS with fallback servers
- Connection pooling
- Sniffing enabled for better routing

### nginx.conf
- Upstream health checks
- Connection retry logic
- Timeout management
- Error page handling
- Request/response buffering optimization

### deploy.sh
- Automated GCP Cloud Run deployment
- Retry logic for failed builds/deployments
- Interactive configuration
- Real-time log streaming
- Error reporting

## Error Handling

### Context Deadline Exceeded
- Nginx proxy retry: 2 attempts
- Timeout configuration: 3600s for long connections
- Keepalive heartbeat: 30s intervals

### Port Closed / Connection Refused
- Nginx upstream health checks
- Automatic fallback to backup upstreams
- Max 3 failures before timeout
- 30-second recovery window

### No Internet Connection
- DNS fallback: 8.8.8.8, 1.1.1.1, 8.8.4.4
- Config.json fallback mode
- Cached DNS responses (300s)

### EOF / Connection Reset
- TCP keep-alive every 30 seconds
- Proxy buffer disabled (streaming mode)
- Socket keep-alive enabled
- Automatic reconnection attempts

## Performance Tiers

| Tier | vCPU | RAM | Price | Best For |
|------|------|-----|-------|----------|
| BROWSING | 1 | 2Gi | Low | Light usage |
| STREAMING | 2 | 4Gi | Medium | Video streaming |
| GAMING | 4 | 8Gi | High | Gaming |
| ULTRA | 8 | 16Gi | Premium | High load |

## Monitoring

### Health Endpoint
```
GET /health
```
Returns `200 OK` if service is healthy

### Logs
```bash
gcloud run logs tail SERVICE_NAME --region us-central1
```

## Admin Commands

### View Service URL
```bash
gcloud run services describe SERVICE_NAME --region us-central1 --format='value(status.url)'
```

### Scale Instances
```bash
gcloud run services update SERVICE_NAME --min-instances 2 --max-instances 8 --region us-central1
```

### Delete Service
```bash
gcloud run services delete SERVICE_NAME --region us-central1
```

## Configuration Generation

The portal automatically generates configurations:

### VLESS
```
vless://saeka@ADDRESS:443?encryption=none&security=tls&host=HOST&path=PATH&sni=SNI&alpn=http/1.1
```

### TROJAN
```
trojan://saeka@ADDRESS:443?type=ws&host=HOST&path=PATH&security=tls&sni=SNI&alpn=http/1.1
```

### VMESS
```
vmess://BASE64(CONFIG_JSON)
```

### Shadowsocks
```
ss://BASE64(METHOD:PASSWORD)@ADDRESS:443?obfs=websocket&obfs-host=HOST
```

## Troubleshooting

### "Context deadline exceeded"
- Check Xray core logs
- Verify ports 10000-10011 are open
- Increase timeout values in nginx.conf

### "Port closed / Connection refused"
- Ensure service is fully deployed
- Check health endpoint: `/health`
- Verify upstream servers in nginx.conf

### "No internet connection"
- Check DNS resolvers in config.json
- Verify network policies
- Test external connectivity

### "EOF / Connection reset"
- Enable TCP keep-alive (already configured)
- Check keep-alive intervals
- Review nginx proxy buffer settings

## Created By

**SAEKA TOJIRP**
- Facebook: [fb.com/saekacutiee](https://fb.com/saekacutiee)
- Repository: [404-deployer](https://github.com/saekacutie/404-deployer)

## License

MIT License - Use at your own risk

## Support

For issues and questions, open an issue on GitHub or contact the creator.