#!/usr/bin/env python3
import json
import re
import os

HTML_FILE_PATH = "index.html"
CONFIG_OUTPUT_PATH = "/tmp/config.json"

def extract_from_html():
    if not os.path.exists(HTML_FILE_PATH):
        print(f"ERROR: {HTML_FILE_PATH} not found")
        return [], [], []
    
    with open(HTML_FILE_PATH, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Find the CredentialsPool array
    pool_match = re.search(r'CredentialsPool:\s*\[(.*?)\n\s*\]', content, re.DOTALL)
    
    uuids = []
    trojan_passwords = []
    ss_creds = []
    
    if pool_match:
        pool_content = pool_match.group(1)
        
        # Extract UUIDs (format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)
        found_uuids = re.findall(r'([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})', pool_content)
        uuids.extend(found_uuids)
        
        # Extract plain passwords (alphanumeric, 20-40 chars, no hyphens, no colons)
        plain_passwords = re.findall(r'"([A-Za-z0-9]{20,40})"', pool_content)
        trojan_passwords.extend(plain_passwords)
        
        # Extract Shadowsocks credentials (method:password format)
        ss_creds = re.findall(r'"(aes-256-gcm|chacha20-poly1305):([A-Za-z0-9]+)"', pool_content)
    
    # Remove duplicates while preserving order
    uuids = list(dict.fromkeys(uuids))
    trojan_passwords = list(dict.fromkeys(trojan_passwords))
    
    print(f"📊 Extracted from index.html:")
    print(f"   UUIDs (VLESS/VMess): {len(uuids)}")
    print(f"   Passwords (Trojan): {len(trojan_passwords)}")
    print(f"   SS credentials: {len(ss_creds)}")
    
    return uuids, trojan_passwords, ss_creds

def generate_config():
    uuids, trojan_passwords, ss_creds = extract_from_html()
    
    # Fallbacks if extraction fails
    if not uuids:
        uuids = ["f47ac10b-58cc-4372-a567-0e02b2c3d479"]
        print("⚠️ No UUIDs found, using fallback")
    if not trojan_passwords:
        trojan_passwords = ["GCPMatrixPassTokenVectorAlpha01"]
        print("⚠️ No Trojan passwords found, using fallback")
    
    config = {
        "log": {"loglevel": "warning"},
        "dns": {
            "servers": ["8.8.8.8", "1.1.1.1", "8.8.4.4"],
            "queryStrategy": "UseIPv4"
        },
        "inbounds": [],
        "outbounds": [{"protocol": "freedom", "tag": "direct", "settings": {}}],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [{"type": "field", "ip": ["127.0.0.0/8"], "outbound": "direct"}]
        }
    }
    
    sock_opts = {"tcpFastOpen": True, "tcpNoDelay": True, "tcpKeepAliveInterval": 30}
    sniff_opts = {"enabled": True, "destOverride": ["http", "tls"]}
    
    # Port mappings: 10000-10011
    # Trojan: ports 10000-10002
    # VMess: ports 10003-10005
    # VLESS: ports 10006-10008
    # Shadowsocks: ports 10009-10011
    
    networks = [
        ("ws", "wsSettings", ""),
        ("httpupgrade", "httpupgradeSettings", "-hu"),
        ("xhttp", "xhttpSettings", "-xh")
    ]
    
    # 1. TROJAN (ports 10000, 10001, 10002)
    for i, (net, setting_key, suffix) in enumerate(networks):
        port = 10000 + i
        config["inbounds"].append({
            "port": port,
            "listen": "127.0.0.1",
            "protocol": "trojan",
            "tag": f"trojan-{net}",
            "settings": {"clients": [{"password": pwd} for pwd in trojan_passwords]},
            "streamSettings": {
                "network": net,
                setting_key: {"path": f"/saeka-tojirp{suffix}"},
                "sockopt": sock_opts
            },
            "sniffing": sniff_opts
        })
    
    # 2. VMESS (ports 10003, 10004, 10005)
    for i, (net, setting_key, suffix) in enumerate(networks):
        port = 10003 + i
        config["inbounds"].append({
            "port": port,
            "listen": "127.0.0.1",
            "protocol": "vmess",
            "tag": f"vmess-{net}",
            "settings": {"clients": [{"id": uid, "security": "auto"} for uid in uuids]},
            "streamSettings": {
                "network": net,
                setting_key: {"path": f"/vmess-saeka{suffix}"},
                "sockopt": sock_opts
            },
            "sniffing": sniff_opts
        })
    
    # 3. VLESS (ports 10006, 10007, 10008)
    for i, (net, setting_key, suffix) in enumerate(networks):
        port = 10006 + i
        config["inbounds"].append({
            "port": port,
            "listen": "127.0.0.1",
            "protocol": "vless",
            "tag": f"vless-{net}",
            "settings": {"clients": [{"id": uid} for uid in uuids], "decryption": "none"},
            "streamSettings": {
                "network": net,
                setting_key: {"path": f"/vless-saeka{suffix}"},
                "sockopt": sock_opts
            },
            "sniffing": sniff_opts
        })
    
    # 4. SHADOWSOCKS (ports 10009, 10010, 10011)
    for i, (net, setting_key, suffix) in enumerate(networks):
        port = 10009 + i
        # Use ss_creds if available, otherwise fallback to trojan_passwords
        if ss_creds:
            clients = [{"password": pwd, "method": method} for method, pwd in ss_creds]
        else:
            clients = [{"password": pwd, "method": "aes-256-gcm"} for pwd in trojan_passwords[:10]]
        
        config["inbounds"].append({
            "port": port,
            "listen": "127.0.0.1",
            "protocol": "shadowsocks",
            "tag": f"ss-{net}",
            "settings": {"clients": clients},
            "streamSettings": {
                "network": net,
                setting_key: {"path": f"/ss-saeka{suffix}"},
                "sockopt": sock_opts
            },
            "sniffing": sniff_opts
        })
    
    with open(CONFIG_OUTPUT_PATH, "w") as f:
        json.dump(config, f, indent=2)
    
    print(f"\n✅ config.json generated at {CONFIG_OUTPUT_PATH}")
    print(f"   Total inbounds: {len(config['inbounds'])}")
    print(f"   - Trojan: 3 (ports 10000-10002)")
    print(f"   - VMess: 3 (ports 10003-10005)")
    print(f"   - VLESS: 3 (ports 10006-10008)")
    print(f"   - Shadowsocks: 3 (ports 10009-10011)")

if __name__ == "__main__":
    generate_config()
