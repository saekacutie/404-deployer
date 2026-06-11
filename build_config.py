import json
import re
import os

HTML_FILE_PATH = "index.html"
CONFIG_OUTPUT_PATH = "config.json"

def extract_tokens_from_html(html_path):
    # Default fallbacks if the HTML isn't built yet during local Docker stages
    default_uuids = ["f47ac10b-58cc-4372-a567-0e02b2c3d479"]
    default_passwords = ["Tj8kLp9xQm2wR5nV7yZ1aC3bF4dG6hJ8"]
    
    if not os.path.exists(html_path):
        return default_uuids, default_passwords
        
    with open(html_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Regex patterns matching standard UUIDs and random token strings from the index.html logic
    uuids = re.findall(r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}', content)
    passwords = re.findall(r'["\']([a-zA-Z0-9]{32})["\']', content)

    # De-duplicate the lists while preserving reading order
    clean_uuids = list(dict.fromkeys(uuids)) if uuids else default_uuids
    clean_passwords = list(dict.fromkeys(passwords)) if passwords else default_passwords
    
    return clean_uuids, clean_passwords

def generate_dynamic_config():
    uuids, passwords = extract_tokens_from_html(HTML_FILE_PATH)
    
    # Initialize the structure base
    config = {
        "log": {
            "loglevel": "warning"
        },
        "dns": {
            "servers": ["8.8.8.8", "1.1.1.1", "8.8.4.4"],
            "queryStrategy": "UseIPv4"
        },
        "inbounds": [],
        "outbounds": [
            {
                "protocol": "freedom",
                "tag": "direct",
                "settings": {}
            }
        ]
    }

    # Common socket configurations for stability and low-latency performance
    sock_opts = {
        "tcpFastOpen": True,
        "tcpNoDelay": True,
        "tcpKeepAliveInterval": 30
    }
    
    sniff_opts = {
        "enabled": True,
        "destOverride": ["http", "tls"]
    }

    # -------------------------------------------------------------------------
    # 1. TROJAN CHANNELS (WS & HU)
    # -------------------------------------------------------------------------
    trojan_clients = [{"password": pwd} for pwd in passwords]
    
    # Trojan WS - Port 10000
    config["inbounds"].append({
        "port": 10000,
        "listen": "127.0.0.1",
        "protocol": "trojan",
        "tag": "trojan-ws",
        "settings": {"clients": trojan_clients, "fallback": [{"dest": "127.0.0.1:8080"}]},
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "/saeka-tojirp", "acceptProxyProtocol": false},
            "sockopt": sock_opts
        },
        "sniffing": sniff_opts
    })
    
    # Trojan HTTP Upgrade (hu) - Port 10001
    config["inbounds"].append({
        "port": 10001,
        "listen": "127.0.0.1",
        "protocol": "trojan",
        "tag": "trojan-hu",
        "settings": {"clients": trojan_clients, "fallback": [{"dest": "127.0.0.1:8080"}]},
        "streamSettings": {
            "network": "httpupgrade",
            "httpupgradeSettings": {"path": "/saeka-tojirp-hu"},
            "sockopt": sock_opts
        },
        "sniffing": sniff_opts
    })

    # -------------------------------------------------------------------------
    # 2. VMESS CHANNELS (WS & HU)
    # -------------------------------------------------------------------------
    vmess_clients = [{"id": uid, "security": "auto"} for uid in uuids]
    
    # VMess WS - Port 10002
    config["inbounds"].append({
        "port": 10002,
        "listen": "127.0.0.1",
        "protocol": "vmess",
        "tag": "vmess-ws",
        "settings": {"clients": vmess_clients},
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "/vmess-saeka"},
            "sockopt": sock_opts
        },
        "sniffing": sniff_opts
    })
    
    # VMess HTTP Upgrade (hu) - Port 10003
    config["inbounds"].append({
        "port": 10003,
        "listen": "127.0.0.1",
        "protocol": "vmess",
        "tag": "vmess-hu",
        "settings": {"clients": vmess_clients},
        "streamSettings": {
            "network": "httpupgrade",
            "httpupgradeSettings": {"path": "/vmess-saeka-hu"},
            "sockopt": sock_opts
        },
        "sniffing": sniff_opts
    })

    # -------------------------------------------------------------------------
    # 3. VLESS CHANNELS (WS & HU)
    # -------------------------------------------------------------------------
    vless_clients = [{"id": uid} for uid in uuids]
    
    # Vless WS - Port 10004
    config["inbounds"].append({
        "port": 10004,
        "listen": "127.0.0.1",
        "protocol": "vless",
        "tag": "vless-ws",
        "settings": {"clients": vless_clients, "decryption": "none"},
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "/vless-saeka"},
            "sockopt": sock_opts
        },
        "sniffing": sniff_opts
    })
    
    # Vless HTTP Upgrade (hu) - Port 10005
    config["inbounds"].append({
        "port": 10005,
        "listen": "127.0.0.1",
        "protocol": "vless",
        "tag": "vless-hu",
        "settings": {"clients": vless_clients, "decryption": "none"},
        "streamSettings": {
            "network": "httpupgrade",
            "httpupgradeSettings": {"path": "/vless-saeka-hu"},
            "sockopt": sock_opts
        },
        "sniffing": sniff_opts
    })

    # -------------------------------------------------------------------------
    # 4. SHADOWSOCKS CHANNELS (WS & HU)
    # -------------------------------------------------------------------------
    # For Shadowsocks, the script pairs the first found valid credential token 
    ss_password = passwords if passwords else "GCPCryptoVectorTokenPassAlpha01"
    
    # Shadowsocks WS - Port 10006
    config["inbounds"].append({
        "port": 10006,
        "listen": "127.0.0.1",
        "protocol": "shadowsocks",
        "tag": "ss-ws",
        "settings": {
            "method": "aes-256-gcm",
            "password": ss_password,
            "network": "tcp,udp"
        },
        "streamSettings": {
            "network": "ws",
            "wsSettings": {"path": "/ss-saeka"},
            "sockopt": sock_opts
        }
    })
    
    # Shadowsocks HTTP Upgrade (hu) - Port 10007
    config["inbounds"].append({
        "port": 10007,
        "listen": "127.0.0.1",
        "protocol": "shadowsocks",
        "tag": "ss-hu",
        "settings": {
            "method": "aes-256-gcm",
            "password": ss_password,
            "network": "tcp,udp"
        },
        "streamSettings": {
            "network": "httpupgrade",
            "httpupgradeSettings": {"path": "/ss-saeka-hu"},
            "sockopt": sock_opts
        }
    })

    # Save output config file with standard formatting
    with open(CONFIG_OUTPUT_PATH, 'w', encoding='utf-8') as f:
        json.dump(config, f, indent=2)
        
    print(f"[✔] Compiled config.json: Sync'd {len(uuids)} UUID pools and {len(passwords)} security keys with full WS + HU pipelines.")

if __name__ == "__main__":
    generate_dynamic_config()
