#!/bin/bash

# URL Discovery Module
# TheBestRecon

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Save start time
START_TIME=$(date +%s)

# Default values
OUTPUT_DIR=""
SCAN_MODE="big" # Default scan mode: big

# Process parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        --scan-mode)
            SCAN_MODE="$2"
            shift
            shift
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

# Domain parameter check
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-] Domain parameter is required${NC}"
    echo "Usage: $0 <domain> [-o output_dir] [--scan-mode short|medium|big]"
    exit 1
fi

# Create url_discovery directory in output directory
URL_DISCOVERY_DIR="${OUTPUT_DIR}/url_discovery"
mkdir -p "$URL_DISCOVERY_DIR"

echo -e "${GREEN}###------- Starting URL Discovery: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $URL_DISCOVERY_DIR${NC}"
echo -e "${BLUE}[+] Scan mode: $SCAN_MODE${NC}"

# Create temporary directory
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

# Run URL filtering module (if temp directory doesn't exist or files are missing)
if [ ! -f "$TEMP_DIR/short_urls.txt" ] || [ ! -f "$TEMP_DIR/medium_urls.txt" ] || [ ! -f "$TEMP_DIR/all_urls.txt" ]; then
    echo -e "${BLUE}[+] Running URL filtering module...${NC}"
    bash "$OUTPUT_DIR/../../modules/filter_urls.sh" "$DOMAIN" -o "$OUTPUT_DIR" --scan-mode "$SCAN_MODE"
fi

# Select URL list based on scan mode
LIVE_DOMAINS_FILE=""
case $SCAN_MODE in
    "short")
        if [ -f "$TEMP_DIR/short_urls.txt" ]; then
            LIVE_DOMAINS_FILE="$TEMP_DIR/short_urls.txt"
            echo -e "${BLUE}[+] Short scan mode selected - Scanning with critical subdomains${NC}"
        else
            echo -e "${YELLOW}[!] Short mode URL list not found, using default list${NC}"
        fi
        ;;
    "medium")
        if [ -f "$TEMP_DIR/medium_urls.txt" ]; then
            LIVE_DOMAINS_FILE="$TEMP_DIR/medium_urls.txt"
            echo -e "${BLUE}[+] Medium scan mode selected - Scanning with important subdomains${NC}"
        else
            echo -e "${YELLOW}[!] Medium mode URL list not found, using default list${NC}"
        fi
        ;;
    *)
        echo -e "${BLUE}[+] Big scan mode selected - Scanning all subdomains${NC}"
        if [ -f "$TEMP_DIR/all_urls.txt" ]; then
            LIVE_DOMAINS_FILE="$TEMP_DIR/all_urls.txt"
        fi
        ;;
esac

# If LIVE_DOMAINS_FILE is still empty, check default lists
if [ -z "$LIVE_DOMAINS_FILE" ]; then
    if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
        LIVE_DOMAINS_FILE="$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt"
        echo -e "${BLUE}[+] Using live domains from subs_live module${NC}"
    elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
        LIVE_DOMAINS_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt"
        echo -e "${BLUE}[+] Using live domains from subdomain_brute module${NC}"
    elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
        LIVE_DOMAINS_FILE="$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt"
        echo -e "${BLUE}[+] Using live domains from subdomain_enum module${NC}"
    else
        echo -e "${YELLOW}[!] No live subdomain list found${NC}"
        echo -e "${YELLOW}[!] Using main domain...${NC}"
        echo "$DOMAIN" > "$URL_DISCOVERY_DIR/single_domain.txt"
        LIVE_DOMAINS_FILE="$URL_DISCOVERY_DIR/single_domain.txt"
    fi
fi

DOMAINS_COUNT=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] URL discovery will be performed on $DOMAINS_COUNT subdomains${NC}"
echo -e "${BLUE}[+] Using subdomain list: $LIVE_DOMAINS_FILE ${NC}"

# 1. URL discovery with Gau
if command -v gau &> /dev/null; then
    echo -e "${BLUE}[+] Running gau...${NC}"
    cat "$LIVE_DOMAINS_FILE" | gau --threads 5 --o "$URL_DISCOVERY_DIR/gau_urls.txt"
    GAU_URLS=$(wc -l < "$URL_DISCOVERY_DIR/gau_urls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] gau completed: Found $GAU_URLS URLs${NC}"
else
    echo -e "${RED}[-] gau not found${NC}"
fi

# 2. URL discovery with Waymore
if command -v waymore &> /dev/null; then
    echo -e "${BLUE}[+] Running waymore...${NC}"
    waymore -i "$LIVE_DOMAINS_FILE" -mode U -oU "$URL_DISCOVERY_DIR/waymoreUrls.txt"
    WAYMORE_URLS=$(wc -l < "$URL_DISCOVERY_DIR/waymoreUrls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] waymore completed: Found $WAYMORE_URLS URLs${NC}"
else
    echo -e "${RED}[-] waymore not found${NC}"
fi

# 3. URL discovery with Katana
if command -v katana &> /dev/null; then
    echo -e "${BLUE}[+] Running katana...${NC}"
    katana -list "$LIVE_DOMAINS_FILE" -d 5 -jc -jsl -kf all -aff -rl 5 -o "$URL_DISCOVERY_DIR/katanaURls.txt"   
    KATANA_URLS=$(wc -l < "$URL_DISCOVERY_DIR/katanaURls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] katana completed: Found $KATANA_URLS URLs${NC}"
else
    echo -e "${RED}[-] katana not found${NC}"
fi

# Merge all URLs
echo -e "${BLUE}[+] Merging all URL results...${NC}"
cat "$URL_DISCOVERY_DIR"/*.txt 2>/dev/null | sort -u > "$URL_DISCOVERY_DIR/all_unique_urls.txt"
TOTAL_URLS=$(wc -l < "$URL_DISCOVERY_DIR/all_unique_urls.txt" 2>/dev/null || echo 0)

# Time format function
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    minutes=$((minutes % 60))
    seconds=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Calculate and show total time at the end of the module
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_TIME_FORMATTED=$(format_time $TOTAL_TIME)
echo -e "${CYAN}[+] Total URL discovery time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- URL Discovery completed: $DOMAIN - Found $TOTAL_URLS unique URLs -------###${NC}" 