FROM openresty/openresty:alpine

# Install dependencies
RUN apk add --no-cache ca-certificates wget unzip curl jq busybox-extras python3 py3-pip nodejs npm

# Download Xray
RUN RETRY=0; XRAY_VERSION="1.8.12"; until [ $RETRY -ge 5 ]; do \
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-64.zip && break; \
    RETRY=$((RETRY+1)); sleep 10; \
    done && \
    if [ ! -f /tmp/xray.zip ]; then echo 'Failed to download Xray'; exit 1; fi && \
    unzip -p /tmp/xray.zip xray > /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    /usr/local/bin/xray -version && \
    rm -rf /tmp/xray.zip

# Create log directories
RUN mkdir -p /var/log/xray && touch /var/log/xray/access.log /var/log/xray/error.log
RUN mkdir -p /app

# Setup Node.js backend
COPY server.js /app/server.js
RUN cd /app && npm init -y && npm install express ws 2>/dev/null

# Copy configuration files
COPY build_config.py /tmp/build_config.py
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY index.html /usr/local/openresty/nginx/html/index.html

# Generate config.json
RUN python3 /tmp/build_config.py && \
    if [ -f /tmp/config.json ]; then mv /tmp/config.json /etc/xray.json; \
    elif [ -f /tmp/generated_config.json ]; then mv /tmp/generated_config.json /etc/xray.json; \
    else echo "ERROR: config.json not generated"; exit 1; fi && \
    rm -f /tmp/build_config.py

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=15s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Startup script
RUN mkdir -p /startup
RUN cat > /startup/start.sh << 'EOF'
#!/bin/sh
set -e

echo "[$(date)] Starting services..."

# Start Xray
/usr/local/bin/xray run -c /etc/xray.json &
XRAY_PID=$!
sleep 5

if ! kill -0 $XRAY_PID 2>/dev/null; then
    echo "[$(date)] ERROR: Xray failed to start"
    exit 1
fi
echo "[$(date)] Xray started (PID: $XRAY_PID)"

# Start Node.js backend
cd /app && node server.js &
NODE_PID=$!
sleep 3

if ! kill -0 $NODE_PID 2>/dev/null; then
    echo "[$(date)] ERROR: Node.js failed to start"
    exit 1
fi
echo "[$(date)] Node.js started (PID: $NODE_PID)"

# Wait for Xray ports
echo "[$(date)] Waiting for Xray ports..."
PORT_TIMEOUT=120
START=$(date +%s)

for port in 10000 10001 10002 10003 10004 10005 10006 10007 10008 10009 10010 10011; do
    while ! nc -z 127.0.0.1 $port 2>/dev/null; do
        ELAPSED=$(($(date +%s) - START))
        if [ $ELAPSED -gt $PORT_TIMEOUT ]; then
            echo "[$(date)] ERROR: Port $port timeout"
            kill $XRAY_PID $NODE_PID 2>/dev/null || true
            exit 1
        fi
        sleep 1
    done
    echo "[$(date)] ✓ Port $port open"
done

echo "[$(date)] Starting OpenResty..."
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF

chmod +x /startup/start.sh
CMD ["/startup/start.sh"]
