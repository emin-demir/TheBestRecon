#!/bin/bash

# URL Filtering Module
# TheBestRecon - Filters URL list based on scan mode

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
OUTPUT_DIR=""

# Process parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -o|--output)
            OUTPUT_DIR="$2"
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
    echo "Usage: $0 <domain> [-o output_dir]"
    exit 1
fi

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}"
fi

# Create temporary directory
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}[+] Starting URL Filtering module...${NC}"

# Check if live subdomains exist
LIVE_DOMAINS_FILE=""
if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-domains-clean.txt" ]; then
    LIVE_DOMAINS_FILE="$OUTPUT_DIR/subs_live/200-400-httpx-domains-clean.txt"
    echo -e "${BLUE}[+] Using clean httpx domain list from subs_live module${NC}"
elif [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
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
    echo "$DOMAIN" > "$TEMP_DIR/single_domain.txt"
    LIVE_DOMAINS_FILE="$TEMP_DIR/single_domain.txt"
fi

# Show total URL count
TOTAL_DOMAINS=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] Total domain count: $TOTAL_DOMAINS${NC}"

# Short subdomain list
SHORT_LIST="$OUTPUT_DIR/../../config/30_short_subdomain.txt"
if [ ! -f "$SHORT_LIST" ]; then
    echo -e "${RED}[-] Short subdomain list not found: $SHORT_LIST${NC}"
    exit 1
fi

# Medium subdomain list
MEDIUM_LIST="$OUTPUT_DIR/../../config/100_medium_subdomain.txt"
if [ ! -f "$MEDIUM_LIST" ]; then
    echo -e "${RED}[-] Medium subdomain list not found: $MEDIUM_LIST${NC}"
    exit 1
fi

# Create URL list for Short mode
echo -e "${BLUE}[+] Preparing Short mode URL list...${NC}"
> "$TEMP_DIR/short_urls.txt"

# Scan more effectively with -iFf
grep -iFf "$SHORT_LIST" "$LIVE_DOMAINS_FILE" > "$TEMP_DIR/short_urls.txt" 2>/dev/null

# Check Short URL count
SHORT_URLS=$(wc -l < "$TEMP_DIR/short_urls.txt")
if [ $SHORT_URLS -eq 0 ]; then
    echo -e "${YELLOW}[!] No URLs found for Short mode. Using main domain...${NC}"
    # Check main domain - add https if no http prefix
    if [[ $DOMAIN != http://* ]] && [[ $DOMAIN != https://* ]]; then
        echo "https://$DOMAIN" > "$TEMP_DIR/short_urls.txt"
    else
        echo "$DOMAIN" > "$TEMP_DIR/short_urls.txt"
    fi
    SHORT_URLS=1
fi
echo -e "${GREEN}[+] Prepared $SHORT_URLS URLs for Short mode${NC}"

# Create URL list for Medium mode
echo -e "${BLUE}[+] Preparing Medium mode URL list...${NC}"
> "$TEMP_DIR/medium_urls.txt"

# Scan more effectively with -iFf
grep -iFf "$MEDIUM_LIST" "$LIVE_DOMAINS_FILE" > "$TEMP_DIR/medium_urls.txt" 2>/dev/null

# Check Medium URL count
MEDIUM_URLS=$(wc -l < "$TEMP_DIR/medium_urls.txt")
if [ $MEDIUM_URLS -eq 0 ]; then
    echo -e "${YELLOW}[!] No URLs found for Medium mode. Using main domain...${NC}"
    # Check main domain - add https if no http prefix
    if [[ $DOMAIN != http://* ]] && [[ $DOMAIN != https://* ]]; then
        echo "https://$DOMAIN" > "$TEMP_DIR/medium_urls.txt"
    else
        echo "$DOMAIN" > "$TEMP_DIR/medium_urls.txt"
    fi
    MEDIUM_URLS=1
fi
echo -e "${GREEN}[+] Prepared $MEDIUM_URLS URLs for Medium mode${NC}"

# Copy all URLs for Big mode
cp "$LIVE_DOMAINS_FILE" "$TEMP_DIR/all_urls.txt"

echo -e "${GREEN}[+] URL filtering completed.${NC}"
echo -e "${GREEN}[+] URL list: $TEMP_DIR${NC}"

# Extract IPs from DNS records
DNS_RAW_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_raw_${DOMAIN}.txt"
if [ -f "$DNS_RAW_FILE" ]; then
    echo -e "${BLUE}[+] Starting IP address extraction from DNS records...${NC}"
    
    # Short mode IPs
    echo -e "${BLUE}[+] Extracting Short mode IPs...${NC}"
    cut -d '/' -f3 "$TEMP_DIR/short_urls.txt" 2>/dev/null | sed 's/^https\?:\/\///' | while read -r d; do
        grep -F "$d" "$DNS_RAW_FILE" 2>/dev/null
    done | grep -oP '\[\K[0-9.]+(?=\])' | sort -u > "$TEMP_DIR/short_ips.txt"
    SHORT_IPS=$(wc -l < "$TEMP_DIR/short_ips.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Found $SHORT_IPS unique IP addresses for Short mode${NC}"
    
    # Medium mode IPs
    echo -e "${BLUE}[+] Extracting Medium mode IPs...${NC}"
    cut -d '/' -f3 "$TEMP_DIR/medium_urls.txt" 2>/dev/null | sed 's/^https\?:\/\///' | while read -r d; do
        grep -F "$d" "$DNS_RAW_FILE" 2>/dev/null
    done | grep -oP '\[\K[0-9.]+(?=\])' | sort -u > "$TEMP_DIR/medium_ips.txt"
    MEDIUM_IPS=$(wc -l < "$TEMP_DIR/medium_ips.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Found $MEDIUM_IPS unique IP addresses for Medium mode${NC}"
    
    # Big mode IPs (all IPs)
    echo -e "${BLUE}[+] Extracting all IPs...${NC}"
    cut -d '/' -f3 "$TEMP_DIR/all_urls.txt" 2>/dev/null | sed 's/^https\?:\/\///' | while read -r d; do
        grep -F "$d" "$DNS_RAW_FILE" 2>/dev/null
    done | grep -oP '\[\K[0-9.]+(?=\])' | sort -u > "$TEMP_DIR/all_ips.txt"
    ALL_IPS=$(wc -l < "$TEMP_DIR/all_ips.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Found total $ALL_IPS unique IP addresses${NC}"
    
    echo -e "${GREEN}[+] IP address extraction completed.${NC}"
else
    echo -e "${YELLOW}[!] DNS record file not found: $DNS_RAW_FILE${NC}"
    echo -e "${YELLOW}[!] Could not extract IP addresses.${NC}"
fi