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

# Startup script - using printf to avoid heredoc issues
RUN mkdir -p /startup
RUN printf '#!/bin/sh\n\
set -e\n\
\n\
echo "[$(date)] Starting services..."\n\
\n\
# Start Xray\n\
echo "[$(date)] Launching Xray..."\n\
/usr/local/bin/xray run -c /etc/xray.json &\n\
XRAY_PID=$!\n\
sleep 5\n\
\n\
if ! kill -0 $XRAY_PID 2>/dev/null; then\n\
    echo "[$(date)] ERROR: Xray failed to start"\n\
    exit 1\n\
fi\n\
echo "[$(date)] Xray started (PID: $XRAY_PID)"\n\
\n\
# Start Node.js backend\n\
cd /app && node server.js &\n\
NODE_PID=$!\n\
sleep 3\n\
\n\
if ! kill -0 $NODE_PID 2>/dev/null; then\n\
    echo "[$(date)] ERROR: Node.js failed to start"\n\
    exit 1\n\
fi\n\
echo "[$(date)] Node.js started (PID: $NODE_PID)"\n\
\n\
# Wait for Xray ports\n\
echo "[$(date)] Waiting for Xray ports..."\n\
PORT_TIMEOUT=120\n\
START_TIME=$(date +%s)\n\
\n\
for port in 10000 10001 10002 10003 10004 10005 10006 10007 10008 10009 10010 10011; do\n\
    while ! nc -z 127.0.0.1 $port 2>/dev/null; do\n\
        ELAPSED=$(($(date +%s) - START_TIME))\n\
        if [ $ELAPSED -gt $PORT_TIMEOUT ]; then\n\
            echo "[$(date)] ERROR: Port $port timeout"\n\
            kill $XRAY_PID $NODE_PID 2>/dev/null || true\n\
            exit 1\n\
        fi\n\
        sleep 1\n\
    done\n\
    echo "[$(date)] Port $port open"\n\
done\n\
\n\
echo "[$(date)] Starting OpenResty..."\n\
exec /usr/local/openresty/bin/openresty -g "daemon off;"\n\
' > /startup/start.sh

RUN chmod +x /startup/start.sh
CMD ["/startup/start.sh"]
