#!/bin/bash

# TheBestRecon - Comprehensive Recon Tool
# Main script that controls all modules

# Color definitions
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "  _______ _          ____            _   _____                      "
echo " |__   __| |        |  _ \          | | |  __ \                     "
echo "    | |  | |__   ___| |_) | ___  ___| |_| |__) |___  ___ ___  _ __  "
echo "    | |  | '_ \ / _ \  _ < / _ \/ __| __|  _  // _ \/ __/ _ \| '_ \ "
echo "    | |  | | | |  __/ |_) |  __/\__ \ |_| | \ \  __/ (_| (_) | | | |"
echo "    |_|  |_| |_|\___|____/ \___||___/\__|_|  \_\___|\___\___/|_| |_|"
echo -e "${NC}"
echo -e "${YELLOW}Comprehensive Recon Tool${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
echo ""

# Logging function
log() {
    local log_level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Print to screen
    case $log_level in
        "INFO")
            echo -e "${BLUE}[+] ${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[+] ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[!] ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[-] ${message}${NC}"
            ;;
    esac
    
    # Write to log file
    mkdir -p logs
    echo "[$timestamp] [$log_level] $message" >> "logs/recon_$(date +%Y%m%d).log"
}

# Functions
show_help() {
    echo -e "${YELLOW}TheBestRecon - Comprehensive Recon Tool${NC}"
    echo ""
    echo -e "Usage: ${CYAN}$0 [options]${NC}"
    echo ""
    echo -e "${BLUE}Options:${NC}"
    echo -e "  ${GREEN}-d, --domain${NC} <domain>        Target domain (required, multiple can be specified but not recommended)"
    echo -e "  ${GREEN}-o, --output${NC} <directory>     Output directory (default: output/)"
    echo -e "  ${GREEN}-h, --help${NC}                   Usage instructions (Help Menu)"
    echo -e "  ${GREEN}-a, --api-config${NC} <file>      Configuration file for API keys"
    echo ""
    echo -e "${BLUE}Scan Modes:${NC}"
    echo -e "  ${MAGENTA}--short-scan${NC}               Short scan - Only scans 10 critical subdomains"
    echo -e "  ${MAGENTA}--medium-scan${NC}              Medium scan - Scans 30-50 important subdomains"
    echo -e "  ${MAGENTA}--big-scan${NC}                 Big scan - Scans all subdomains (default)"
    echo ""
    echo -e "${BLUE}Modules:${NC}"
    echo -e "  ${CYAN}--all-modules, -all${NC}          Run all modules"
    echo -e "  ${CYAN}--sub-enum, -sE${NC}              Run subdomain enumeration (assetfinder, subfinder, sublist3r, etc)"
    echo -e "  ${CYAN}--sub-brute, -sB${NC}             Run subdomain bruteforce (gobuster, amass)"
    echo -e "  ${CYAN}--subs-live, -sL${NC}             Run live subdomain check (httpx, httprobe)"
    echo -e "  ${CYAN}--screen-shoot, -sS${NC}          Take screenshots (aquatone)"
    echo -e "  ${CYAN}--url-discovery, -uD${NC}         Run URL Discovery (gau, waymore, katana, feroxbuster etc.)"
    echo -e "  ${CYAN}--js-discovery, -jD${NC}          Discover JavaScript files (subjs, getJS, Secretfinder)"
    echo -e "  ${CYAN}--param-discovery, -pD${NC}       Run parameter discovery (ParamSpider, Arjun)"
    echo -e "  ${CYAN}--js-analysis, -jS${NC}           Search for valuable data in JavaScript files (TruffleHog, Linkfinder, Grep)"
    echo -e "  ${CYAN}--param-analysis, -pmS${NC}        Performs XSS vulnerability detection on parameters (KXSS, Dalfox, XSStrike)"
    echo -e "  ${CYAN}--port-scan, -pS${NC}             Run port scanning (nmap, masscan, naabu)"
    echo -e "  ${CYAN}--vuln-scan, -vS${NC}             Run vulnerability scanning (nuclei, corscanner, smuggler, bfac)"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ${CYAN}$0 -d example.com -sE -pS${NC}"
    echo -e "  ${CYAN}$0 -d example.com --short-scan -all ${NC}"
    echo -e "  ${CYAN}$0 -d example.com --medium-scan -vS ${NC}"
    echo -e "  ${CYAN}$0 -d example.com -d example2.com -all ${NC}"
    echo -e "  ${CYAN}$0 -d example.com -all -a api_keys.txt ${NC}"
    echo -e "  ${CYAN}$0 -d example.com -sE -sL -sS -uD -jD -pD${NC}"
    exit 0
}

