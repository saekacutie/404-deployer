FROM openresty/openresty:alpine
RUN apk add --no-cache ca-certificates wget unzip netcat-openbsd curl jq

# Error handling for Xray download
RUN RETRY=0; until [ $RETRY -ge 3 ]; do \
    wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && break; \
    RETRY=$((RETRY+1)); sleep 5; \
    done && \
    if [ ! -f /tmp/xray.zip ]; then echo 'Failed to download Xray'; exit 1; fi && \
    unzip -p /tmp/xray.zip xray > /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && rm -rf /tmp/xray.zip

COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY index.html /usr/local/openresty/nginx/html/index.html
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Enhanced startup script with error handling
RUN mkdir -p /startup
RUN cat > /startup/start.sh << 'EOF'
#!/bin/sh
set -e

# Start Xray with error handling
timeout 30 /usr/local/bin/xray run -c /etc/xray.json &
XRAY_PID=$!
sleep 2

# Check if Xray started successfully
if ! kill -0 $XRAY_PID 2>/dev/null; then
    echo "ERROR: Xray failed to start"
    exit 1
fi

# Wait for all ports with timeout
for port in 10000 10001 10002 10003 10004 10005 10006 10007 10008 10009 10010 10011; do
    timeout 30 sh -c "until nc -z 127.0.0.1 $port 2>/dev/null; do sleep 0.1; done" || {
        echo "ERROR: Port $port failed to open"
        kill $XRAY_PID 2>/dev/null || true
        exit 1
    }
    echo "✓ Port $port ready"
done

echo "Starting OpenResty..."
exec /usr/local/openresty/bin/openresty -g 'daemon off;'
EOF

chmod +x /startup/start.sh

CMD ["/startup/start.sh"]