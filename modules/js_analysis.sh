#!/bin/bash

# JavaScript Analysis Module
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
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# Create directory for JavaScript analysis
JS_ANALYSIS_DIR="${OUTPUT_DIR}/js_analysis"
mkdir -p "$JS_ANALYSIS_DIR"

echo -e "${GREEN}###------- Starting JavaScript Analysis: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $JS_ANALYSIS_DIR${NC}"

# Check JavaScript files downloaded from JS Discovery module
JS_FILES_DIR=""
if [ -d "${OUTPUT_DIR}/js_param_discovery/js_files/downloaded_js" ]; then
    JS_FILES_DIR="${OUTPUT_DIR}/js_param_discovery/js_files/downloaded_js"
    echo -e "${BLUE}[+] Using JavaScript files downloaded from JS Discovery module${NC}"
    JS_FILES_COUNT=$(find "$JS_FILES_DIR" -name "*.js" | wc -l)
    echo -e "${GREEN}[+] $JS_FILES_COUNT JavaScript files will be analyzed${NC}"
else
    echo -e "${YELLOW}[!] No previously downloaded JavaScript files found${NC}"
    echo -e "${YELLOW}[!] Please run js_and_param_discovery.sh with --js-discovery parameter first${NC}"
fi

# 1. Search for secrets in JavaScript files with TruffleHog
if command -v trufflehog &> /dev/null && [ -d "$JS_FILES_DIR" ]; then
    echo -e "${BLUE}[+] Running TruffleHog...${NC}"
    trufflehog filesystem "$JS_FILES_DIR" --only-verified  --include-detectors=all | tee "$JS_ANALYSIS_DIR/trufflehog_results.txt"
    if [ -s "$JS_ANALYSIS_DIR/trufflehog_results.txt" ]; then
        echo -e "${GREEN}[+] TruffleHog completed: Results saved to trufflehog_results.txt${NC}"
    else
        echo -e "${YELLOW}[!] TruffleHog did not find any secrets${NC}"
        rm "$JS_ANALYSIS_DIR/trufflehog_results.txt" 2>/dev/null
    fi
else
    echo -e "${RED}[-] TruffleHog not found or JavaScript files not available${NC}"
fi

# 2. Search for sensitive information in JS files using regex
if [ -d "$JS_FILES_DIR" ]; then
    echo -e "${BLUE}[+] Searching for sensitive information in JavaScript files using regex...${NC}"

    # Regex list for API keys, tokens, passwords etc. (show only matching part)
    grep -r -i -o -E "api[_-]?key\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}['\"]?|secret[_-]?key\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}['\"]?|password\s*[:=]\s*['\"]?[A-Za-z0-9!@#$%^&*()_+\-]{6,}['\"]?|auth[_-]?token\s*[:=]\s*['\"]?[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+['\"]?" "$JS_FILES_DIR" > "$JS_ANALYSIS_DIR/regex_results_sensitive_strings.txt"

    # Regex for URLs
    grep -r -i -o -E "https?://[a-zA-Z0-9./?=_-]{10,}" "$JS_FILES_DIR" > "$JS_ANALYSIS_DIR/regex_results_urls.txt"

    # Regex for endpoints
    grep -r -i -o -E "/api/[a-zA-Z0-9/_-]{2,}" "$JS_FILES_DIR" > "$JS_ANALYSIS_DIR/regex_results_endpoints.txt"

    REGEX_HITS=$(wc -l < "$JS_ANALYSIS_DIR/regex_results_sensitive_strings.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Regex search completed: $REGEX_HITS potential sensitive information found${NC}"
else
    echo -e "${RED}[-] JavaScript files not available${NC}"
fi

# 3. Extract endpoints from JS files using LinkFinder
if command -v linkfinder &> /dev/null  && [ -d "$JS_FILES_DIR" ]; then
    echo -e "${BLUE}[+] Running LinkFinder...${NC}"
    mkdir -p "$JS_ANALYSIS_DIR/linkfinder_results"
    find "$JS_FILES_DIR" -name "*.js" | while read -r js_file; do
        filename=$(basename "$js_file")
        linkfinder -i "$js_file" -o "$JS_ANALYSIS_DIR/linkfinder_results/${filename%.js}.html" > /dev/null 2>&1
    done
    
    LF_FILES_COUNT=$(find "$JS_ANALYSIS_DIR/linkfinder_results" -name "*.html" | wc -l)
    echo -e "${GREEN}[+] LinkFinder completed: $LF_FILES_COUNT files analyzed${NC}"
else
    echo -e "${RED}[-] LinkFinder not found or JavaScript files not available${NC}"
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
echo -e "${CYAN}[+] Total JavaScript analysis time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- JavaScript analysis completed: $DOMAIN -------###${NC}" 