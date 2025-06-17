#!/bin/bash

# JavaScript and Parameter Discovery Module
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
JS_DISCOVERY=false
PARAM_DISCOVERY=false
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
        -js|--javascript)
            JS_DISCOVERY=true
            shift
            ;;
        -p|--params)
            PARAM_DISCOVERY=true
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
    echo "Usage: $0 <domain> [-o output_dir] [-js/--javascript] [-p/--params] [--scan-mode short|medium|big]"
    exit 1
fi

# Prepare output directory
JS_DIR="${OUTPUT_DIR}/js_param_discovery"
mkdir -p "$JS_DIR"
mkdir -p "$JS_DIR/js_files"
mkdir -p "$JS_DIR/param_files"

echo -e "${GREEN}###------- Starting JavaScript and Parameter Discovery: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $JS_DIR${NC}"
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
URL_LIST=""
case $SCAN_MODE in
    "short")
        if [ -f "$TEMP_DIR/short_urls.txt" ]; then
            URL_LIST="$TEMP_DIR/short_urls.txt"
            echo -e "${BLUE}[+] Short scan mode selected - Scanning with critical subdomains${NC}"
        else
            echo -e "${YELLOW}[!] Short mode URL list not found, using default list${NC}"
        fi
        ;;
    "medium")
        if [ -f "$TEMP_DIR/medium_urls.txt" ]; then
            URL_LIST="$TEMP_DIR/medium_urls.txt"
            echo -e "${BLUE}[+] Medium scan mode selected - Scanning with important subdomains${NC}"
        else
            echo -e "${YELLOW}[!] Medium mode URL list not found, using default list${NC}"
        fi
        ;;
    *)
        echo -e "${BLUE}[+] Big scan mode selected - Scanning all subdomains${NC}"
        if [ -f "$TEMP_DIR/all_urls.txt" ]; then
            URL_LIST="$TEMP_DIR/all_urls.txt"
        fi
        ;;
esac

