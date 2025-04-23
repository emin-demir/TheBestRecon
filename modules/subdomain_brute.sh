#!/bin/bash

# Subdomain Bruteforce Modülü
# TheBestRecon - DNS ve Subdomain Bruteforce birleştirilmiş

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

# Output dizininde subdomain_brute klasörü oluştur
SUBDOMAIN_BRUTE_DIR="${OUTPUT_DIR}/subdomain_brute"
mkdir -p "$SUBDOMAIN_BRUTE_DIR"

echo -e "${GREEN}###------- Subdomain ve DNS bruteforce başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $SUBDOMAIN_BRUTE_DIR${NC}"

# 1. Gobuster ile subdomain bruteforce
echo -e "${BLUE}[+] Gobuster çalıştırılıyor...${NC}"
if command -v ffuf &> /dev/null; then
    gobuster dns -d ${DOMAIN} -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-5000.txt -o "$SUBDOMAIN_BRUTE_DIR/gobuster_subs_${DOMAIN}_dont_merge.txt" --delay 200ms --no-color -t 5
    if [ -f "$SUBDOMAIN_BRUTE_DIR/gobuster_subs_${DOMAIN}_dont_merge.txt" ]; then
        cat "$SUBDOMAIN_BRUTE_DIR/gobuster_subs_${DOMAIN}_dont_merge.txt" | cut -d ' ' -f2 > gobuster_${DOMAIN}.txt
        echo -e "${GREEN}[+] Gobuster tamamlandı: $(wc -l < "$SUBDOMAIN_BRUTE_DIR/gobuster_${DOMAIN}.txt") subdomain bulundu${NC}"
    fi
else
    echo -e "${RED}[-] Gobuster bulunamadı${NC}"
fi

# 2. Shuffledns ile DNS bruteforce
echo -e "${BLUE}[+] shuffledns çalıştırılıyor...${NC}"
if command -v shuffledns &> /dev/null; then
    # Resolver dosyasını kontrol et
    RESOLVER_FILE="$OUTPUT_DIR/../../config/resolvers.txt"
    if [ ! -f "$RESOLVER_FILE" ]; then
        echo -e "${YELLOW}[!] Resolver dosyası ($RESOLVER_FILE) bulunamadı, oluşturuluyor...${NC}"
        wget -O "$RESOLVER_FILE" https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt
    fi

    shuffledns -d "$DOMAIN" \
               -w /usr/share/wordlists/seclists/Discovery/DNS/subdomains-top1million-110000.txt \
               -o "$SUBDOMAIN_BRUTE_DIR/shuffledns_${DOMAIN}.txt" \
               -r "$RESOLVER_FILE" \
               -mode bruteforce \
               -wt 50 \
               -t 100 -v
    
    echo -e "${GREEN}[+] shuffledns tamamlandı: $(wc -l < "$SUBDOMAIN_BRUTE_DIR/shuffledns_${DOMAIN}.txt") subdomain bulundu${NC}"
else
    echo -e "${RED}[-] shuffledns bulunamadı${NC}"
fi

# 3. Tüm sonuçları birleştir
echo -e "${BLUE}[+] Tüm bruteforce sonuçları birleştiriliyor...${NC}"
# Gobuster çıktılarını birleştir
cat "$SUBDOMAIN_BRUTE_DIR"/*_"${DOMAIN}.txt" 2>/dev/null | sort -u > "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt"

echo -e "${GREEN}[+] Toplam $(wc -l < "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt") benzersiz subdomain bulundu${NC}"

# 4. DNSX ile canlı subdomainleri kontrol et
echo -e "${BLUE}[+] dnsx ile canlı subdomain kontrolü yapılıyor...${NC}"
if command -v dnsx &> /dev/null; then
    # Subdomain enum sonuçlarını da kontrol et
    if [ -f "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" ]; then
        echo -e "${BLUE}[+] Subdomain enumeration sonuçları da dnsx kontrolüne dahil ediliyor...${NC}"
        cat "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt" | \
        sort -u > "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt"
    else
        cp "$SUBDOMAIN_BRUTE_DIR/all_brute_subdomains_${DOMAIN}.txt" "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt"
    fi
    
    # DNS sorgusu çalıştır ve ham sonuçları kaydet
    cat "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt" | \
        dnsx -r "$RESOLVER_FILE" -a -resp -o "$SUBDOMAIN_BRUTE_DIR/dnsx_raw_${DOMAIN}.txt" -nc
    
    # Sadece subdomainleri ayır (1. sütun)
    cat "$SUBDOMAIN_BRUTE_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f1 | sort -u > "$SUBDOMAIN_BRUTE_DIR/dnsx_live_subdomains_${DOMAIN}.txt"
    
    # IP adreslerini ayır (3. sütun) ve parantezleri kaldır
    cat "$SUBDOMAIN_BRUTE_DIR/dnsx_raw_${DOMAIN}.txt" | cut -d ' ' -f3 | sed 's/\[\(.*\)\]/\1/g' | sort -u > "$SUBDOMAIN_BRUTE_DIR/dnsx_ips_${DOMAIN}.txt"
    
    LIVE_SUBDOMAINS=$(wc -l < "$SUBDOMAIN_BRUTE_DIR/dnsx_live_subdomains_${DOMAIN}.txt")
    IP_COUNT=$(wc -l < "$SUBDOMAIN_BRUTE_DIR/dnsx_ips_${DOMAIN}.txt")
    
    echo -e "${GREEN}[+] dnsx tamamlandı: $LIVE_SUBDOMAINS canlı subdomain ve $IP_COUNT benzersiz IP adresi bulundu${NC}"
else
    echo -e "${RED}[-] dnsx bulunamadı${NC}"
    cp "$SUBDOMAIN_BRUTE_DIR/combined_subdomains_${DOMAIN}.txt" "$OUTPUT_DIR/" 2>/dev/null
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
echo -e "${CYAN}[+] Toplam subdomain brute force süresi: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Subdomain Bruteforce tamamlandı: $DOMAIN - Toplam $TOTAL_SUBDOMAINS benzersiz subdomain bulundu -------###${NC}" 