# Variables
DOMAINS=()
OUTPUT_DIR="output"
# Fixed API config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_CONFIG="$SCRIPT_DIR/config/config.json"
SUB_ENUM=false
SUB_BRUTE=false
PORT_SCAN=false
VULN_SCAN=false
JS_ANALYSIS=false
PARAM_ANALYSIS=false
SUBS_LIVE=false
SCREEN_SHOOT=false
URL_DISCOVERY=false
JS_DISCOVERY=false
PARAM_DISCOVERY=false
ALL_MODULES=false
# Determine scan mode (default: big)
SCAN_MODE="big"

# Parameter check
if [[ $# -eq 0 ]]; then
    show_help
fi

# Main directory check
if [[ ! -d "modules" ]]; then
    log "ERROR" "'modules' directory not found"
    log "ERROR" "Run this script in the TheBestRecon root directory"
    exit 1
fi

# Process parameters
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--domain)
            DOMAINS+=("$2")
            shift
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        -a|--api-config)
            # API_CONFIG parameter is no longer used, using fixed value
            log "WARNING" "-a parameter is being ignored. Using fixed API config file: $API_CONFIG"
            shift
            shift
            ;;
        -h|--help)
            show_help
            ;;
        --short-scan)
            SCAN_MODE="short"
            shift
            ;;
        --medium-scan)
            SCAN_MODE="medium"
            shift
            ;;
        --big-scan)
            SCAN_MODE="big"
            shift
            ;;
        --sub-enum|-sE)
            SUB_ENUM=true
            shift
            ;;
        --sub-brute|-sB)
            SUB_BRUTE=true
            shift
            ;;
        --port-scan|-pS)
            PORT_SCAN=true
            shift
            ;;
        --vuln-scan|-vS)
            VULN_SCAN=true
            shift
            ;;
        --js-analysis|-jS)
            JS_ANALYSIS=true
            shift
            ;;
        --param-analysis|-pmS)
            PARAM_ANALYSIS=true
            shift
            ;;
        --subs-live|-sL)
            SUBS_LIVE=true
            shift
            ;;
        --screen-shoot|-sS)
            SCREEN_SHOOT=true
            shift
            ;;
        --url-discovery|-uD)
            URL_DISCOVERY=true
            shift
            ;;
        --js-discovery|-jD)
            JS_DISCOVERY=true
            shift
            ;;
        --param-discovery|-pD)
            PARAM_DISCOVERY=true
            shift
            ;;
        --all-modules|-all)
            ALL_MODULES=true
            shift
            ;;
        *)
            log "ERROR" "Unknown parameter: $1"
            show_help
            ;;
    esac
done

# Domain parameter check
if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    log "ERROR" "At least one domain parameter is required"
    show_help
fi

# If all modules are selected
if $ALL_MODULES; then
    SUB_ENUM=true
    SUB_BRUTE=true
    PORT_SCAN=true
    VULN_SCAN=true
    JS_ANALYSIS=true
    PARAM_ANALYSIS=true
    SUBS_LIVE=true
    SCREEN_SHOOT=true
    URL_DISCOVERY=true
    JS_DISCOVERY=true
    PARAM_DISCOVERY=true
fi

# Prepare output directory
mkdir -p "$OUTPUT_DIR"

# Activate Python virtual environment
VENV_PATH="$SCRIPT_DIR/venv"
VENV_ACTIVATE="$VENV_PATH/bin/activate"

# Virtual environment check and activation
if [ -d "$VENV_PATH" ] && [ -f "$VENV_ACTIVATE" ]; then
    echo -e "\033[0;34m[+] Activating Python virtual environment...\033[0m"
    source "$VENV_ACTIVATE"
    echo -e "\033[0;32m[+] Python virtual environment activated\033[0m"
else
    echo -e "\033[0;31m[-] Python virtual environment not found: $VENV_ACTIVATE\033[0m"
    echo -e "\033[0;33m[!] Please run install_tools.sh first to install the required environment.\033[0m"
fi

