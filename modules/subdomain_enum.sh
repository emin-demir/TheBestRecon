#!/bin/bash

# Subdomain Enumeration Module
# TheBestRecon

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Default values
API_CONFIG=""
OUTPUT_DIR=""
SKIP_DNSX=false

# Process parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -a|--api-config)
            API_CONFIG="$2"
            shift
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        --skip-dnsx)
            SKIP_DNSX=true
            shift
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

# Create subdomain_enum directory in output directory
SUBDOMAIN_ENUM_DIR="${OUTPUT_DIR}/subdomain_enum"
mkdir -p "$SUBDOMAIN_ENUM_DIR"

echo -e "${GREEN}###------- Starting subdomain enumeration: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $SUBDOMAIN_ENUM_DIR${NC}"

# Save start time
START_TIME=$(date +%s)

# API config check
if [ ! -z "$API_CONFIG" ] && [ -f "$API_CONFIG" ]; then
    echo -e "${BLUE}[+] API configuration file loaded: $API_CONFIG${NC}"
        VTAPIKEY=$(grep -o '"VTAPIKEY": *"[^"]*"' "$API_CONFIG" | sed 's/"VTAPIKEY": *"\([^"]*\)"/\1/')
        GITHUB_API_KEY=$(grep -o '"GITHUB_API_KEY": *"[^"]*"' "$API_CONFIG" | sed 's/"GITHUB_API_KEY": *"\([^"]*\)"/\1/')
        PDCP_API_KEY=$(grep -o '"PDCP_API_KEY": *"[^"]*"' "$API_CONFIG" | sed 's/"PDCP_API_KEY": *"\([^"]*\)"/\1/')    
        DNSDUMPSTER_API_KEY=$(grep -o '"DNSDUMPSTER_API_KEY": *"[^"]*"' "$API_CONFIG" | sed 's/"DNSDUMPSTER_API_KEY": *"\([^"]*\)"/\1/')
    echo -e "${BLUE}[+] API keys loaded and set as environment variables${NC}"
else
    echo -e "${YELLOW}[!] API configuration file not found or not specified${NC}"
    echo -e "${YELLOW}[!] Some tools will run with limited capacity${NC}"
    VTAPIKEY="NONE"
    GITHUB_API_KEY="NONE"
    PDCP_API_KEY="NONE"
    DNSDUMPSTER_API_KEY="NONE"
fi

# Set default values as environment variables
export VTAPIKEY="$VTAPIKEY"
export VT_API_KEY="$VTAPIKEY"
export VIRUSTOTAL_API_KEY="$VTAPIKEY"
export GITHUB_API_KEY="$GITHUB_API_KEY"
export CHAOS_API_KEY="$PDCP_API_KEY"
export PDCP_API_KEY="$PDCP_API_KEY"
export DNSDUMPSTER_API_KEY="$DNSDUMPSTER_API_KEY"

# 1. Find subdomains with assetfinder
echo -e "${BLUE}[+] Running assetfinder...${NC}"
if command -v assetfinder &> /dev/null; then
    assetfinder --subs-only "$DOMAIN" | tee "$SUBDOMAIN_ENUM_DIR/assetfinder_${DOMAIN}.txt"
    echo -e "${GREEN}[+] assetfinder completed: $(wc -l < "$SUBDOMAIN_ENUM_DIR/assetfinder_${DOMAIN}.txt") subdomains found${NC}"
else
    echo -e "${RED}[-] assetfinder not found${NC}"
fi

# 2. Find subdomains with subfinder
echo -e "${BLUE}[+] Running subfinder...${NC}"
if command -v subfinder &> /dev/null; then
    subfinder -all -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/subfinder_${DOMAIN}.txt"
    echo -e "${GREEN}[+] subfinder completed: $(wc -l < "$SUBDOMAIN_ENUM_DIR/subfinder_${DOMAIN}.txt") subdomains found${NC}"
else
    echo -e "${RED}[-] subfinder not found${NC}"
fi

# 3. Find subdomains with sublist3r
echo -e "${BLUE}[+] Running sublist3r...${NC}"
if command -v sublist3r &> /dev/null; then
    sublist3r -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/sublist3r_${DOMAIN}.txt"
    echo -e "${GREEN}[+] sublist3r completed: $(wc -l < "$SUBDOMAIN_ENUM_DIR/sublist3r_${DOMAIN}.txt") subdomains found${NC}"
else
    echo -e "${RED}[-] sublist3r not found${NC}"
fi

# 4. Find subdomains with chaos (API key required)
echo -e "${BLUE}[+] Running chaos...${NC}"
if command -v chaos &> /dev/null; then
    if [ ! -z "$PDCP_API_KEY" ]; then
        chaos -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/chaos_${DOMAIN}.txt"
        echo -e "${GREEN}[+] chaos completed: $(wc -l < "$SUBDOMAIN_ENUM_DIR/chaos_${DOMAIN}.txt") subdomains found${NC}"
    else
        echo -e "${YELLOW}[!] Chaos API key not found, skipping chaos${NC}"
    fi
