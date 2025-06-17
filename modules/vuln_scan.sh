#!/bin/bash

# Vulnerability Scanning Module
# TheBestRecon

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Record start time
START_TIME=$(date +%s)

# Default values
SCAN_MODE="big" # Default scan mode: big

# Parse parameters
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

# Check domain parameter
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-] Domain parameter is required${NC}"
    echo "Usage: $0 <domain> [-o output_dir] [--scan-mode short|medium|big]"
    exit 1
fi

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# Create directory for vulnerability scan
VULN_SCAN_DIR="${OUTPUT_DIR}/vuln_scan"
mkdir -p "$VULN_SCAN_DIR"

echo -e "${BLUE}#==============================================================#${NC}"
echo -e "${BLUE}# ${GREEN}TheBestRecon - Comprehensive Vulnerability Scan${BLUE}                #${NC}"
echo -e "${BLUE}#==============================================================#${NC}"
echo -e "${GREEN}[+] Target Domain: ${CYAN}$DOMAIN${NC}"
echo -e "${GREEN}[+] Scan Mode: ${CYAN}$SCAN_MODE${NC}"
echo -e "${GREEN}[+] Output will be saved to: ${CYAN}$VULN_SCAN_DIR${NC}"
echo

RESOLVER_FILE="$OUTPUT_DIR/../../config/resolvers.txt"
if [ ! -f "$RESOLVER_FILE" ]; then
    echo -e "${YELLOW}[!] Resolver file ($RESOLVER_FILE) not found, downloading...${NC}"
    wget -O "$RESOLVER_FILE" https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt
fi

# Check if there are live subdomains
LIVE_DOMAINS_FILE=""

# Select URL list based on scan mode
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

# Run URL filtering module (if temp directory does not exist)
if [ ! -f "$TEMP_DIR/short_urls.txt" ] || [ ! -f "$TEMP_DIR/medium_urls.txt" ]; then
    echo -e "${BLUE}[+] Running URL filtering module...${NC}"
    bash "$OUTPUT_DIR/../../modules/filter_urls.sh" "$DOMAIN" -o "$OUTPUT_DIR"
fi

# Select URL list based on scan mode
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
        echo -e "${BLUE}[+] Big scan mode selected - All subdomains will be scanned${NC}"
        ;;
esac

# If LIVE_DOMAINS_FILE is still empty, check default lists
if [ -z "$LIVE_DOMAINS_FILE" ]; then
    if [ -f "$TEMP_DIR/all_urls.txt" ]; then
        LIVE_DOMAINS_FILE="$TEMP_DIR/all_urls.txt"
        echo -e "${BLUE}[+] Using all URLs${NC}"
    elif [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-domains-clean.txt" ]; then
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
        echo -e "${YELLOW}[!] Live subdomain list not found${NC}"
        echo -e "${YELLOW}[!] Using main domain...${NC}"
        echo "$DOMAIN" > "$VULN_SCAN_DIR/single_domain.txt"
        LIVE_DOMAINS_FILE="$VULN_SCAN_DIR/single_domain.txt"
    fi
fi

DOMAINS_COUNT=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] Vulnerability scan will be performed on $DOMAINS_COUNT live domains${NC}"

# Create URL list - direct copy
cp "$LIVE_DOMAINS_FILE" "$VULN_SCAN_DIR/domain_urls.txt"
URL_LIST="$VULN_SCAN_DIR/domain_urls.txt"
URLS_COUNT=$(wc -l < "$URL_LIST")
echo -e "${GREEN}[+] Scan will be performed on $URLS_COUNT URLs${NC}"

# Check IP list
IP_FILE=""

# Check IP lists in temp directory based on scan mode
if [ "$SCAN_MODE" = "short" ] && [ -f "$TEMP_DIR/short_ips.txt" ]; then
    IP_FILE="$TEMP_DIR/short_ips.txt"
    echo -e "${BLUE}[+] Using filtered IP list for short scan mode${NC}"
elif [ "$SCAN_MODE" = "medium" ] && [ -f "$TEMP_DIR/medium_ips.txt" ]; then
    IP_FILE="$TEMP_DIR/medium_ips.txt"
    echo -e "${BLUE}[+] Using filtered IP list for medium scan mode${NC}"
elif [ -f "$TEMP_DIR/all_ips.txt" ]; then
    IP_FILE="$TEMP_DIR/all_ips.txt"
    echo -e "${BLUE}[+] Using all filtered IP list${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Using IP list from subdomain_brute module${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_enum/dnsx_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Using IP list from subdomain_enum module${NC}"
