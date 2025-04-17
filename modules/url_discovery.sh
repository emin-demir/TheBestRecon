#!/bin/bash

# URL Discovery Modülü
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
    echo "Kullanım: $0 <domain> [-o output_dir]"
    exit 1
fi

# Output dizininde url_discovery klasörü oluştur
URL_DISCOVERY_DIR="${OUTPUT_DIR}/url_discovery"
mkdir -p "$URL_DISCOVERY_DIR"

echo -e "${GREEN}###------- URL Discovery başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $URL_DISCOVERY_DIR${NC}"

# Canlı subdomainler var mı kontrol et
LIVE_DOMAINS_FILE=""
if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
    LIVE_DOMAINS_FILE="$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt"
    echo -e "${BLUE}[+] Subs_live modülünden canlı domainler kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
    LIVE_DOMAINS_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_brute modülünden canlı domainler kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
    LIVE_DOMAINS_FILE="$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_enum modülünden canlı domainler kullanılıyor${NC}"
else
    echo -e "${YELLOW}[!] Canlı subdomain listesi bulunamadı${NC}"
    echo -e "${YELLOW}[!] Önce --subs-live, --sub-enum veya --sub-brute çalıştırın${NC}"
    exit 1
fi

DOMAINS_COUNT=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] $DOMAINS_COUNT subdomain üzerinde URL keşfi yapılacak${NC}"
echo -e "${BLUE}[+] Kullanılan subdomain listesi : $LIVE_DOMAINS_FILE ${NC}"

# 1. Gau ile URL keşfi
if command -v gau &> /dev/null; then
    echo -e "${BLUE}[+] gau çalıştırılıyor...${NC}"
    cat "$LIVE_DOMAINS_FILE" | gau --threads 5 --o "$URL_DISCOVERY_DIR/gau_urls.txt"
    GAU_URLS=$(wc -l < "$URL_DISCOVERY_DIR/gau_urls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] gau tamamlandı: $GAU_URLS URL bulundu${NC}"
else
    echo -e "${RED}[-] gau bulunamadı${NC}"
fi

# 2. Waymore ile URL keşfi
if command -v waymore &> /dev/null; then
    echo -e "${BLUE}[+] waymore çalıştırılıyor...${NC}"
    waymore -i "$LIVE_DOMAINS_FILE" -mode U -oU "$URL_DISCOVERY_DIR/waymoreUrls.txt"
    WAYMORE_URLS=$(wc -l < "$URL_DISCOVERY_DIR/waymoreUrls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] waymore tamamlandı: $WAYMORE_URLS URL bulundu${NC}"
else
    echo -e "${RED}[-] waymore bulunamadı${NC}"
fi

# 3. Katana ile URL keşfi
if command -v katana &> /dev/null; then
    echo -e "${BLUE}[+] katana çalıştırılıyor...${NC}"
    katana -list "$LIVE_DOMAINS_FILE" -d 5 -jc -jsl -kf all -aff -rl 10 -o "$URL_DISCOVERY_DIR/katanaURls.txt"   
    KATANA_URLS=$(wc -l < "$URL_DISCOVERY_DIR/katanaURls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] katana tamamlandı: $KATANA_URLS URL bulundu${NC}"
else
    echo -e "${RED}[-] katana bulunamadı${NC}"
fi

# Tüm URL'leri birleştir
echo -e "${BLUE}[+] Tüm URL sonuçları birleştiriliyor...${NC}"
cat "$URL_DISCOVERY_DIR"/*.txt 2>/dev/null | sort -u > "$URL_DISCOVERY_DIR/all_unique_urls.txt"
TOTAL_URLS=$(wc -l < "$URL_DISCOVERY_DIR/all_unique_urls.txt" 2>/dev/null || echo 0)

echo -e "${GREEN}###------- URL Discovery tamamlandı: $DOMAIN - Toplam $TOTAL_URLS benzersiz URL bulundu -------###${NC}" 