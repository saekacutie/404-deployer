FROM openresty/openresty:alpine
RUN apk add --no-cache ca-certificates wget unzip netcat-openbsd curl jq

# Download Xray with retry and version pinning for stability
RUN RETRY=0; XRAY_VERSION="1.8.12"; until [ $RETRY -ge 5 ]; do \
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip && break; \
    RETRY=$((RETRY+1)); sleep 10; \
    done && \
    if [ ! -f /tmp/xray.zip ]; then echo 'Failed to download Xray after retries'; exit 1; fi && \
    unzip -p /tmp/xray.zip xray > /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    /usr/local/bin/xray -version && \
    rm -rf /tmp/xray.zip

COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY index.html /usr/local/openresty/nginx/html/index.html
EXPOSE 8080

# Optimized health check for Cloud Run (longer timeouts)
HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Enhanced startup script
RUN mkdir -p /startup
RUN cat > /startup/start.sh << 'EOF'
#!/bin/sh
set -e

echo "[$(date)] Starting services..."

# Start Xray
echo "[$(date)] Launching Xray..."
/usr/local/bin/xray run -c /etc/xray.json &
XRAY_PID=$!
sleep 5

# Verify Xray is running
if ! kill -0 $XRAY_PID 2>/dev/null; then
    echo "[$(date)] ERROR: Xray failed to start (PID: $XRAY_PID)"
    sleep 2
    tail -20 /var/log/xray/*.log 2>/dev/null || echo "No logs available"
    exit 1
fi

echo "[$(date)] Xray started (PID: $XRAY_PID). Waiting for ports..."

# Port check with overall timeout
PORT_TIMEOUT=120
START=$(date +%s)
PORTS="10000 10001 10002 10003 10004 10005 10006 10007 10008 10009 10010 10011"

for port in $PORTS; do
    while ! nc -z 127.0.0.1 $port 2>/dev/null; do
        ELAPSED=$(($(date +%s) - START))
        if [ $ELAPSED -gt $PORT_TIMEOUT ]; then
            echo "[$(date)] ERROR: Port $port never opened (timeout after ${ELAPSED}s)"
            kill $XRAY_PID 2>/dev/null || true
            exit 1
        fi
        echo "[$(date)] Waiting for port $port (${ELAPSED}s elapsed)..."
        sleep 1
    done
    echo "[$(date)] ✓ Port $port is open"
done

echo "[$(date)] All ports ready. Starting OpenResty..."
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF

chmod +x /startup/start.sh
CMD ["/startup/start.sh"]
