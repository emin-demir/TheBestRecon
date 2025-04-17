#!/bin/bash

# Port Scanning Modülü
# TheBestRecon

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Varsayılan değerler
OUTPUT_DIR=""

# Parametreleri işle
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

# Domain parametresi kontrolü
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-] Domain parametresi gerekli${NC}"
    echo "Kullanım: $0 <domain> [-o output_dir] "
    exit 1
fi

# Output dizininde port_scan klasörü oluştur
PORT_SCAN_DIR="${OUTPUT_DIR}/port_scan"
mkdir -p "$PORT_SCAN_DIR"

echo -e "${GREEN}###------- Port Tarama başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $PORT_SCAN_DIR${NC}"

# IP listesi var mı kontrol et (subdomain taramalarından)
IP_FILE=""
if [ -f "$OUTPUT_DIR/dns_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/dns_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain modüllerinden IP listesi kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_brute/dns_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_brute/dns_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_brute modülünden IP listesi kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dns_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_enum/dns_ips_${DOMAIN}.txt" 
    echo -e "${BLUE}[+] Subdomain_enum modülünden IP listesi kullanılıyor${NC}"
else
    echo -e "${YELLOW}[!] IP listesi bulunamadı, domainin IP'si çözümlenecek${NC}"
    
    # Domain'in IP adresini çözümle
    if command -v host &> /dev/null; then
        IP=$(host "$DOMAIN" | grep "has address" | head -1 | cut -d ' ' -f 4)
        if [ -n "$IP" ]; then
            echo "$IP" > "$PORT_SCAN_DIR/resolved_ips.txt"
            IP_FILE="$PORT_SCAN_DIR/resolved_ips.txt"
            echo -e "${BLUE}[+] Domain IP adresi: $IP${NC}"
        else
            echo -e "${RED}[-] Domain IP adresi çözümlenemedi${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[-] host komutu bulunamadı${NC}"
        exit 1
    fi
fi

IP_COUNT=$(wc -l < "$IP_FILE")
echo -e "${GREEN}[+] $IP_COUNT IP adresi üzerinde port taraması yapılacak${NC}"

# 1. Naabu ile port taraması
echo -e "${BLUE}[+] naabu ile port taraması yapılıyor...${NC}"
if command -v naabu &> /dev/null; then
    naabu -iL "$IP_FILE" -tp full  -o "$PORT_SCAN_DIR/naabu_ports.txt" -silent
    PORTS_COUNT=$(wc -l < "$PORT_SCAN_DIR/naabu_ports.txt" 2>/dev/null || echo 0)
    
    # IP:PORT formatını, port listesine dönüştür
    cat "$PORT_SCAN_DIR/naabu_ports.txt" | cut -d':' -f2 | sort -nu > "$PORT_SCAN_DIR/open_ports.txt"
    UNIQUE_PORTS_COUNT=$(wc -l < "$PORT_SCAN_DIR/open_ports.txt" 2>/dev/null || echo 0)
    
    echo -e "${GREEN}[+] naabu tamamlandı: $PORTS_COUNT port bağlantısı ($UNIQUE_PORTS_COUNT benzersiz port) bulundu${NC}"
    
    # Port listesi oluştur (nmap için)
    PORTS=$(cat "$PORT_SCAN_DIR/open_ports.txt" | tr '\n' ',' | sed 's/,$//')
    
    if [ -n "$PORTS" ]; then
        echo -e "${BLUE}[+] Bulunan açık portlar: $PORTS${NC}"
        
        # IP adreslerini döngüde işle
        while read -r ip; do
            echo -e "${BLUE}[+] $ip IP adresi için nmap servis taraması yapılıyor...${NC}"
            
            # 2. Nmap ile servis ve versiyon taraması
            if command -v nmap &> /dev/null; then
                # Açık portlara göre detaylı servis ve versiyon taraması
                nmap -sV -sC -p "$PORTS" -oN "$PORT_SCAN_DIR/nmap_services_${ip}.txt" "$ip"
                echo -e "${GREEN}[+] $ip için nmap servis taraması tamamlandı${NC}"
            else
                echo -e "${RED}[-] nmap bulunamadı${NC}"
            fi
        done < "$IP_FILE"
    else
        echo -e "${YELLOW}[!] Açık port bulunamadı, nmap taraması yapılmayacak${NC}"
    fi
else
    echo -e "${RED}[-] naabu bulunamadı${NC}"
    echo -e "${YELLOW}[!] Alternatif olarak nmap ile direkt tarama yapılacak${NC}"
    
    # Naabu yoksa doğrudan nmap ile tarama yap
    if command -v nmap &> /dev/null; then
        while read -r ip; do
            echo -e "${BLUE}[+] $ip IP adresi için nmap taraması yapılıyor...${NC}"
            # İlk olarak hızlı port taraması yap
            nmap -sS -T4 -p- --min-rate=1000 -oN "$PORT_SCAN_DIR/nmap_quick_${ip}.txt" "$ip"
            # Açık portları al
            OPEN_PORTS=$(grep "^[0-9]" "$PORT_SCAN_DIR/nmap_quick_${ip}.txt" | cut -d'/' -f1 | tr '\n' ',' | sed 's/,$//')
            
            if [ -n "$OPEN_PORTS" ]; then
                echo -e "${BLUE}[+] $ip IP adresi için bulunan açık portlar: $OPEN_PORTS${NC}"
                # Açık portlar üzerinde detaylı tarama
                nmap -sV -sC -p "$OPEN_PORTS" -oN "$PORT_SCAN_DIR/nmap_services_${ip}.txt" "$ip"
                echo -e "${GREEN}[+] $ip için nmap servis taraması tamamlandı${NC}"
            else
                echo -e "${YELLOW}[!] $ip üzerinde açık port bulunamadı${NC}"
            fi
        done < "$IP_FILE"
    else
        echo -e "${RED}[-] nmap bulunamadı${NC}"
        echo -e "${RED}[-] Port tarama yapılamıyor: Hem naabu hem de nmap bulunamadı${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}###------- Port tarama tamamlandı: $DOMAIN -------###${NC}" 