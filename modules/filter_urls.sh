#!/bin/bash

# URL Filtreleme Modülü
# TheBestRecon - Tarama moduna göre URL listesini filtreler

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

# Output dizinini belirle
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}"
fi

# Temporary dizini oluştur
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

echo -e "${BLUE}[+] URL Filtreleme modülü başlatılıyor...${NC}"

# Canlı subdomainler var mı kontrol et
LIVE_DOMAINS_FILE=""
if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-domains-clean.txt" ]; then
    LIVE_DOMAINS_FILE="$OUTPUT_DIR/subs_live/200-400-httpx-domains-clean.txt"
    echo -e "${BLUE}[+] Subs_live modülünden temiz httpx domain listesi kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
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
    echo -e "${YELLOW}[!] Ana domain kullanılıyor...${NC}"
    echo "$DOMAIN" > "$TEMP_DIR/single_domain.txt"
    LIVE_DOMAINS_FILE="$TEMP_DIR/single_domain.txt"
fi

# Toplam URL sayısını göster
TOTAL_DOMAINS=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] Toplam domain sayısı: $TOTAL_DOMAINS${NC}"

# Short subdomain listesi
SHORT_LIST="$OUTPUT_DIR/../../config/30_short_subdomain.txt"
if [ ! -f "$SHORT_LIST" ]; then
    echo -e "${RED}[-] Short subdomain listesi bulunamadı: $SHORT_LIST${NC}"
    exit 1
fi

# Medium subdomain listesi
MEDIUM_LIST="$OUTPUT_DIR/../../config/100_medium_subdomain.txt"
if [ ! -f "$MEDIUM_LIST" ]; then
    echo -e "${RED}[-] Medium subdomain listesi bulunamadı: $MEDIUM_LIST${NC}"
    exit 1
fi


# Short mode için URL listesi oluştur
echo -e "${BLUE}[+] Short mode URL listesi hazırlanıyor...${NC}"
> "$TEMP_DIR/short_urls.txt"

# -iFf ile daha etkili şekilde tarama yap
grep -iFf "$SHORT_LIST" "$LIVE_DOMAINS_FILE" > "$TEMP_DIR/short_urls.txt" 2>/dev/null

# Short URL sayısını kontrol et
SHORT_URLS=$(wc -l < "$TEMP_DIR/short_urls.txt")
if [ $SHORT_URLS -eq 0 ]; then
    echo -e "${YELLOW}[!] Short mode için hiç URL bulunamadı. Ana domain kullanılıyor...${NC}"
    # Ana domain kontrolü - başında http yoksa https ekle
    if [[ $DOMAIN != http://* ]] && [[ $DOMAIN != https://* ]]; then
        echo "https://$DOMAIN" > "$TEMP_DIR/short_urls.txt"
    else
        echo "$DOMAIN" > "$TEMP_DIR/short_urls.txt"
    fi
    SHORT_URLS=1
fi
echo -e "${GREEN}[+] Short mode için $SHORT_URLS URL hazırlandı${NC}"

# Medium mode için URL listesi oluştur
echo -e "${BLUE}[+] Medium mode URL listesi hazırlanıyor...${NC}"
> "$TEMP_DIR/medium_urls.txt"

# -iFf ile daha etkili şekilde tarama yap
grep -iFf "$MEDIUM_LIST" "$LIVE_DOMAINS_FILE" > "$TEMP_DIR/medium_urls.txt" 2>/dev/null

# Medium URL sayısını kontrol et
MEDIUM_URLS=$(wc -l < "$TEMP_DIR/medium_urls.txt")
if [ $MEDIUM_URLS -eq 0 ]; then
    echo -e "${YELLOW}[!] Medium mode için hiç URL bulunamadı. Ana domain kullanılıyor...${NC}"
    # Ana domain kontrolü - başında http yoksa https ekle
    if [[ $DOMAIN != http://* ]] && [[ $DOMAIN != https://* ]]; then
        echo "https://$DOMAIN" > "$TEMP_DIR/medium_urls.txt"
    else
        echo "$DOMAIN" > "$TEMP_DIR/medium_urls.txt"
    fi
    MEDIUM_URLS=1
fi
echo -e "${GREEN}[+] Medium mode için $MEDIUM_URLS URL hazırlandı${NC}"

# Big mode için tüm URL'leri kopyala
cp "$LIVE_DOMAINS_FILE" "$TEMP_DIR/all_urls.txt"

echo -e "${GREEN}[+] URL filtreleme işlemi tamamlandı.${NC}"
echo -e "${GREEN}[+] URL listesi: $TEMP_DIR${NC}"

# DNS kayıtlarından IP'leri ayıklama
DNS_RAW_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_raw_${DOMAIN}.txt"
if [ -f "$DNS_RAW_FILE" ]; then
    echo -e "${BLUE}[+] DNS kayıtlarından IP adreslerini ayıklama işlemi başlatılıyor...${NC}"
    
    # Short mode IP'leri
    echo -e "${BLUE}[+] Short mode IP'leri ayıklanıyor...${NC}"
    cut -d '/' -f3 "$TEMP_DIR/short_urls.txt" 2>/dev/null | sed 's/^https\?:\/\///' | while read -r d; do
        grep -F "$d" "$DNS_RAW_FILE" 2>/dev/null
    done | grep -oP '\[\K[0-9.]+(?=\])' | sort -u > "$TEMP_DIR/short_ips.txt"
    SHORT_IPS=$(wc -l < "$TEMP_DIR/short_ips.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Short mode için $SHORT_IPS benzersiz IP adresi bulundu${NC}"
    
    # Medium mode IP'leri
    echo -e "${BLUE}[+] Medium mode IP'leri ayıklanıyor...${NC}"
    cut -d '/' -f3 "$TEMP_DIR/medium_urls.txt" 2>/dev/null | sed 's/^https\?:\/\///' | while read -r d; do
        grep -F "$d" "$DNS_RAW_FILE" 2>/dev/null
    done | grep -oP '\[\K[0-9.]+(?=\])' | sort -u > "$TEMP_DIR/medium_ips.txt"
    MEDIUM_IPS=$(wc -l < "$TEMP_DIR/medium_ips.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Medium mode için $MEDIUM_IPS benzersiz IP adresi bulundu${NC}"
    
    # Big mode IP'leri (tüm IP'ler)
    echo -e "${BLUE}[+] Tüm IP'ler ayıklanıyor...${NC}"
    cut -d '/' -f3 "$TEMP_DIR/all_urls.txt" 2>/dev/null | sed 's/^https\?:\/\///' | while read -r d; do
        grep -F "$d" "$DNS_RAW_FILE" 2>/dev/null
    done | grep -oP '\[\K[0-9.]+(?=\])' | sort -u > "$TEMP_DIR/all_ips.txt"
    ALL_IPS=$(wc -l < "$TEMP_DIR/all_ips.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Toplam $ALL_IPS benzersiz IP adresi bulundu${NC}"
    
    echo -e "${GREEN}[+] IP adreslerini ayıklama işlemi tamamlandı.${NC}"
else
    echo -e "${YELLOW}[!] DNS kayıt dosyası bulunamadı: $DNS_RAW_FILE${NC}"
    echo -e "${YELLOW}[!] IP adresleri ayıklanamadı.${NC}"
fi