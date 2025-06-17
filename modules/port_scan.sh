#!/bin/bash

# Port Scanning Module
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

# Create port_scan directory in output directory
PORT_SCAN_DIR="${OUTPUT_DIR}/port_scan"
mkdir -p "$PORT_SCAN_DIR"

echo -e "${GREEN}###------- Starting Port Scan: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Results will be saved to: $PORT_SCAN_DIR${NC}"

# Check if IP list exists (from subdomain scans)
IP_FILE=""

# Create temporary directory
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

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
# Legacy IP list checks
elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Using IP list from subdomain_brute module${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_enum/dnsx_ips_${DOMAIN}.txt" 
    echo -e "${BLUE}[+] Using IP list from subdomain_enum module${NC}"
else
    echo -e "${YELLOW}[!] IP list not found, resolving domain IP${NC}"
    
    # Resolve domain's IP address
    if command -v host &> /dev/null; then
        IP=$(host "$DOMAIN" | grep "has address" | head -1 | cut -d ' ' -f 4)
        if [ -n "$IP" ]; then
            echo "$IP" > "$PORT_SCAN_DIR/resolved_ips.txt"
            IP_FILE="$PORT_SCAN_DIR/resolved_ips.txt"
            echo -e "${BLUE}[+] Domain IP address: $IP${NC}"
        else
            echo -e "${RED}[-] Could not resolve domain IP address${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[-] host command not found${NC}"
        exit 1
    fi
fi

IP_COUNT=$(wc -l < "$IP_FILE")
echo -e "${GREEN}[+] Port scan will be performed on $IP_COUNT IP addresses${NC}"

# 1. Port scanning with Naabu
echo -e "${BLUE}[+] Running port scan with naabu...${NC}"
if command -v naabu &> /dev/null; then
    
    # Prepare nmap command
    NMAP_OUTPUT="$PORT_SCAN_DIR/naabu_nmap_results.txt"
    NMAP_CMD="nmap -sV -sS -sC -oN $NMAP_OUTPUT"
    
    # Run advanced naabu scan
    naabu -l "$IP_FILE" -tp full -c 15 -timeout 1500 -sV -sD -ping -verify -nmap-cli "$NMAP_CMD" -o "$PORT_SCAN_DIR/naabu_ports.txt" -silent
    
    PORTS_COUNT=$(wc -l < "$PORT_SCAN_DIR/naabu_ports.txt" 2>/dev/null || echo 0)
    
    # Convert IP:PORT format to port list
    cat "$PORT_SCAN_DIR/naabu_ports.txt" | cut -d':' -f2 | sort -nu > "$PORT_SCAN_DIR/open_ports.txt"
    UNIQUE_PORTS_COUNT=$(wc -l < "$PORT_SCAN_DIR/open_ports.txt" 2>/dev/null || echo 0)
    
    echo -e "${GREEN}[+] naabu completed: $PORTS_COUNT port connections ($UNIQUE_PORTS_COUNT unique ports) found${NC}"
    
    # Check nmap integration results
    if [ -f "$NMAP_OUTPUT" ]; then
        echo -e "${GREEN}[+] Nmap scan through naabu completed successfully${NC}"
        echo -e "${GREEN}[+] Nmap results: $NMAP_OUTPUT${NC}"
        
        # Skip manual nmap scan if integrated scan was successful
        echo -e "${CYAN}[*] nmap scan was automatically performed by naabu, skipping manual scan...${NC}"
    else
        # Run manual nmap scan if integration failed
        echo -e "${YELLOW}[!] Naabu-nmap integration failed, running manual nmap scan${NC}"
        
        # Create port list (for nmap)
        PORTS=$(cat "$PORT_SCAN_DIR/open_ports.txt" | tr '\n' ',' | sed 's/,$//')
        
        if [ -n "$PORTS" ]; then
            echo -e "${BLUE}[+] Found open ports: $PORTS${NC}"
            
            # Process IP addresses in loop
            while read -r ip; do
                echo -e "${BLUE}[+] Running nmap service scan for IP address $ip...${NC}"
                
                # 2. Service and version scanning with Nmap
                if command -v nmap &> /dev/null; then
                    # Detailed service and version scan for open ports
                    nmap -sV -sC -p "$PORTS" -oN "$PORT_SCAN_DIR/nmap_services_${ip}.txt" "$ip"
                    echo -e "${GREEN}[+] Nmap service scan completed for $ip${NC}"
                else
                    echo -e "${RED}[-] nmap not found${NC}"
                fi
            done < "$IP_FILE"
        else
            echo -e "${YELLOW}[!] No open ports found, skipping nmap scan${NC}"
        fi
    fi
else
    echo -e "${RED}[-] naabu not found${NC}"
    echo -e "${YELLOW}[!] Running direct scan with nmap as alternative${NC}"
    
    # Run direct nmap scan if naabu is not available
    if command -v nmap &> /dev/null; then
        while read -r ip; do
            echo -e "${BLUE}[+] Running nmap scan for IP address $ip...${NC}"
            if [ -n "$OPEN_PORTS" ]; then
                echo -e "${BLUE}[+] Found open ports for IP address $ip: $OPEN_PORTS${NC}"
                # Detailed scan on open ports
                nmap -sS -sV -oN "$PORT_SCAN_DIR/nmap_services_${ip}.txt" "$ip"
                echo -e "${GREEN}[+] Nmap service scan completed for $ip${NC}"
            else
                echo -e "${YELLOW}[!] No open ports found on $ip${NC}"
            fi
        done < "$IP_FILE"
    else
        echo -e "${RED}[-] Port scan not possible: Neither naabu nor nmap found${NC}"
        exit 1
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

END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_TIME_FORMATTED=$(format_time $TOTAL_TIME)
echo -e "${CYAN}[+] Total port scan time: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Port scan completed: $DOMAIN -------###${NC}" 