#!/bin/bash
BOLD='\033[1m'; RESET='\033[0m'
GREEN='\033[1;32m'; RED='\033[1;31m'; CYAN='\033[1;36m'
YELLOW='\033[1;33m'; MAGENTA='\033[1;35m'; WHITE='\033[1;37m'

loading() {
    local t="$1"
    local s="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    for ((i=0;i<5;i++)); do for ((j=0;j<${#s};j++)); do echo -ne "\r  ${CYAN}${s:$j:1} ${t}...${RESET}"; sleep 0.05; done; done
    echo -ne "\r  ${GREEN}DONE: ${t}${RESET}\n"
}

clear
echo ""
echo -e "  ${BOLD}${WHITE}404 NOT FOUND DEPLOYER${RESET}"
echo -e "  ${MAGENTA}MADE BY SAEKA TOJIRP${RESET}"
echo -e "  ${GREEN}fb.com/saekacutiee${RESET}"
echo ""

PROJECT_ID=$(gcloud config get-value project 2>/dev/null | tr -d '[:space:]')
echo -e "  ${CYAN}PROJECT: ${GREEN}${PROJECT_ID}${RESET}"
echo ""

read -r -p "$(echo -e "  ${CYAN}SERVICE NAME [prvtspyyy]: ${RESET}")" INPUT_NAME
SERVICE_NAME=${INPUT_NAME:-prvtspyyy}

echo ""
echo -e "  ${CYAN}SELECT PERFORMANCE:${RESET}"
echo -e "  ${YELLOW}1) 1 vCPU / 2Gi RAM${RESET}"
echo -e "  ${YELLOW}2) 2 vCPU / 4Gi RAM${RESET}"
echo -e "  ${YELLOW}3) 4 vCPU / 8Gi RAM${RESET}"
echo ""
read -r -p "$(echo -e "  ${CYAN}CHOICE [2]: ${RESET}")" PAIR_CHOICE

case "$PAIR_CHOICE" in
    1) CPU="1"; RAM="2Gi";;
    3) CPU="4"; RAM="8Gi";;
    *) CPU="2"; RAM="4Gi";;
esac

echo ""
loading "BUILDING IMAGE"
gcloud builds submit --tag "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" . --project=$PROJECT_ID --quiet > build.log 2>&1
if [ $? -ne 0 ]; then echo -e "  ${RED}BUILD FAILED${RESET}"; tail -n 10 build.log; exit 1; fi

loading "DEPLOYING TO CLOUD RUN"
gcloud run deploy "$SERVICE_NAME" \
  --image "gcr.io/${PROJECT_ID}/${SERVICE_NAME}" \
  --platform managed --region us-central1 \
  --cpu "$CPU" --memory "$RAM" --port 8080 \
  --concurrency 1000 --cpu-boost --no-cpu-throttling \
  --timeout 3600 --min-instances 1 --max-instances 4 \
  --allow-unauthenticated --project=$PROJECT_ID --quiet > deploy.log 2>&1

if [ $? -ne 0 ]; then echo -e "  ${RED}DEPLOYMENT FAILED${RESET}"; tail -n 10 deploy.log; exit 1; fi

SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" --region us-central1 --project=$PROJECT_ID --format='value(status.url)' 2>/dev/null)
CLEAN_HOST=$(echo "$SERVICE_URL" | sed 's|https://||')

echo ""
echo -e "  ${GREEN}DEPLOYED SUCCESSFULLY${RESET}"
echo ""
echo -e "  ${CYAN}HOST     ${GREEN}${CLEAN_HOST}${RESET}"
echo -e "  ${CYAN}PORT     ${GREEN}443${RESET}"
echo -e "  ${CYAN}PASS     ${GREEN}saeka${RESET}"
echo ""
echo -e "  ${CYAN}PAGE     ${GREEN}${SERVICE_URL}${RESET}"

rm -f build.log deploy.log
