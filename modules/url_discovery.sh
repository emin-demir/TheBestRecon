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

# Başlangıç zamanını kaydet
START_TIME=$(date +%s)

# Varsayılan değerler
OUTPUT_DIR=""
SCAN_MODE="big" # Varsayılan tarama modu: big

# Parametreleri işle
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

# Domain parametresi kontrolü
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-] Domain parametresi gerekli${NC}"
    echo "Kullanım: $0 <domain> [-o output_dir] [--scan-mode short|medium|big]"
    exit 1
fi

# Output dizininde url_discovery klasörü oluştur
URL_DISCOVERY_DIR="${OUTPUT_DIR}/url_discovery"
mkdir -p "$URL_DISCOVERY_DIR"

echo -e "${GREEN}###------- URL Discovery başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $URL_DISCOVERY_DIR${NC}"
echo -e "${BLUE}[+] Tarama modu: $SCAN_MODE${NC}"

# Temporary dizini oluştur
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

# URL filtreleme modülünü çalıştır (eğer temp dizini yoksa veya dosyalar yoksa)
if [ ! -f "$TEMP_DIR/short_urls.txt" ] || [ ! -f "$TEMP_DIR/medium_urls.txt" ] || [ ! -f "$TEMP_DIR/all_urls.txt" ]; then
    echo -e "${BLUE}[+] URL filtreleme modülü çalıştırılıyor...${NC}"
    bash "$OUTPUT_DIR/../../modules/filter_urls.sh" "$DOMAIN" -o "$OUTPUT_DIR" --scan-mode "$SCAN_MODE"
fi

# Tarama moduna göre URL listesini seç
LIVE_DOMAINS_FILE=""
case $SCAN_MODE in
    "short")
        if [ -f "$TEMP_DIR/short_urls.txt" ]; then
            LIVE_DOMAINS_FILE="$TEMP_DIR/short_urls.txt"
            echo -e "${BLUE}[+] Kısa tarama modu seçildi - Kritik subdomainler ile tarama yapılacak${NC}"
        else
            echo -e "${YELLOW}[!] Short mode URL listesi bulunamadı, varsayılan liste kullanılacak${NC}"
        fi
        ;;
    "medium")
        if [ -f "$TEMP_DIR/medium_urls.txt" ]; then
            LIVE_DOMAINS_FILE="$TEMP_DIR/medium_urls.txt"
            echo -e "${BLUE}[+] Orta tarama modu seçildi - Önemli subdomainler ile tarama yapılacak${NC}"
        else
            echo -e "${YELLOW}[!] Medium mode URL listesi bulunamadı, varsayılan liste kullanılacak${NC}"
        fi
        ;;
    *)
        echo -e "${BLUE}[+] Büyük tarama modu seçildi - Tüm subdomainler taranacak${NC}"
        if [ -f "$TEMP_DIR/all_urls.txt" ]; then
            LIVE_DOMAINS_FILE="$TEMP_DIR/all_urls.txt"
        fi
        ;;
esac

# Eğer LIVE_DOMAINS_FILE hala boşsa, varsayılan listeleri kontrol et
if [ -z "$LIVE_DOMAINS_FILE" ]; then
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
        echo -e "${YELLOW}[!] Ana domain kullanılıyor...${NC}"
        echo "$DOMAIN" > "$URL_DISCOVERY_DIR/single_domain.txt"
        LIVE_DOMAINS_FILE="$URL_DISCOVERY_DIR/single_domain.txt"
    fi
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
    katana -list "$LIVE_DOMAINS_FILE" -d 5 -jc -jsl -kf all -aff -rl 5 -o "$URL_DISCOVERY_DIR/katanaURls.txt"   
    KATANA_URLS=$(wc -l < "$URL_DISCOVERY_DIR/katanaURls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] katana tamamlandı: $KATANA_URLS URL bulundu${NC}"
else
    echo -e "${RED}[-] katana bulunamadı${NC}"
fi

# Tüm URL'leri birleştir
echo -e "${BLUE}[+] Tüm URL sonuçları birleştiriliyor...${NC}"
cat "$URL_DISCOVERY_DIR"/*.txt 2>/dev/null | sort -u > "$URL_DISCOVERY_DIR/all_unique_urls.txt"
TOTAL_URLS=$(wc -l < "$URL_DISCOVERY_DIR/all_unique_urls.txt" 2>/dev/null || echo 0)

# Süre formatı fonksiyonu
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local hours=$((minutes / 60))
    minutes=$((minutes % 60))
    seconds=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $seconds
}

# Modül sonunda toplam süreyi hesapla ve göster
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_TIME_FORMATTED=$(format_time $TOTAL_TIME)
echo -e "${CYAN}[+] Toplam URL discovery süresi: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- URL Discovery tamamlandı: $DOMAIN - Toplam $TOTAL_URLS benzersiz URL bulundu -------###${NC}" 