else
    echo -e "${YELLOW}[!] IP list not found${NC}"
    echo -e "${YELLOW}[!] LazyHunter scan will be skipped${NC}"
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

# Progress report function
report_progress() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local elapsed_formatted=$(format_time $elapsed)
    echo -e "${CYAN}[*] Elapsed time: $elapsed_formatted${NC}"
}

# 1. Vulnerability scan with Nuclei
echo -e "\n${MAGENTA}#----- Vulnerability Scan with Nuclei -----#${NC}"
if command -v nuclei &> /dev/null; then
    echo -e "${BLUE}[+] Starting Nuclei scan...${NC}"
    echo -e "${CYAN}[*] This process may take a while${NC}"
    
    # Nuclei scan start time
    NUCLEI_START=$(date +%s)
    
    # Run nuclei with desired parameters
    nuclei -l "$LIVE_DOMAINS_FILE" -uc -v -as -nc -r "$RESOLVER_FILE" -rate-limit 5 -o "$VULN_SCAN_DIR/nuclei_results.txt"
    
    # Nuclei scan end time
    NUCLEI_END=$(date +%s)
    NUCLEI_TIME=$((NUCLEI_END - NUCLEI_START))
    NUCLEI_TIME_FORMATTED=$(format_time $NUCLEI_TIME)
    
    # Separate results by severity
    if [ -f "$VULN_SCAN_DIR/nuclei_results.txt" ]; then
        # Critical
        grep -i "\[critical\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_critical.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_critical.txt"
        CRIT_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_critical.txt" 2>/dev/null || echo 0)
        
        # High
        grep -i "\[high\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_high.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_high.txt"
        HIGH_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_high.txt" 2>/dev/null || echo 0)
        
        # Medium
        grep -i "\[medium\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_medium.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_medium.txt"
        MED_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_medium.txt" 2>/dev/null || echo 0)
        
        # Low
        grep -i "\[low\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_low.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_low.txt"
        LOW_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_low.txt" 2>/dev/null || echo 0)
        
        # Info
        grep -i "\[info\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_info.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_info.txt"
        INFO_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_info.txt" 2>/dev/null || echo 0)
        
        echo -e "${GREEN}[+] Nuclei scan completed: Duration: $NUCLEI_TIME_FORMATTED${NC}"
        echo -e "${GREEN}[+] Results:${NC}"
        echo -e "   ${RED}Critical: $CRIT_COUNT${NC}"
        echo -e "   ${MAGENTA}High: $HIGH_COUNT${NC}"
        echo -e "   ${YELLOW}Medium: $MED_COUNT${NC}"
        echo -e "   ${BLUE}Low: $LOW_COUNT${NC}"
        echo -e "   ${CYAN}Info: $INFO_COUNT${NC}"
    else
        echo -e "${YELLOW}[!] Nuclei result file was not created${NC}"
    fi
else
    echo -e "${RED}[-] nuclei not found${NC}"
fi

report_progress

# 2. IP-based vulnerability scan with LazyHunter
echo -e "\n${MAGENTA}#----- IP-based Vulnerability Scan with LazyHunter -----#${NC}"
if command -v lazyhunter &> /dev/null && [ -n "$IP_FILE" ]; then
    echo -e "${BLUE}[+] Starting LazyHunter scan...${NC}"
    echo -e "${CYAN}[*] This process may take a while${NC}"
    
    # Run LazyHunter with desired parameters
    lazyhunter -f "$IP_FILE" --cve+ports --host | tee "$VULN_SCAN_DIR/lazyhunter_vulns.txt"
    
    # Detect number of CVEs
    LH_CVES=$(grep -c "CVE-" "$VULN_SCAN_DIR/lazyhunter_vulns.txt" 2>/dev/null || echo 0)
    
    if [ $LH_CVES -gt 0 ]; then
        echo -e "${GREEN}[+] LazyHunter scan completed: $LH_CVES potential CVEs found${NC}"
    else
        echo -e "${GREEN}[+] LazyHunter scan completed: No CVEs found${NC}"
    fi
elif [ -z "$IP_FILE" ]; then
    echo -e "${YELLOW}[!] LazyHunter scan skipped because IP list was not found${NC}"
else
    echo -e "${RED}[-] lazyhunter not found${NC}"
fi

report_progress

