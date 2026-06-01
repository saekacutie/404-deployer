FROM openresty/openresty:alpine
RUN apk add --no-cache ca-certificates wget unzip netcat-openbsd

RUN wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip && \
    unzip -p /tmp/xray.zip xray > /usr/local/bin/xray && \
    chmod +x /usr/local/bin/xray && rm -rf /tmp/xray.zip

COPY config.json /etc/xray.json
COPY nginx.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY index.html /usr/local/openresty/nginx/html/index.html
EXPOSE 8080

CMD /usr/local/bin/xray run -c /etc/xray.json & \
    sleep 3 && \
    /usr/local/openresty/bin/openresty -g 'daemon off;'
