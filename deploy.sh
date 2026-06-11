#!/bin/bash
set -e

BOLD='\033[1m'; RESET='\033[0m'
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; MAGENTA='\033[1;35m'; WHITE='\033[1;37m'

loading() {
    local t="$1"
    local s="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    for ((i=0;i<5;i++)); do 
        for ((j=0;j<${#s};j++)); do 
            echo -ne "\r  ${CYAN}${s:$j:1} ${t}...${RESET}"
            sleep 0.05
        done
    done
    echo -ne "\r  ${GREEN}✓ ${t}${RESET}\n"
}

error_exit() {
    echo -e "  ${RED}✗ ERROR: $1${RESET}"
    exit 1
}

retry_command() {
    local max_attempts=3
    local attempt=1
    while [ $attempt -le $max_attempts ]; do
        echo -e "  ${YELLOW}Attempt $attempt/$max_attempts...${RESET}"
        if "$@"; then
            return 0
        fi
        attempt=$((attempt + 1))
        if [ $attempt -le $max_attempts ]; then
            sleep 5
        fi
    done
    return 1
}

clear
echo ""
echo -e "  ${BOLD}${WHITE}404 NOT FOUND DEPLOYER${RESET}"
echo -e "  ${MAGENTA}MADE BY SAEKA TOJIRP${RESET}"
echo -e "  ${GREEN}fb.com/saekacutiee${RESET}"
echo -e "  ${CYAN}Version 2.0 - Enhanced Error Handling${RESET}"
echo ""

# Check gcloud
if ! command -v gcloud &> /dev/null; then
    error_exit "gcloud CLI not found. Please install Google Cloud SDK."
fi

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
if [ -z "$PROJECT_ID" ]; then
    error_exit "No GCP project configured. Run: gcloud config set project PROJECT_ID"
fi

echo -e "  ${CYAN}PROJECT: ${GREEN}${PROJECT_ID}${RESET}"
echo ""

read -r -p "$(echo -e "  ${CYAN}SERVICE NAME [prvtspyyy]: ${RESET}")" INPUT_NAME
SERVICE_NAME=${INPUT_NAME:-prvtspyyy}

echo ""
echo -e "  ${CYAN}SELECT MODE:${RESET}"
echo -e "  ${YELLOW}1) BROWSING     (1 vCPU / 2Gi  RAM)${RESET}"
echo -e "  ${YELLOW}2) STREAMING    (2 vCPU / 4Gi  RAM)${RESET}"
echo -e "  ${YELLOW}3) GAMING       (4 vCPU / 8Gi  RAM)${RESET}"
echo -e "  ${YELLOW}4) ULTRA        (8 vCPU / 16Gi RAM)${RESET}"
echo -e "  ${YELLOW}5) CUSTOM${RESET}"
echo ""
read -r -p "$(echo -e "  ${CYAN}CHOICE [4]: ${RESET}")" MODE_CHOICE

case "$MODE_CHOICE" in
    1) CPU="1"; RAM="2Gi"; MODE="BROWSING";;
    2) CPU="2"; RAM="4Gi"; MODE="STREAMING";;
    3) CPU="4"; RAM="8Gi"; MODE="GAMING";;
    5)
        echo ""
        read -r -p "$(echo -e "  ${CYAN}CPU (1/2/4/8): ${RESET}")" CPU
        read -r -p "$(echo -e "  ${CYAN}RAM (2Gi/4Gi/8Gi/16Gi/32Gi): ${RESET}")" RAM
        echo ""
        echo -e "  ${CYAN}SELECT INSTANCES:${RESET}"
        echo -e "  ${YELLOW}1) 1 INSTANCE${RESET}"
        echo -e "  ${YELLOW}2) 2 INSTANCES${RESET}"
        echo -e "  ${YELLOW}3) 4 INSTANCES${RESET}"
        echo -e "  ${YELLOW}4) 8 INSTANCES${RESET}"
        echo ""
        read -r -p "$(echo -e "  ${CYAN}CHOICE [1]: ${RESET}")" INST_CHOICE
        case "$INST_CHOICE" in
            2) MAX_INSTANCES="2";;
            3) MAX_INSTANCES="4";;
            4) MAX_INSTANCES="8";;
            *) MAX_INSTANCES="1";;
        esac
        MODE="CUSTOM"
        ;;
    *) CPU="8"; RAM="16Gi"; MODE="ULTRA"; MAX_INSTANCES="2";;
esac

