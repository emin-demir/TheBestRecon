#!/bin/bash

# Subdomain Bruteforce Module
# TheBestRecon - Combined DNS and Subdomain Bruteforce

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

# Create subdomain_brute directory in output directory
SUBDOMAIN_BRUTE_DIR="${OUTPUT_DIR}/subdomain_brute"
mkdir -p "$SUBDOMAIN_BRUTE_DIR"

echo -e "${GREEN}###------- Starting subdomain and DNS bruteforce: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $SUBDOMAIN_BRUTE_DIR${NC}"

# 1. Subdomain bruteforce with Gobuster
echo -e "${BLUE}[+] Running Gobuster...${NC}"
if command -v ffuf &> /dev/null; then
    gobuster dns -d ${DOMAIN} -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o "$SUBDOMAIN_BRUTE_DIR/gobuster_subs_${DOMAIN}_dont_merge.txt" --delay 200ms --no-color -t 5
    if [ -f "$SUBDOMAIN_BRUTE_DIR/gobuster_subs_${DOMAIN}_dont_merge.txt" ]; then
        cat "$SUBDOMAIN_BRUTE_DIR/gobuster_subs_${DOMAIN}_dont_merge.txt" | cut -d ' ' -f2 > gobuster_${DOMAIN}.txt
        echo -e "${GREEN}[+] Gobuster completed: $(wc -l < "$SUBDOMAIN_BRUTE_DIR/gobuster_${DOMAIN}.txt") subdomains found${NC}"
    fi
else
    echo -e "${RED}[-] Gobuster not found${NC}"
fi

# 2. DNS bruteforce with shuffledns
echo -e "${BLUE}[+] Running shuffledns...${NC}"
if command -v shuffledns &> /dev/null; then
    # Check resolver file
    RESOLVER_FILE="$OUTPUT_DIR/../../config/resolvers.txt"
    if [ ! -f "$RESOLVER_FILE" ]; then
        echo -e "${YELLOW}[!] Resolver file ($RESOLVER_FILE) not found, creating...${NC}"
        wget -O "$RESOLVER_FILE" https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt
    fi

    shuffledns -d "$DOMAIN" \
               -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt \
               -o "$SUBDOMAIN_BRUTE_DIR/shuffledns_${DOMAIN}.txt" \
               -r "$RESOLVER_FILE" \
               -mode bruteforce \
               -wt 50 \
               -t 100 -v
    
    echo -e "${GREEN}[+] shuffledns completed: $(wc -l < "$SUBDOMAIN_BRUTE_DIR/shuffledns_${DOMAIN}.txt") subdomains found${NC}"
else
    echo -e "${RED}[-] shuffledns not found${NC}"
fi

# 3. Merge all results
echo -e "${BLUE}[+] Merging all bruteforce results...${NC}"
# Merge Gobuster outputs
cat "$SUBDOMAIN_BRUTE_DIR"/*_"${DOMAIN}.txt" 2>/dev/null | sort -u > "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt"

echo -e "${GREEN}[+] Total $(wc -l < "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt") unique subdomains found${NC}"

# 4. Check live subdomains with DNSX
echo -e "${BLUE}[+] Checking live subdomains with dnsx...${NC}"
if command -v dnsx &> /dev/null; then
    # Also check subdomain enum results
    if [ -f "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" ]; then
        echo -e "${BLUE}[+] Including subdomain enumeration results in dnsx check...${NC}"
        cat "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt" | \
        sort -u > "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt"
    else
        cp "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt" "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt"
    fi
    
    # Run DNS query and save raw results
    cat "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt" | \
        dnsx -r "$RESOLVER_FILE" -a -resp -o "$SUBDOMAIN_BRUTE_DIR/dnsx_raw_${DOMAIN}.txt" -nc
    
    # Extract only subdomains (1st column)
    cat "$SUBDOMAIN_BRUTE_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f1 | sort -u > "$SUBDOMAIN_BRUTE_DIR/dnsx_live_subdomains_${DOMAIN}.txt"
    
    # Extract IP addresses (3rd column) and remove brackets
    cat "$SUBDOMAIN_BRUTE_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f3 | sed 's/\[\(.*\)\]/\1/g' | sort -u > "$SUBDOMAIN_BRUTE_DIR/dnsx_ips_${DOMAIN}.txt"
    
    LIVE_SUBDOMAINS=$(wc -l < "$SUBDOMAIN_BRUTE_DIR/dnsx_live_subdomains_${DOMAIN}.txt")
    IP_COUNT=$(wc -l < "$SUBDOMAIN_BRUTE_DIR/dnsx_ips_${DOMAIN}.txt")
    
    echo -e "${GREEN}[+] dnsx completed: $LIVE_SUBDOMAINS live subdomains and $IP_COUNT unique IP addresses found${NC}"
else
    echo -e "${RED}[-] dnsx not found${NC}"
    cp "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt" "$OUTPUT_DIR/" 2>/dev/null
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
echo -e "${CYAN}[+] Total subdomain bruteforce time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Subdomain Bruteforce completed: $DOMAIN - Total $TOTAL_SUBDOMAINS unique subdomains found -------###${NC}" 