# Selected scan mode
case $SCAN_MODE in
    "short")
        log "INFO" "Selected short scan mode - Only scans 10 critical subdomains"
        ;;
    "medium")
        log "INFO" "Selected medium scan mode - Scans 30-50 important subdomains"
        ;;
    "big")
        log "INFO" "Selected big scan mode - Scans all subdomains"
        ;;
esac

# Process each domain
for domain in "${DOMAINS[@]}"; do
    log "INFO" " Processing target domain: $domain "
    # Use only date in timestamp (GG-AA-YYYY format)
    datestamp=$(date +%d-%m-%Y)
    domain_output_dir="${OUTPUT_DIR}/${domain}_${datestamp}"
    mkdir -p "$domain_output_dir"
    
    log "INFO" " Results will be saved to: $domain_output_dir "
    
    # 1. Subdomain Enumeration
    if $SUB_ENUM; then
        # If SUB_BRUTE is active, skip dnsx in subdomain_enum
        SKIP_DNSX_PARAM=""
        if $SUB_BRUTE; then
            SKIP_DNSX_PARAM="--skip-dnsx"
        fi
        
        bash modules/subdomain_enum.sh "$domain" -a "$API_CONFIG" -o "$domain_output_dir" $SKIP_DNSX_PARAM
    fi
    
    # 2. Subdomain Bruteforce - DNS Bruteforce included
    if $SUB_BRUTE; then
        bash modules/subdomain_brute.sh "$domain" -o "$domain_output_dir"
    fi
    
    # 3. Subdomain Live Check and Screenshot
    if $SUBS_LIVE || $SCREEN_SHOOT; then
        LIVE_PARAM=""
        SCREENSHOT_PARAM=""
        
        if $SUBS_LIVE; then
            LIVE_PARAM="-l"
        fi
        
        if $SCREEN_SHOOT; then
            SCREENSHOT_PARAM="-s"
        fi
        
        bash modules/live_and_screenshot.sh "$domain" -o "$domain_output_dir" $LIVE_PARAM $SCREENSHOT_PARAM
    fi
    
    # Check if subdomain scanning was performed
    SUBDOMAIN_SCANNED=false
    if $SUB_ENUM || $SUB_BRUTE || $SUBS_LIVE; then
        SUBDOMAIN_SCANNED=true
    fi
    
    # Check if other modules need to be run
    NEED_URL_FILTERING=false
    if $VULN_SCAN || $URL_DISCOVERY || $JS_DISCOVERY || $PARAM_DISCOVERY; then
        NEED_URL_FILTERING=true
    fi
    
    # If subdomain scanning and other modules need to be run, run URL filtering module
    if $SUBDOMAIN_SCANNED || $NEED_URL_FILTERING; then
        log "INFO" "Subdomain scanning performed and other required modules run - Running URL filtering module"
        bash modules/filter_urls.sh "$domain" -o "$domain_output_dir"
    fi
    
    # 4. URL Discovery
    if $URL_DISCOVERY; then
        bash modules/url_discovery.sh "$domain" -o "$domain_output_dir" --scan-mode "$SCAN_MODE"
    fi
    
    # 5. JavaScript and Parameter Discovery
    if $JS_DISCOVERY || $PARAM_DISCOVERY; then
        JS_FLAG=""
        PARAM_FLAG=""
        
        if $JS_DISCOVERY; then
            JS_FLAG="-js"
        fi
        
        if $PARAM_DISCOVERY; then
            PARAM_FLAG="-p"
        fi
        
        bash modules/js_and_param_discovery.sh "$domain" -o "$domain_output_dir" $JS_FLAG $PARAM_FLAG --scan-mode "$SCAN_MODE"
    fi
    
    # 6. Port Scanning
    if $PORT_SCAN; then
        bash modules/port_scan.sh "$domain" -o "$domain_output_dir" --scan-mode "$SCAN_MODE"
    fi
    
    # 7. JavaScript Analysis
    if $JS_ANALYSIS; then
        bash modules/js_analysis.sh "$domain" -o "$domain_output_dir"
    fi
    
    # 8. Parameter Analysis
    if $PARAM_ANALYSIS; then
        bash modules/param_analysis.sh "$domain" -o "$domain_output_dir" 
    fi

    # 9. Vulnerability Scanning
    if $VULN_SCAN; then
        bash modules/vuln_scan.sh "$domain" -o "$domain_output_dir" --scan-mode "$SCAN_MODE"
    fi
done

log "SUCCESS" "###------- TheBestRecon completed. Results: $OUTPUT_DIR -------###" 