if [ -z "$MAX_INSTANCES" ]; then
    echo ""
    echo -e "  ${CYAN}SELECT INSTANCES:${RESET}"
    echo -e "  ${YELLOW}1) 1 INSTANCE${RESET}"
    echo -e "  ${YELLOW}2) 2 INSTANCES${RESET}"
    echo -e "  ${YELLOW}3) 4 INSTANCES${RESET}"
    echo -e "  ${YELLOW}4) 8 INSTANCES${RESET}"
    echo ""
    read -r -p "$(echo -e "  ${CYAN}CHOICE [1]: ${RESET}")" INST_CHOICE
    case "$INST_CHOICE" in
        2) MAX_INSTANCES="2";;
        3) MAX_INSTANCES="4";;
        4) MAX_INSTANCES="8";;
        *) MAX_INSTANCES="1";;
    esac
fi

echo ""
echo -e "  ${CYAN}MODE: ${GREEN}${MODE}${RESET} | ${CYAN}CPU: ${GREEN}${CPU}${RESET} | ${CYAN}RAM: ${GREEN}${RAM}${RESET} | ${CYAN}INSTANCES: ${GREEN}${MAX_INSTANCES}${RESET}"
echo ""

# Build with retry
loading "BUILDING IMAGE"
if ! retry_command gcloud builds submit --tag "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" . --project=$PROJECT_ID --quiet > build.log 2>&1; then
    error_exit "Build failed after 3 attempts. Last 20 lines:"; tail -n 20 build.log
fi

# Deploy with retry
loading "DEPLOYING TO CLOUD RUN"
if ! retry_command gcloud run deploy "$SERVICE_NAME" \
  --image "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" \
  --platform managed --region us-central1 \
  --cpu "$CPU" --memory "$RAM" --port 8080 \
  --concurrency 1000 --cpu-boost --no-cpu-throttling \
  --timeout 3600 --min-instances 1 --max-instances "$MAX_INSTANCES" \
  --allow-unauthenticated --project=$PROJECT_ID --quiet > deploy.log 2>&1; then
    error_exit "Deployment failed after 3 attempts. Last 20 lines:"; tail -n 20 deploy.log
fi

# Get service URL with retry
loading "RETRIEVING SERVICE URL"
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region us-central1 --project=$PROJECT_ID --format='value(status.url)' 2>/dev/null)
if [ -z "$SERVICE_URL" ]; then
    error_exit "Failed to retrieve service URL"
fi

CLEAN_HOST=$(echo "$SERVICE_URL" | sed 's|https://||')

echo ""
echo -e "  ${GREEN}✓ DEPLOYMENT SUCCESSFUL${RESET}"
echo ""
echo -e "  ${CYAN}HOST       ${GREEN}${CLEAN_HOST}${RESET}"
echo -e "  ${CYAN}PORT       ${GREEN}443${RESET}"
echo -e "  ${CYAN}PASS       ${GREEN}saeka${RESET}"
echo -e "  ${CYAN}MODE       ${GREEN}${MODE}${RESET}"
echo -e "  ${CYAN}CPU        ${GREEN}${CPU}${RESET}"
echo -e "  ${CYAN}RAM        ${GREEN}${RAM}${RESET}"
echo -e "  ${CYAN}INSTANCES  ${GREEN}${MAX_INSTANCES}${RESET}"
echo ""
echo -e "  ${CYAN}TROJAN       ${GREEN}/saeka-tojirp${RESET}"
echo -e "  ${CYAN}VMESS        ${GREEN}/vmess-saeka${RESET}"
echo -e "  ${CYAN}VLESS        ${GREEN}/vless-saeka${RESET}"
echo -e "  ${CYAN}SHADOWSOCKS  ${GREEN}/ss-saeka${RESET}"
echo ""
echo -e "  ${CYAN}PAGE     ${GREEN}${SERVICE_URL}${RESET}"
echo ""
echo -e "  ${CYAN}STARTING REAL-TIME LOGS...${RESET}"
echo -e "  ${YELLOW}(Press Ctrl+C to stop)${RESET}"
echo ""

npm install express cors ws
node server.js

# Tail logs with error handling
gcloud run logs tail "$SERVICE_NAME" --region us-central1 --project="$PROJECT_ID" || {
    echo -e "  ${YELLOW}Note: Logs streaming interrupted (this is normal)${RESET}"
    echo -e "  ${CYAN}Service is still running at: ${GREEN}${SERVICE_URL}${RESET}"
}
