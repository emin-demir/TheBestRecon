#!/bin/bash

# Subdomain Live Check ve Screenshot Modülü
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
LIVE_CHECK=false
SCREENSHOT=false

# Parametreleri işle
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        -l|--live)
            LIVE_CHECK=true
            shift
            ;;
        -s|--screenshot)
            SCREENSHOT=true
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
    echo "Kullanım: $0 <domain> [-o output_dir] [-l/--live] [-s/--screenshot]"
    exit 1
fi

# Output dizininde subs_live klasörü oluştur
SUBS_LIVE_DIR="${OUTPUT_DIR}/subs_live"
mkdir -p "$SUBS_LIVE_DIR"

echo -e "${GREEN}###------- Subdomain Live Check ve Screenshot başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $SUBS_LIVE_DIR${NC}"

# Tüm subdomain dosyalarını birleştir
echo -e "${BLUE}[+] Tüm subdomain sonuçları birleştiriliyor...${NC}"

# 1. ve 2. adım: subdomain_brute klasörünün varlığını ve içindeki dosyayı kontrol et
if [ -d "$OUTPUT_DIR/subdomain_brute" ] && [ -f "$OUTPUT_DIR/subdomain_brute/combined_subdomains_${DOMAIN}.txt" ] && [ -s "$OUTPUT_DIR/subdomain_brute/combined_subdomains_${DOMAIN}.txt" ]; then
    echo -e "${GREEN}[+] Subdomain brute sonuçları kullanılıyor${NC}"
    cp "$OUTPUT_DIR/subdomain_brute/combined_subdomains_${DOMAIN}.txt" "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt"
# 3. adım: subdomain_enum klasöründeki dosyayı kontrol et
elif [ -f "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" ] && [ -s "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" ]; then
    echo -e "${GREEN}[+] Subdomain enum sonuçları kullanılıyor${NC}"
    cp "$OUTPUT_DIR/subdomain_enum/all_subdomains_${DOMAIN}.txt" "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt"
# 4. adım: Hiçbiri bulunamazsa hata ver
else
    echo -e "${RED}[-] HATA: Hiçbir subdomain dosyası bulunamadı!${NC}"
    echo -e "${YELLOW}[!] Lütfen önce 'subdomain_enum.sh' veya 'subdomain_brute.sh' çalıştırın.${NC}"
    exit 1
fi

