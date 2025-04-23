#!/bin/bash

# Subdomain Enumeration Modülü
# TheBestRecon

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Varsayılan değerler
API_CONFIG=""
OUTPUT_DIR=""
SKIP_DNSX=false

# Parametreleri işle
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -a|--api-config)
            API_CONFIG="$2"
            shift
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        --skip-dnsx)
            SKIP_DNSX=true
            shift
            ;;
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

# Output dizininde subdomain_enum klasörü oluştur
SUBDOMAIN_ENUM_DIR="${OUTPUT_DIR}/subdomain_enum"
mkdir -p "$SUBDOMAIN_ENUM_DIR"

echo -e "${GREEN}###------- Subdomain enumeration başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $SUBDOMAIN_ENUM_DIR${NC}"

# Başlangıç zamanını kaydet
START_TIME=$(date +%s)

# API config kontrolü
if [ ! -z "$API_CONFIG" ] && [ -f "$API_CONFIG" ]; then
    echo -e "${BLUE}[+] API yapılandırma dosyası yüklendi: $API_CONFIG${NC}"
        VTAPIKEY=$(grep -o '"VTAPIKEY": *"[^"]*"' "$API_CONFIG" | sed 's/"VTAPIKEY": *"\([^"]*\)"/\1/')
        GITHUB_API_KEY=$(grep -o '"GITHUB_API_KEY": *"[^"]*"' "$API_CONFIG" | sed 's/"GITHUB_API_KEY": *"\([^"]*\)"/\1/')
        PDCP_API_KEY=$(grep -o '"PDCP_API_KEY": *"[^"]*"' "$API_CONFIG" | sed 's/"PDCP_API_KEY": *"\([^"]*\)"/\1/')    
        DNSDUMPSTER_API_KEY=$(grep -o '"DNSDUMPSTER_API_KEY": *"[^"]*"' "$API_CONFIG" | sed 's/"DNSDUMPSTER_API_KEY": *"\([^"]*\)"/\1/')
    echo -e "${BLUE}[+] API anahtarları yüklendi ve çevre değişkeni olarak ayarlandı${NC}"
else
    echo -e "${YELLOW}[!] API yapılandırma dosyası bulunamadı veya belirtilmedi${NC}"
    echo -e "${YELLOW}[!] Bazı araçlar sınırlı kapasitede çalışacak${NC}"
    VTAPIKEY="NONE"
    GITHUB_API_KEY="NONE"
    PDCP_API_KEY="NONE"
    DNSDUMPSTER_API_KEY="NONE"
fi

# Varsayılan değerleri çevre değişkeni olarak ayarla
export VTAPIKEY="$VTAPIKEY"
export VT_API_KEY="$VTAPIKEY"
export VIRUSTOTAL_API_KEY="$VTAPIKEY"
export GITHUB_API_KEY="$GITHUB_API_KEY"
export CHAOS_API_KEY="$PDCP_API_KEY"
export PDCP_API_KEY="$PDCP_API_KEY"
export DNSDUMPSTER_API_KEY="$DNSDUMPSTER_API_KEY"

# 1. Assetfinder ile subdomain bulma
echo -e "${BLUE}[+] assetfinder çalıştırılıyor...${NC}"
if command -v assetfinder &> /dev/null; then
    assetfinder --subs-only "$DOMAIN" | tee "$SUBDOMAIN_ENUM_DIR/assetfinder_${DOMAIN}.txt"
    echo -e "${GREEN}[+] assetfinder tamamlandı: $(wc -l < "$SUBDOMAIN_ENUM_DIR/assetfinder_${DOMAIN}.txt") subdomain bulundu${NC}"
else
    echo -e "${RED}[-] assetfinder bulunamadı${NC}"
fi

# 2. Subfinder ile subdomain bulma
echo -e "${BLUE}[+] subfinder çalıştırılıyor...${NC}"
if command -v subfinder &> /dev/null; then
    subfinder -all -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/subfinder_${DOMAIN}.txt"
    echo -e "${GREEN}[+] subfinder tamamlandı: $(wc -l < "$SUBDOMAIN_ENUM_DIR/subfinder_${DOMAIN}.txt") subdomain bulundu${NC}"
else
    echo -e "${RED}[-] subfinder bulunamadı${NC}"
fi

# 3. Sublist3r ile subdomain bulma
echo -e "${BLUE}[+] sublist3r çalıştırılıyor...${NC}"
if command -v sublist3r &> /dev/null; then
    sublist3r -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/sublist3r_${DOMAIN}.txt"
    echo -e "${GREEN}[+] sublist3r tamamlandı: $(wc -l < "$SUBDOMAIN_ENUM_DIR/sublist3r_${DOMAIN}.txt") subdomain bulundu${NC}"
else
    echo -e "${RED}[-] sublist3r bulunamadı${NC}"
fi

# 4. Chaos ile subdomain bulma (API key gerekli)
echo -e "${BLUE}[+] chaos çalıştırılıyor...${NC}"
if command -v chaos &> /dev/null; then
    if [ ! -z "$PDCP_API_KEY" ]; then
        chaos -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/chaos_${DOMAIN}.txt"
        echo -e "${GREEN}[+] chaos tamamlandı: $(wc -l < "$SUBDOMAIN_ENUM_DIR/chaos_${DOMAIN}.txt") subdomain bulundu${NC}"
    else
        echo -e "${YELLOW}[!] Chaos API anahtarı bulunamadı, chaos atlanıyor${NC}"
    fi