# 3. HTTP request smuggling scan with HTTP Smuggler
echo -e "\n${MAGENTA}#----- HTTP Smuggler Scan -----#${NC}"
if command -v smuggler &> /dev/null; then
    echo -e "${BLUE}[+] Starting HTTP Smuggling vulnerability scan...${NC}"
    
    # Run smuggler for each URL
    while read -r url; do
        # Remove protocol part from URL (http:// or https://)
        domain=$(echo "$url" | sed 's/^https\?:\/\///')
        echo -e "${CYAN}[*] Smuggler: Scanning $domain...${NC}"
        smuggler -u "$domain" --no-color | tee -a "$VULN_SCAN_DIR/smuggler_vulns.txt"
    done < "$URL_LIST"
    
    SMUGGLER_VULNS=$(grep -c "Vulnerable" "$VULN_SCAN_DIR/smuggler_vulns.txt" 2>/dev/null || echo 0)
    
    if [ $SMUGGLER_VULNS -gt 0 ]; then
        echo -e "${GREEN}[+] HTTP Smuggling scan completed: $SMUGGLER_VULNS potential vulnerabilities found${NC}"
    else
        echo -e "${GREEN}[+] HTTP Smuggling scan completed: No vulnerabilities found${NC}"
    fi
else
    echo -e "${RED}[-] smuggler not found${NC}"
fi

report_progress

