FROM openresty/openresty:alpine

RUN apk add --no-cache ca-certificates wget unzip netcat-openbsd curl

RUN wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip -p /tmp/xray.zip xray > /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && \
    rm -rf /tmp/xray.zip

COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY index.html /usr/local/openresty/nginx/html/index.html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=5 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start Xray in background, wait only for FIRST port, then start Nginx
CMD /usr/local/bin/xray run -c /etc/xray.json 2>&1 & \
    echo "Waiting for Xray to start..." && \
    while ! nc -z 127.0.0.1 10000 2>/dev/null; do sleep 0.5; done && \
    echo "Xray ready. Starting Nginx..." && \
    exec /usr/local/openresty/bin/openresty -g 'daemon off;'
