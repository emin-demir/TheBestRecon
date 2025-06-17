#!/bin/bash

# Parameter Analysis Module
# TheBestRecon

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "Usage: $0 <domain> [-o output_dir] [-t threads]"
    exit 1
fi

# Default values
THREADS=5

# Set output directory
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# Create directory for parameter analysis
PARAM_ANALYSIS_DIR="${OUTPUT_DIR}/param_analysis"
mkdir -p "$PARAM_ANALYSIS_DIR"

echo -e "${GREEN}###------- Starting Parameter Analysis: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $PARAM_ANALYSIS_DIR${NC}"

# Save start time
START_TIME=$(date +%s)

# Check parameter URLs
PARAM_URLS_FILE=""
if [ -f "${OUTPUT_DIR}/js_param_discovery/param_files/paramspider_urls.txt" ]; then
    PARAM_URLS_FILE="${OUTPUT_DIR}/js_param_discovery/param_files/paramspider_urls.txt"
    echo -e "${BLUE}[+] Using parameter URLs from JS & Param Discovery module${NC}"
    PARAMS_COUNT=$(wc -l < "$PARAM_URLS_FILE")
    echo -e "${GREEN}[+] $PARAMS_COUNT parameter URLs will be analyzed${NC}"
else
    echo -e "${YELLOW}[!] Parameter URL list not found${NC}"
    echo -e "${YELLOW}[!] Please run js_and_param_discovery.sh with --param-discovery parameter first${NC}"
    
    # Alternative: Extract parameter URLs from URL discovery
    if [ -f "$OUTPUT_DIR/url_discovery/all_unique_urls.txt" ]; then
        echo -e "${BLUE}[+] Extracting parameter URLs from URL Discovery module...${NC}"
        cat "$OUTPUT_DIR/url_discovery/all_unique_urls.txt" | grep -P "\?" | sort -u > "$PARAM_ANALYSIS_DIR/grep_param_urls.txt"
        GREP_PARAMS_COUNT=$(wc -l < "$PARAM_ANALYSIS_DIR/grep_param_urls.txt" 2>/dev/null || echo 0)
        
        if [ $GREP_PARAMS_COUNT -gt 0 ]; then
            echo -e "${GREEN}[+] Extracted $GREP_PARAMS_COUNT parameter URLs from URL list${NC}"
            PARAM_URLS_FILE="$PARAM_ANALYSIS_DIR/grep_param_urls.txt"
        else
            echo -e "${RED}[-] No parameter URLs found${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[-] URL list not found${NC}"
        exit 1
    fi
fi