else
    echo -e "${RED}[-] chaos not found${NC}"
fi

# 5. Find subdomains with amass
echo -e "${BLUE}[+] Running amass...${NC}"
if command -v amass &> /dev/null; then
    amass enum -passive -trqps 5 -rqps 5  -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/amass_${DOMAIN}_dontmerge.txt"
    echo -e "${GREEN}[+] amass completed: $(wc -l < "$SUBDOMAIN_ENUM_DIR/amass_${DOMAIN}_dontmerge.txt") subdomains found${NC}"
else
    echo -e "${RED}[-] amass not found${NC}"
fi

# 6. Find subdomains with github-subdomains
echo -e "${BLUE}[+] Running github-subdomains...${NC}"
if command -v github-subdomains &> /dev/null; then
    if [ ! -z "$GITHUB_API_KEY" ]; then
        github-subdomains -d "$DOMAIN" -k -e -t "$GITHUB_API_KEY" -o "$SUBDOMAIN_ENUM_DIR/github_subdomains_${DOMAIN}_dontmerge.txt"
        echo -e "${GREEN}[+] github-subdomains completed: $(wc -l < "$SUBDOMAIN_ENUM_DIR/github_subdomains_${DOMAIN}_dontmerge.txt") subdomains found${NC}"
    else
        echo -e "${YELLOW}[!] GitHub API key not found. Skipping github-subdomains${NC}"
    fi
else
    echo -e "${RED}[-] github-subdomains not found${NC}"
fi

# Merge all results
echo -e "${BLUE}[+] Merging all subdomain results...${NC}"
cat "$SUBDOMAIN_ENUM_DIR"/*_"$DOMAIN.txt" 2>/dev/null | sort -u > "$SUBDOMAIN_ENUM_DIR/all_subdomains_${DOMAIN}.txt"

TOTAL_SUBDOMAINS=$(wc -l < "$SUBDOMAIN_ENUM_DIR/all_subdomains_${DOMAIN}.txt")
echo -e "${GREEN}###------- Total $TOTAL_SUBDOMAINS unique subdomains found -------###${NC}"

# Check live subdomains with DNSX (if skip-dnsx parameter is not provided)
if ! $SKIP_DNSX; then
    echo -e "${BLUE}[+] Checking live subdomains with dnsx...${NC}"
    if command -v dnsx &> /dev/null; then
        # Check resolver file
        RESOLVER_FILE="$OUTPUT_DIR/../../config/resolvers.txt"
        if [ ! -f "$RESOLVER_FILE" ]; then
            echo -e "${YELLOW}[!] Resolver file ($RESOLVER_FILE) not found, creating...${NC}"
            wget -O "$RESOLVER_FILE" https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers.txt
        fi
        
        # Run DNS query and save raw results
        cat "$SUBDOMAIN_ENUM_DIR/all_subdomains_${DOMAIN}.txt" | \
            dnsx -r "$RESOLVER_FILE" -a -resp -o "$SUBDOMAIN_ENUM_DIR/dnsx_raw_${DOMAIN}.txt" -nc
        
        # Extract only subdomains (1st column)
        cat "$SUBDOMAIN_ENUM_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f1 | sort -u > "$SUBDOMAIN_ENUM_DIR/dnsx_live_subdomains_${DOMAIN}.txt" 
        
        # Extract IP addresses (3rd column) and remove brackets
        cat "$SUBDOMAIN_ENUM_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f3 | sed 's/\[\(.*\)\]/\1/g' | sort -u > "$SUBDOMAIN_ENUM_DIR/dnsx_ips_${DOMAIN}.txt"
        
        LIVE_SUBDOMAINS=$(wc -l < "$SUBDOMAIN_ENUM_DIR/dnsx_live_subdomains_${DOMAIN}.txt")
        IP_COUNT=$(wc -l < "$SUBDOMAIN_ENUM_DIR/dnsx_ips_${DOMAIN}.txt")
        
        echo -e "${GREEN}[+] dnsx completed: $LIVE_SUBDOMAINS live subdomains and $IP_COUNT unique IP addresses found${NC}"
    else
        echo -e "${RED}[-] dnsx not found${NC}"
    fi
else
    echo -e "${YELLOW}[!] Skipping dnsx check (--skip-dnsx parameter provided)${NC}"
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
echo -e "${CYAN}[+] Total subdomain discovery time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Subdomain Enumeration completed: $DOMAIN - Total $TOTAL_SUBDOMAINS unique subdomains found -------###${NC}"