# Live Check işlemi
if $LIVE_CHECK; then
    echo -e "${BLUE}[+] httpx ile canlı subdomain kontrolü yapılıyor...${NC}"
    
    if command -v httpx &> /dev/null; then
        # Toplam subdomain sayısını al
        TOTAL_SUBDOMAINS=$(wc -l < "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt")
        
        # pv ile loading çubuğu ekle
        if command -v pv &> /dev/null; then
            # httpx ile canlı subdomainleri kontrol et ve detaylı bilgileri al
            cat "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt" | \
            pv -p -t -e -s "$TOTAL_SUBDOMAINS" | \
            httpx -sc -status-code -ip -ct -web-server -t 25 -rl 25 -location -lc -title -td -method -websocket -cname -extract-fqdn -asn -cdn -probe -silent | \
            tee "$SUBS_LIVE_DIR/httpx_detailed_${DOMAIN}.txt" | \
            tee >(grep -E '\b(2[0-9]{2}|3[0-9]{2}|400)\b' > "$SUBS_LIVE_DIR/200-400-httpx-domains.txt") \
                >(grep -Ev '\b(2[0-9]{2}|3[0-9]{2}|400)\b' > "$SUBS_LIVE_DIR/exclude-200-400-httpx-domains.txt")
        else
            # pv yoksa normal çalıştır
            cat "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt" | \
            httpx -sc -status-code -ip -ct -web-server -t 25 -rl 25 -location -lc -title -td -method -websocket -cname -extract-fqdn -asn -cdn -probe -silent | \
            tee "$SUBS_LIVE_DIR/httpx_detailed_${DOMAIN}.txt" | \
            tee >(grep -E '\b(2[0-9]{2}|3[0-9]{2}|400)\b' > "$SUBS_LIVE_DIR/200-400-httpx-domains.txt") \
                >(grep -Ev '\b(2[0-9]{2}|3[0-9]{2}|400)\b' > "$SUBS_LIVE_DIR/exclude-200-400-httpx-domains.txt")
        fi
        
        # Sadece domain listesini oluştur (200-400 HTTP kodları)
        cat "$SUBS_LIVE_DIR/200-400-httpx-domains.txt" | cut -d ' ' -f1 | sort -u > "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt"
        
        LIVE_SUBDOMAINS=$(wc -l < "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt")
        echo -e "${GREEN}[+] httpx tamamlandı: $LIVE_SUBDOMAINS canlı subdomain bulundu (HTTP 200-400)${NC}"
        
        # httprobe ile de kontrol et
        echo -e "${BLUE}[+] httprobe ile canlı subdomain kontrolü yapılıyor...${NC}"
        if command -v httprobe &> /dev/null; then
            # pv ile loading çubuğu ekle
            if command -v pv &> /dev/null; then
                cat "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt" | \
                pv -p -t -e -s "$TOTAL_SUBDOMAINS" | \
                httprobe -c 5 -p http,https | \
                tee "$SUBS_LIVE_DIR/httprobe_all_${DOMAIN}.txt" | \
                tee >(grep "^http://" > "$SUBS_LIVE_DIR/http-httprobe-domains.txt") \
                    >(grep "^https://" > "$SUBS_LIVE_DIR/https-httprobe-domains.txt")
            else
                # pv yoksa normal çalıştır
                cat "$SUBS_LIVE_DIR/combined_all_subdomains_${DOMAIN}.txt" | \
                httprobe -c 5 -p http,https | \
                tee "$SUBS_LIVE_DIR/httprobe_all_${DOMAIN}.txt" | \
                tee >(grep "^http://" > "$SUBS_LIVE_DIR/http-httprobe-domains.txt") \
                    >(grep "^https://" > "$SUBS_LIVE_DIR/https-httprobe-domains.txt")
            fi
            
            # httprobe ve httpx sonuçlarını birleştir
            cat "$SUBS_LIVE_DIR/httprobe_all_${DOMAIN}.txt" "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt" | sort -u > "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt"
            
            COMBINED_LIVE=$(wc -l < "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt")
            echo -e "${GREEN}[+] httprobe tamamlandı: Toplam $COMBINED_LIVE benzersiz canlı subdomain bulundu${NC}"
        else
            echo -e "${RED}[-] httprobe bulunamadı${NC}"
            cp "$SUBS_LIVE_DIR/200-400-httpx-domains-clean.txt" "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt"
        fi
    else
        echo -e "${RED}[-] httpx bulunamadı${NC}"
    fi
fi

# Screenshot işlemi
if $SCREENSHOT && [ -f "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt" ]; then
    echo -e "${BLUE}[+] aquatone ile ekran görüntüleri alınıyor...${NC}"
    
    if command -v aquatone &> /dev/null; then
        SCREENSHOT_DIR="$SUBS_LIVE_DIR/aquatone_results"
        mkdir -p "$SCREENSHOT_DIR"
        
        # Toplam canlı subdomain sayısını al
        TOTAL_LIVE_DOMAINS=$(wc -l < "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt")
        
        # pv ile loading çubuğu ekle
        if command -v pv &> /dev/null; then
            cat "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt" | \
            pv -p -t -e -s "$TOTAL_LIVE_DOMAINS" | \
            aquatone -silent -out "$SCREENSHOT_DIR" -scan-timeout 1000 -http-timeout 5000
        else
            # pv yoksa normal çalıştır
            cat "$SUBS_LIVE_DIR/200-400-httpx-httprobe-domains.txt" | \
            aquatone -silent -out "$SCREENSHOT_DIR" -scan-timeout 1000 -http-timeout 5000
        fi
        
        echo -e "${GREEN}[+] aquatone tamamlandı: Ekran görüntüleri $SCREENSHOT_DIR dizinine kaydedildi${NC}"
    else
        echo -e "${RED}[-] aquatone bulunamadı${NC}"
    fi
else
    if $SCREENSHOT; then
        echo -e "${YELLOW}[!] Ekran görüntüsü alınacak canlı subdomain bulunamadı${NC}"
    fi
fi
 
echo -e "${GREEN}###------- Subdomain Live Check ve Screenshot tamamlandı: $DOMAIN -------###${NC}" 