else
    echo -e "${RED}[-] chaos bulunamadı${NC}"
fi

# 5. Amass ile subdomain bulma
echo -e "${BLUE}[+] amass çalıştırılıyor...${NC}"
if command -v amass &> /dev/null; then
    amass enum -passive -trqps 5 -rqps 5  -d "$DOMAIN" -o "$SUBDOMAIN_ENUM_DIR/amass_${DOMAIN}_dontmerge.txt"
    echo -e "${GREEN}[+] amass tamamlandı: $(wc -l < "$SUBDOMAIN_ENUM_DIR/amass_${DOMAIN}_dontmerge.txt") subdomain bulundu${NC}"
else
    echo -e "${RED}[-] amass bulunamadı${NC}"
fi

# 6. GitHub subdomains ile subdomain bulma
echo -e "${BLUE}[+] github-subdomains çalıştırılıyor...${NC}"
if command -v github-subdomains &> /dev/null; then
    if [ ! -z "$GITHUB_API_KEY" ]; then
        github-subdomains -d "$DOMAIN" -k -e -t "$GITHUB_API_KEY" -o "$SUBDOMAIN_ENUM_DIR/github_subdomains_${DOMAIN}_dontmerge.txt"
        echo -e "${GREEN}[+] github-subdomains tamamlandı: $(wc -l < "$SUBDOMAIN_ENUM_DIR/github_subdomains_${DOMAIN}_dontmerge.txt") subdomain bulundu${NC}"
    else
        echo -e "${YELLOW}[!] GitHub API anahtarı bulunamadı. github-subdomains atlanıyor${NC}"
    fi
else
    echo -e "${RED}[-] github-subdomains bulunamadı${NC}"
fi

# Tüm sonuçları birleştir
echo -e "${BLUE}[+] Tüm subdomain sonuçları birleştiriliyor...${NC}"
cat "$SUBDOMAIN_ENUM_DIR"/*_"$DOMAIN.txt" 2>/dev/null | sort -u > "$SUBDOMAIN_ENUM_DIR/all_subdomains_${DOMAIN}.txt"

TOTAL_SUBDOMAINS=$(wc -l < "$SUBDOMAIN_ENUM_DIR/all_subdomains_${DOMAIN}.txt")
echo -e "${GREEN}###------- Toplam $TOTAL_SUBDOMAINS benzersiz subdomain bulundu -------###${NC}"

# DNSX ile canlı subdomainleri kontrol et (eğer skip-dnsx parametresi verilmemişse)
if ! $SKIP_DNSX; then
    echo -e "${BLUE}[+] dnsx ile canlı subdomain kontrolü yapılıyor...${NC}"
    if command -v dnsx &> /dev/null; then
        # Resolver dosyasını kontrol et
        RESOLVER_FILE="$OUTPUT_DIR/../../config/resolvers.txt"
        if [ ! -f "$RESOLVER_FILE" ]; then
            echo -e "${YELLOW}[!] Resolver dosyası ($RESOLVER_FILE) bulunamadı, oluşturuluyor...${NC}"
            wget -O "$RESOLVER_FILE" https://raw.githubusercontent.com/trickest/resolvers/refs/heads/main/resolvers.txt
        fi
        
        # DNS sorgusu çalıştır ve ham sonuçları kaydet
        cat "$SUBDOMAIN_ENUM_DIR/all_subdomains_${DOMAIN}.txt" | \
            dnsx -r "$RESOLVER_FILE" -a -resp -o "$SUBDOMAIN_ENUM_DIR/dnsx_raw_${DOMAIN}.txt" -nc
        
        # Sadece subdomainleri ayır (1. sütun)
        cat "$SUBDOMAIN_ENUM_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f1 | sort -u > "$SUBDOMAIN_ENUM_DIR/dnsx_live_subdomains_${DOMAIN}.txt" 
        
        # IP adreslerini ayır (3. sütun) ve parantezleri kaldır
        cat "$SUBDOMAIN_ENUM_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f3 | sed 's/\[\(.*\)\]/\1/g' | sort -u > "$SUBDOMAIN_ENUM_DIR/dnsx_ips_${DOMAIN}.txt"
        
        LIVE_SUBDOMAINS=$(wc -l < "$SUBDOMAIN_ENUM_DIR/dnsx_live_subdomains_${DOMAIN}.txt")
        IP_COUNT=$(wc -l < "$SUBDOMAIN_ENUM_DIR/dnsx_ips_${DOMAIN}.txt")
        
        echo -e "${GREEN}[+] dnsx tamamlandı: $LIVE_SUBDOMAINS canlı subdomain ve $IP_COUNT benzersiz IP adresi bulundu${NC}"
    else
        echo -e "${RED}[-] dnsx bulunamadı${NC}"
    fi
else
    echo -e "${YELLOW}[!] dnsx kontrolü atlanıyor (--skip-dnsx parametresi verildi)${NC}"
fi

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
echo -e "${CYAN}[+] Toplam subdomain keşif süresi: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Subdomain Enumeration tamamlandı: $DOMAIN - Toplam $TOTAL_SUBDOMAINS benzersiz subdomain bulundu -------###${NC}"