# If URL_LIST is still empty, find from default sources
if [ -z "$URL_LIST" ]; then
    if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
        URL_LIST="$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt"
        echo -e "${BLUE}[+] Using live domains from subs_live module${NC}"
    elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
        URL_LIST="$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt"
        echo -e "${BLUE}[+] Using live domains from subdomain_brute module${NC}"
    elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
        URL_LIST="$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt"
        echo -e "${BLUE}[+] Using live domains from subdomain_enum module${NC}"
    else
        echo -e "${YELLOW}[!] No live subdomain list found${NC}"
        echo -e "${YELLOW}[!] Using main domain...${NC}"
        if [[ $DOMAIN != http://* ]] && [[ $DOMAIN != https://* ]]; then
            echo "https://$DOMAIN" > "$JS_DIR/domain.txt"
        else
            echo "$DOMAIN" > "$JS_DIR/domain.txt"
        fi
        URL_LIST="$JS_DIR/domain.txt"
    fi
fi

URLS_COUNT=$(wc -l < "$URL_LIST")
echo -e "${GREEN}[+] Discovery will be performed on $URLS_COUNT URLs${NC}"

# JavaScript Discovery process
if $JS_DISCOVERY; then
    echo -e "${BLUE}[+] Starting JavaScript Discovery...${NC}"
    
    # 1. Find JavaScript URLs with subjs
    echo -e "${BLUE}[+] Running subjs...${NC}"
    if command -v subjs &> /dev/null; then
        cat "$URL_LIST" | subjs -c 100 | tee "$JS_DIR/js_files/js_urls.txt"
        JS_URLS_COUNT=$(wc -l < "$JS_DIR/js_files/js_urls.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] subjs completed: $JS_URLS_COUNT JavaScript URLs found${NC}"
    else
        echo -e "${RED}[-] subjs not found${NC}"
    fi
    
    # 2. Find JavaScript URLs with getJS
    echo -e "${BLUE}[+] Running getJS...${NC}"
    if command -v getJS &> /dev/null; then
        getJS -input "$URL_LIST" -complete -resolve -output "$JS_DIR/js_files/getjs_urls.txt" 
        if [ -f "$JS_DIR/js_files/getjs_urls.txt" ]; then
            cat "$JS_DIR/js_files/getjs_urls.txt" | grep -E "http|https" > "$JS_DIR/js_files/getjs_urls_filtered.txt"
            mv "$JS_DIR/js_files/getjs_urls_filtered.txt" "$JS_DIR/js_files/getjs_urls.txt"
            GETJS_URLS_COUNT=$(wc -l < "$JS_DIR/js_files/getjs_urls.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] getJS completed: $GETJS_URLS_COUNT JavaScript URLs found${NC}"
        else
            echo -e "${YELLOW}[!] getJS did not find any results${NC}"
            touch "$JS_DIR/js_files/getjs_urls.txt"
        fi
    else
        echo -e "${RED}[-] getJS not found${NC}"
    fi
    
    # Check all_unique_urls.txt file from URL Discovery module
    if [ -f "${OUTPUT_DIR}/url_discovery/all_unique_urls.txt" ]; then
        echo -e "${BLUE}[+] Checking all URLs from URL Discovery module...${NC}"
        # Extract URLs ending with .js
        cat "${OUTPUT_DIR}/url_discovery/all_unique_urls.txt" | grep -i "\.js$" > "$JS_DIR/js_files/urls_discovery_js.txt"
        JS_FROM_URL_DISC=$(wc -l < "$JS_DIR/js_files/urls_discovery_js.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] Found $JS_FROM_URL_DISC JavaScript URLs from URL Discovery module${NC}"
    else
        echo -e "${YELLOW}[!] all_unique_urls.txt file not found in URL Discovery module${NC}"
    fi
    
    # Merge all JavaScript URLs
    cat "$JS_DIR/js_files"/*.txt 2>/dev/null | sort -u > "$JS_DIR/js_files/all_js_urls.txt"
    TOTAL_JS=$(wc -l < "$JS_DIR/js_files/all_js_urls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Found total $TOTAL_JS unique JavaScript URLs${NC}"
    
    if [ $TOTAL_JS -gt 0 ]; then
        # Download JavaScript files
        echo -e "${BLUE}[+] Downloading JavaScript files...${NC}"
        mkdir -p "$JS_DIR/js_files/downloaded_js"
        
        if command -v aria2c &> /dev/null; then
            aria2c -d "$JS_DIR/js_files/downloaded_js" -i "$JS_DIR/js_files/all_js_urls.txt" --timeout=45 --max-tries=3 --retry-wait=10 -j 1 --max-overall-download-limit=500K --split=1 --max-connection-per-server=1

            JS_FILES_COUNT=$(find "$JS_DIR/js_files/downloaded_js" -name "*.js" | wc -l)
            echo -e "${GREEN}[+] JavaScript files downloaded: $JS_FILES_COUNT files${NC}"
        else
            echo -e "${RED}[-] aria2c not found, cannot download JS files${NC}"
            echo -e "${YELLOW}[!] Please install aria2c with 'sudo apt install aria2' command${NC}"
        fi
    fi
    
    echo -e "${GREEN}[+] JavaScript Discovery completed${NC}"
    echo -e "${YELLOW}[!] Run js_analysis.sh module to analyze JavaScript files${NC}"
fi

# Parameter Discovery process
if $PARAM_DISCOVERY; then
    echo -e "${BLUE}[+] Starting Parameter Discovery...${NC}"
    
    # Use URL list (already determined above)
    URLS_COUNT=$(wc -l < "$URL_LIST")
    echo -e "${GREEN}[+] Parameter discovery will be performed on $URLS_COUNT URLs${NC}"
    
    # 1. Parameter discovery with ParamSpider
    echo -e "${BLUE}[+] Running ParamSpider...${NC}"
    if command -v paramspider &> /dev/null; then
        # Get absolute path of URL file
        ABSOLUTE_URL_LIST=$(realpath "$URL_LIST")
        
        cd "$JS_DIR/param_files" || exit
        paramspider -l "$ABSOLUTE_URL_LIST"
        cd - > /dev/null || exit
        
        if [ -d "$JS_DIR/param_files/results" ]; then
            cat "$JS_DIR/param_files/results"/*.txt 2>/dev/null | sort -u > "$JS_DIR/param_files/paramspider_urls.txt"
            PARAMS_COUNT=$(wc -l < "$JS_DIR/param_files/paramspider_urls.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] ParamSpider completed: $PARAMS_COUNT parameter URLs found${NC}"
        else
            echo -e "${YELLOW}[!] ParamSpider did not find any results${NC}"
        fi
    else
        echo -e "${RED}[-] ParamSpider not found${NC}"
    fi
    
    # 2. Parameter discovery with x8
    echo -e "${BLUE}[+] Running x8...${NC}"
    if command -v x8 &> /dev/null; then
        x8 -u "$URL_LIST" -o "$JS_DIR/param_files/x8_results.txt"
        if [ -f "$JS_DIR/param_files/x8_results.txt" ]; then
            X8_PARAMS_COUNT=$(wc -l < "$JS_DIR/param_files/x8_results.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] x8 completed: $X8_PARAMS_COUNT parameter URLs found${NC}"
        else
            echo -e "${YELLOW}[!] x8 did not find any results${NC}"
        fi
    else
        echo -e "${RED}[-] x8 not found${NC}"
    fi
    
    # 3. Find unknown parameters in URLs with Arjun
    echo -e "${BLUE}[+] Running Arjun...${NC}"
    if command -v arjun &> /dev/null; then
        arjun -i "$URL_LIST" -oT "$JS_DIR/param_files/arjun_hidden_params.txt"
        if [ -f "$JS_DIR/param_files/arjun_hidden_params.txt" ]; then
            ARJUN_PARAMS_COUNT=$(wc -l < "$JS_DIR/param_files/arjun_hidden_params.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] Arjun completed: $ARJUN_PARAMS_COUNT hidden parameters found${NC}"
        else
            echo -e "${YELLOW}[!] Arjun did not find any results${NC}"
        fi
    else
        echo -e "${RED}[-] Arjun not found${NC}"
    fi
    
    # Merge all parameter results
    cat "$JS_DIR/param_files"/*.txt 2>/dev/null | sort -u > "$JS_DIR/param_files/all_params.txt"
    TOTAL_PARAMS=$(wc -l < "$JS_DIR/param_files/all_params.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Found total $TOTAL_PARAMS unique parameter URLs${NC}"
    
    echo -e "${GREEN}[+] Parameter Discovery completed${NC}"
    echo -e "${YELLOW}[!] Run param_analysis.sh module to analyze parameters${NC}"
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
echo -e "${CYAN}[+] Total discovery time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Discovery completed: $DOMAIN -------###${NC}" 