# 4. Vulnerable endpoint scan with GoChopChop
echo -e "\n${MAGENTA}#----- GoChopChop Endpoint Scan -----#${NC}"
if command -v chopchop &> /dev/null; then
    echo -e "${BLUE}[+] Starting GoChopChop scan...${NC}"
    
    # ChopChop config file path
    CHOPCHOP_CONFIG="$OUTPUT_DIR/../../setup/ChopChop/chopchop.yml"
    
    if [ -f "$CHOPCHOP_CONFIG" ]; then
        echo -e "${GREEN}[+] ChopChop config file found: $CHOPCHOP_CONFIG${NC}"
        
        # Run GoChopChop with config file
        chopchop scan -u "$URL_LIST" -k --threads 5 -c "$CHOPCHOP_CONFIG" --export-filename "$VULN_SCAN_DIR/chopchop_vulns.txt"
    else
        echo -e "${YELLOW}[!] ChopChop config file not found, downloading...${NC}"
        
        # Check and create ChopChop config directory
        CONFIG_DIR=$(dirname "$CHOPCHOP_CONFIG")
        if [ ! -d "$CONFIG_DIR" ]; then
            mkdir -p "$CONFIG_DIR"
        fi
        
        # Download chopchop.yml from GitHub
        if wget -q "https://raw.githubusercontent.com/michelin/ChopChop/refs/heads/master/chopchop.yml" -O "$CHOPCHOP_CONFIG"; then
            echo -e "${GREEN}[+] ChopChop config file successfully downloaded: $CHOPCHOP_CONFIG${NC}"
            
            # Run GoChopChop with downloaded config file
            chopchop scan -u "$URL_LIST" -k --threads 5 --config "$CHOPCHOP_CONFIG" --export-filename "$VULN_SCAN_DIR/chopchop_vulns.txt"
        else
            echo -e "${RED}[-] ChopChop config file could not be downloaded, using default config${NC}"
            
            # Run GoChopChop with default config
            chopchop scan -u "$URL_LIST" -k --threads 5 --export-filename "$VULN_SCAN_DIR/chopchop_vulns.txt"
        fi
    fi
    
    if [ -f "$VULN_SCAN_DIR/chopchop_vulns.txt" ]; then
        GOCHOP_VULNS=$(grep -c "Vulnerable" "$VULN_SCAN_DIR/chopchop_vulns.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] GoChopChop scan completed: $GOCHOP_VULNS vulnerable endpoints found${NC}"
    else
        echo -e "${GREEN}[+] GoChopChop scan completed: Result file could not be created${NC}"
        GOCHOP_VULNS=0
    fi
else
    echo -e "${RED}[-] chopchop not found${NC}"
    GOCHOP_VULNS=0
fi

report_progress

# 5. Hidden file scan with Snallygaster
echo -e "\n${MAGENTA}#----- Snallygaster Hidden File Scan -----#${NC}"
if command -v snallygaster &> /dev/null; then
    echo -e "${BLUE}[+] Starting Snallygaster scan...${NC}"
    
    # Get only domain names (without URL)
    cat "$LIVE_DOMAINS_FILE" > "$VULN_SCAN_DIR/snallygaster_domains.txt"
    
    # Run snallygaster with desired parameters
    snallygaster --nohttp --json "$VULN_SCAN_DIR/snallygaster_domains.txt" > "$VULN_SCAN_DIR/snallygaster_json.txt" 2>/dev/null
    
    # Convert JSON to text output for more readable format
    if [ -f "$VULN_SCAN_DIR/snallygaster_json.txt" ]; then
        grep -o '"url":"[^\"]*"' "$VULN_SCAN_DIR/snallygaster_json.txt" | \
        sed 's/"url":"//g' | sed 's/"//g' > "$VULN_SCAN_DIR/snallygaster_findings.txt"
        
        SNALLY_FINDINGS=$(wc -l < "$VULN_SCAN_DIR/snallygaster_findings.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] Snallygaster scan completed: $SNALLY_FINDINGS potential findings${NC}"
    else
        echo -e "${GREEN}[+] Snallygaster scan completed: No hidden files found${NC}"
        SNALLY_FINDINGS=0
    fi
else
    echo -e "${RED}[-] snallygaster not found${NC}"
    SNALLY_FINDINGS=0
fi

report_progress

# 6. Backup file scan with BFAC
echo -e "\n${MAGENTA}#----- Backup File Access Checker (BFAC) Scan -----#${NC}"
if command -v bfac &> /dev/null; then
    echo -e "${BLUE}[+] Starting BFAC scan...${NC}"
    
    # Run BFAC with desired parameters
    bfac --list "$LIVE_DOMAINS_FILE" \
         --threads 5 \
         --request-rate-throttling 10 \
         -ra \
         -o "$VULN_SCAN_DIR/bfac_vulns.txt"
    
    if [ -f "$VULN_SCAN_DIR/bfac_vulns.txt" ]; then
        BFAC_VULNS=$(grep -c "FOUND" "$VULN_SCAN_DIR/bfac_vulns.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] BFAC scan completed: $BFAC_VULNS potential accessible backup files found${NC}"
    else
        echo -e "${GREEN}[+] BFAC scan completed: No accessible backup files found${NC}"
        BFAC_VULNS=0
    fi
else
    echo -e "${RED}[-] bfac not found${NC}"
    BFAC_VULNS=0
fi

report_progress

# Create summary report
echo -e "\n${MAGENTA}#============ Vulnerability Scan Summary ============#${NC}"
echo -e "${BLUE}Target:${NC} $DOMAIN"
echo -e "${BLUE}Number of Subdomains Scanned:${NC} $DOMAINS_COUNT"

# Nuclei results
if [ -f "$VULN_SCAN_DIR/nuclei_results.txt" ]; then
    NUCLEI_TOTAL=$(wc -l < "$VULN_SCAN_DIR/nuclei_results.txt" 2>/dev/null || echo 0)
    echo -e "${BLUE}Nuclei Findings:${NC} $NUCLEI_TOTAL"
    if [ $CRIT_COUNT -gt 0 ]; then echo -e "  ${RED}Critical:${NC} $CRIT_COUNT"; fi
    if [ $HIGH_COUNT -gt 0 ]; then echo -e "  ${MAGENTA}High:${NC} $HIGH_COUNT"; fi
    if [ $MED_COUNT -gt 0 ]; then echo -e "  ${YELLOW}Medium:${NC} $MED_COUNT"; fi
    if [ $LOW_COUNT -gt 0 ]; then echo -e "  ${BLUE}Low:${NC} $LOW_COUNT"; fi
    if [ $INFO_COUNT -gt 0 ]; then echo -e "  ${CYAN}Info:${NC} $INFO_COUNT"; fi
fi

# Other tool findings
if [ -f "$VULN_SCAN_DIR/lazyhunter_vulns.txt" ]; then
    echo -e "${BLUE}LazyHunter Findings:${NC} $LH_CVES"
fi

if [ -f "$VULN_SCAN_DIR/smuggler_vulns.txt" ]; then
    echo -e "${BLUE}HTTP Smuggling Findings:${NC} $SMUGGLER_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/chopchop_vulns.txt" ]; then
    echo -e "${BLUE}GoChopChop Findings:${NC} $GOCHOP_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/snallygaster_findings.txt" ]; then
    echo -e "${BLUE}Snallygaster Findings:${NC} $SNALLY_FINDINGS"
fi

if [ -f "$VULN_SCAN_DIR/bfac_vulns.txt" ]; then
    echo -e "${BLUE}BFAC Findings:${NC} $BFAC_VULNS"
fi

# Total time
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_TIME_FORMATTED=$(format_time $TOTAL_TIME)
echo -e "${BLUE}Total Time:${NC} $TOTAL_TIME_FORMATTED"

echo -e "\n${GREEN}###------- Vulnerability scan completed: $DOMAIN -------###${NC}" 