# 1. Parameter analysis with KXSS
if command -v kxss &> /dev/null; then
    echo -e "${BLUE}[+] Starting XSS scan with KXSS...${NC}"
    
    # Calculate total URL count
    TOTAL_URLS=$(wc -l < "$PARAM_URLS_FILE")
    CURRENT_URL=0
    
    # Scan each URL with KXSS
    cat "$PARAM_URLS_FILE" | while read -r url; do
        CURRENT_URL=$((CURRENT_URL + 1))
        echo -e "${CYAN}[*] KXSS [${CURRENT_URL}/${TOTAL_URLS}]: Scanning $url...${NC}"
        echo "$url" | kxss >> "$PARAM_ANALYSIS_DIR/kxss_raw_results.txt"
    done
    
    KXSS_VULNS=$(wc -l < "$PARAM_ANALYSIS_DIR/kxss_raw_results.txt" 2>/dev/null || echo 0)
    
    if [ $KXSS_VULNS -gt 0 ]; then
        echo -e "${GREEN}[+] KXSS completed: Found $KXSS_VULNS potential XSS vulnerabilities${NC}"
        
        # Extract URLs from KXSS output
        echo -e "${BLUE}[+] Extracting URLs from KXSS output...${NC}"
        grep -o "URL: [^[:space:]]*" "$PARAM_ANALYSIS_DIR/kxss_raw_results.txt" | sed 's/URL: //' > "$PARAM_ANALYSIS_DIR/kxss_extracted_urls.txt"
        EXTRACTED_URLS=$(wc -l < "$PARAM_ANALYSIS_DIR/kxss_extracted_urls.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] Extracted ${EXTRACTED_URLS} URLs from KXSS output${NC}"
        
        # Copy extracted URLs to file for XSStrike and Dalfox
        cp "$PARAM_ANALYSIS_DIR/kxss_extracted_urls.txt" "$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    else
        echo -e "${GREEN}[+] KXSS completed: No XSS vulnerabilities found${NC}"
        # Use original URL list
        cp "$PARAM_URLS_FILE" "$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    fi
else
    echo -e "${RED}[-] KXSS not found${NC}"
    # Use original URL list
    cp "$PARAM_URLS_FILE" "$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
fi

# 2. Parameter analysis with XSStrike
if command -v xsstrike &> /dev/null ; then
    echo -e "${BLUE}[+] Starting XSS scan with XSStrike...${NC}"
    
    # Use extracted URLs
    XSSTRIKE_URL_LIST="$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    XSSTRIKE_URLS_COUNT=$(wc -l < "$XSSTRIKE_URL_LIST" 2>/dev/null || echo 0)
    echo -e "${BLUE}[+] XSStrike will run on ${XSSTRIKE_URLS_COUNT} URLs...${NC}"
    
    # Run XSStrike
    xsstrike --seeds "$XSSTRIKE_URL_LIST" --threads "$THREADS" --log-file "$PARAM_ANALYSIS_DIR/xsstrike_vulnerable.log"
    
    if [ -f "$PARAM_ANALYSIS_DIR/xsstrike_vulnerable.log" ]; then
        echo -e "${GREEN}[+] XSStrike completed: Results saved to xsstrike_vulnerable.log${NC}"
        
        # Extract vulnerabilities from log
        XSS_VULNS=$(wc -l < "$PARAM_ANALYSIS_DIR/xsstrike_vulnerable.log" 2>/dev/null || echo 0)
        
        if [ $XSS_VULNS -gt 0 ]; then
            echo -e "${GREEN}[+] XSStrike: Found $XSS_VULNS potential XSS vulnerabilities${NC}"
        else
            echo -e "${GREEN}[+] XSStrike: No XSS vulnerabilities found${NC}"
        fi
    else
        echo -e "${YELLOW}[!] XSStrike log file not created${NC}"
    fi
else
    echo -e "${RED}[-] XSStrike not found. Should be in tools/XSStrike directory${NC}"
fi

# 3. Parameter analysis with Dalfox
if command -v dalfox &> /dev/null; then
    echo -e "${BLUE}[+] Starting XSS scan with Dalfox...${NC}"
    
    # Use extracted URLs
    DALFOX_URL_LIST="$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    DALFOX_URLS_COUNT=$(wc -l < "$DALFOX_URL_LIST" 2>/dev/null || echo 0)
    echo -e "${BLUE}[+] Dalfox will run on ${DALFOX_URLS_COUNT} URLs...${NC}"
    
    # Run Dalfox scan
    dalfox file "$DALFOX_URL_LIST" -o "$PARAM_ANALYSIS_DIR/dalfox_vulnerable.json" -b hahwul.xss.ht --format json -w 5 --skip-mining-all
    
    if [ -f "$PARAM_ANALYSIS_DIR/dalfox_vulnerable.json" ]; then
        echo -e "${GREEN}[+] Dalfox completed: Results saved to dalfox_vulnerable.json${NC}"
        
        # Extract vulnerabilities from JSON file (simple grep, better JSON parser can be used in real project)
        DALFOX_VULNS=$(grep -c "vulnerable" "$PARAM_ANALYSIS_DIR/dalfox_vulnerable.json" 2>/dev/null || echo 0)
        
        if [ $DALFOX_VULNS -gt 0 ]; then
            echo -e "${GREEN}[+] Dalfox: Found $DALFOX_VULNS XSS vulnerabilities${NC}"
        else
            echo -e "${GREEN}[+] Dalfox: No XSS vulnerabilities found${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Dalfox results file not created${NC}"
    fi
else
    echo -e "${RED}[-] Dalfox not found${NC}"
fi

TOTAL_VULNS=$(wc -l < "$KXSS_VULNS" 2>/dev/null || echo 0)

if [ $TOTAL_VULNS -gt 0 ]; then
    echo -e "${GREEN}[+] Found total $TOTAL_VULNS potential XSS vulnerabilities${NC}"
    echo -e "${YELLOW}[!] You can review the results in $PARAM_ANALYSIS_DIR/all_vulnerabilities.txt${NC}"
else
    echo -e "${GREEN}[+] No XSS vulnerabilities found${NC}"
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
echo -e "${CYAN}[+] Total parameter analysis time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Parameter analysis completed: $DOMAIN -------###${NC}"