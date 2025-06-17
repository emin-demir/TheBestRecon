#!/bin/bash

# Subdomain Live Check and Screenshot Module
# TheBestRecon

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
OUTPUT_DIR=""
LIVE_CHECK=false
SCREENSHOT=false

# Process parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        -l|--live)
            LIVE_CHECK=true
            shift
            ;;
        -s|--screenshot)
            SCREENSHOT=true
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
    echo "Usage: $0 <domain> [-o output_dir] [-l/--live] [-s/--screenshot]"
    exit 1
fi

# Save start time
START_TIME=$(date +%s)

# Create subs_live directory in output directory
SUBS_LIVE_DIR="${OUTPUT_DIR}/subs_live"
mkdir -p "$SUBS_LIVE_DIR"

echo -e "${GREEN}###------- Starting Subdomain Live Check and Screenshot: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $SUBS_LIVE_DIR${NC}"

# Merge all subdomain files
echo -e "${BLUE}[+] Merging all subdomain results...${NC}"

# Steps 1 and 2: Check subdomain_brute directory and its file
if [ -d "$OUTPUT_DIR/subdomain_brute" ] && [ -f "$OUTPUT_DIR/subdomain_brute/combined_subdomains_${DOMAIN}.txt" ] && [ -s "$OUTPUT_DIR/subdomain_brute/combined_subdomains_${DOMAIN}.txt" ]; then
    echo -e "${GREEN}[+] Using subdomain brute results${NC}"
    cp "$OUTPUT_DIR/subdomain_brute/combined_subdomains_${DOMAIN}.txt" "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt"
# Step 3: Check file in subdomain_enum directory
elif [ -f "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" ] && [ -s "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" ]; then
    echo -e "${GREEN}[+] Using subdomain enum results${NC}"
    cp "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt"
# Step 4: Error if none found
else
    echo -e "${RED}[-] ERROR: No subdomain files found!${NC}"
    echo -e "${YELLOW}[!] Please run 'subdomain_enum.sh' or 'subdomain_brute.sh' first.${NC}"
    exit 1
fi

# Live Check process
if $LIVE_CHECK; then
    echo -e "${BLUE}[+] Checking live subdomains with httpx...${NC}"
    
    if command -v httpx &> /dev/null; then
        # Get total subdomain count
        TOTAL_SUBDOMAINS=$(wc -l < "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt")
        cat "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt" | \
        httpx -sc -status-code -ip -ct -web-server -t 25 -rl 25 -location -lc -title -td -method -websocket -cname -extract-fqdn -asn -cdn -probe -silent | \
        tee "$SUBS_LIVE_DIR/httpx_detailed_${DOMAIN}.txt" | \
        tee >(grep -E '\b(2[0-9]{2}|3[0-9]{2}|400)\b' > "$SUBS_LIVE_DIR/200-400-httpx-domains.txt") \
            >(grep -Ev '\b(2[0-9]{2}|3[0-9]{2}|400)\b' > "$SUBS_LIVE_DIR/exclude-200-400-httpx-domains.txt")
        
        # Create domain list only (200-400 HTTP codes)
        cat "$SUBS_LIVE_DIR/200-400-httpx-domains.txt" | cut -d ' ' -f1 | sort -u > "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt"
        
        LIVE_SUBDOMAINS=$(wc -l < "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt")
        echo -e "${GREEN}[+] httpx completed: $LIVE_SUBDOMAINS subdomains found returning 200-400 status code (HTTP 200-400)${NC}"
        
        # Also check with httprobe
        echo -e "${BLUE}[+] Checking https and http with httprobe...${NC}"
        if command -v httprobe &> /dev/null; then
                cat "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt" | \
                httprobe -c 5 -p http,https | \
                tee "$SUBS_LIVE_DIR/httprobe_all_${DOMAIN}.txt" | \
                tee >(grep "^http://" > "$SUBS_LIVE_DIR/http-httprobe-domains.txt") \
                    >(grep "^https://" > "$SUBS_LIVE_DIR/https-httprobe-domains.txt")
            # Merge httprobe and httpx results
            cat "$SUBS_LIVE_DIR/httprobe_all_${DOMAIN}.txt" "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt" | sort -u > "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt"     
            COMBINED_LIVE=$(wc -l < "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt")
            echo -e "${GREEN}[+] httprobe completed: Total $COMBINED_LIVE domains found matching http and https protocols${NC}"
        else
            echo -e "${RED}[-] httprobe not found${NC}"
            cp "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt" "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt"
        fi
    else
        echo -e "${RED}[-] httpx not found${NC}"
    fi
fi

# Screenshot process
if $SCREENSHOT && [ -f "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt" ]; then
    echo -e "${BLUE}[+] Taking screenshots with aquatone...${NC}"
    
    if command -v aquatone &> /dev/null; then
        SCREENSHOT_DIR="$SUBS_LIVE_DIR/aquatone_results"
        mkdir -p "$SCREENSHOT_DIR"
        
        # Get total live subdomain count
        TOTAL_LIVE_DOMAINS=$(wc -l < "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt")
        
            cat "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt" | \
            aquatone -out "$SCREENSHOT_DIR" -scan-timeout 6000 -http-timeout 20000 -threads 1
        
        echo -e "${GREEN}[+] aquatone completed: Screenshots saved to $SCREENSHOT_DIR directory${NC}"
    else
        echo -e "${RED}[-] aquatone not found${NC}"
    fi
else
    if $SCREENSHOT; then
        echo -e "${YELLOW}[!] No live subdomains found to take screenshots${NC}"
    fi
fi
 
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
echo -e "${CYAN}[+] Total process time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Process completed: $DOMAIN -------###${NC}" 