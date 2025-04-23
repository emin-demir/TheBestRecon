#!/bin/bash

# JavaScript ve Parameter Discovery Modülü
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
JS_DISCOVERY=false
PARAM_DISCOVERY=false
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
        -js|--javascript)
            JS_DISCOVERY=true
            shift
            ;;
        -p|--params)
            PARAM_DISCOVERY=true
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
    echo "Kullanım: $0 <domain> [-o output_dir] [-js/--javascript] [-p/--params] [--scan-mode short|medium|big]"
    exit 1
fi

# Output dizini hazırla
JS_DIR="${OUTPUT_DIR}/js_param_discovery"
mkdir -p "$JS_DIR"
mkdir -p "$JS_DIR/js_files"
mkdir -p "$JS_DIR/param_files"

echo -e "${GREEN}###------- JavaScript ve Parameter Discovery başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $JS_DIR${NC}"
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
URL_LIST=""
case $SCAN_MODE in
    "short")
        if [ -f "$TEMP_DIR/short_urls.txt" ]; then
            URL_LIST="$TEMP_DIR/short_urls.txt"
            echo -e "${BLUE}[+] Kısa tarama modu seçildi - Kritik subdomainler ile tarama yapılacak${NC}"
        else
            echo -e "${YELLOW}[!] Short mode URL listesi bulunamadı, varsayılan liste kullanılacak${NC}"
        fi
        ;;
    "medium")
        if [ -f "$TEMP_DIR/medium_urls.txt" ]; then
            URL_LIST="$TEMP_DIR/medium_urls.txt"
            echo -e "${BLUE}[+] Orta tarama modu seçildi - Önemli subdomainler ile tarama yapılacak${NC}"
        else
            echo -e "${YELLOW}[!] Medium mode URL listesi bulunamadı, varsayılan liste kullanılacak${NC}"
        fi
        ;;
    *)
        echo -e "${BLUE}[+] Büyük tarama modu seçildi - Tüm subdomainler taranacak${NC}"
        if [ -f "$TEMP_DIR/all_urls.txt" ]; then
            URL_LIST="$TEMP_DIR/all_urls.txt"
        fi
        ;;
esac

# Eğer URL_LIST hala boşsa, varsayılan kaynaklardan bul
if [ -z "$URL_LIST" ]; then
    if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
        URL_LIST="$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt"
        echo -e "${BLUE}[+] Subs_live modülünden canlı domainler kullanılıyor${NC}"
    elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
        URL_LIST="$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt"
        echo -e "${BLUE}[+] Subdomain_brute modülünden canlı domainler kullanılıyor${NC}"
    elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
        URL_LIST="$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt"
        echo -e "${BLUE}[+] Subdomain_enum modülünden canlı domainler kullanılıyor${NC}"
    else
        echo -e "${YELLOW}[!] Canlı subdomain listesi bulunamadı${NC}"
        echo -e "${YELLOW}[!] Ana domain kullanılıyor...${NC}"
        if [[ $DOMAIN != http://* ]] && [[ $DOMAIN != https://* ]]; then
            echo "https://$DOMAIN" > "$JS_DIR/domain.txt"
        else
            echo "$DOMAIN" > "$JS_DIR/domain.txt"
        fi
        URL_LIST="$JS_DIR/domain.txt"
    fi
fi


URLS_COUNT=$(wc -l < "$URL_LIST")
echo -e "${GREEN}[+] $URLS_COUNT URL üzerinde keşif yapılacak${NC}"

# JavaScript Discovery işlemi
if $JS_DISCOVERY; then
    echo -e "${BLUE}[+] JavaScript Discovery başlatılıyor...${NC}"
    
    # 1. subjs ile JavaScript URL'lerini bul
    echo -e "${BLUE}[+] subjs çalıştırılıyor...${NC}"
    if command -v subjs &> /dev/null; then
        cat "$URL_LIST" | subjs -c 100 | tee "$JS_DIR/js_files/js_urls.txt"
        JS_URLS_COUNT=$(wc -l < "$JS_DIR/js_files/js_urls.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] subjs tamamlandı: $JS_URLS_COUNT JavaScript URL'si bulundu${NC}"
    else
        echo -e "${RED}[-] subjs bulunamadı${NC}"
    fi
    
    # 2. getJS ile JavaScript URL'lerini bul
    echo -e "${BLUE}[+] getJS çalıştırılıyor...${NC}"
    if command -v getJS &> /dev/null; then
        getJS -input "$URL_LIST" -complete -resolve -output "$JS_DIR/js_files/getjs_urls.txt" 
        if [ -f "$JS_DIR/js_files/getjs_urls.txt" ]; then
            cat "$JS_DIR/js_files/getjs_urls.txt" | grep -E "http|https" > "$JS_DIR/js_files/getjs_urls_filtered.txt"
            mv "$JS_DIR/js_files/getjs_urls_filtered.txt" "$JS_DIR/js_files/getjs_urls.txt"
            GETJS_URLS_COUNT=$(wc -l < "$JS_DIR/js_files/getjs_urls.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] getJS tamamlandı: $GETJS_URLS_COUNT JavaScript URL'si bulundu${NC}"
        else
            echo -e "${YELLOW}[!] getJS herhangi bir sonuç bulamadı${NC}"
            touch "$JS_DIR/js_files/getjs_urls.txt"
        fi
    else
        echo -e "${RED}[-] getJS bulunamadı${NC}"
    fi
    
    # URL Discovery modülünden all_unique_urls.txt dosyasını kontrol et
    if [ -f "${OUTPUT_DIR}/url_discovery/all_unique_urls.txt" ]; then
        echo -e "${BLUE}[+] URL Discovery modülünden tüm URL'ler kontrol ediliyor...${NC}"
        # .js ile biten URL'leri ayıkla
        cat "${OUTPUT_DIR}/url_discovery/all_unique_urls.txt" | grep -i "\.js$" > "$JS_DIR/js_files/urls_discovery_js.txt"
        JS_FROM_URL_DISC=$(wc -l < "$JS_DIR/js_files/urls_discovery_js.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] URL Discovery modülünden $JS_FROM_URL_DISC JavaScript URL'si bulundu${NC}"
    else
        echo -e "${YELLOW}[!] URL Discovery modülünde all_unique_urls.txt dosyası bulunamadı${NC}"
    fi
    
    # Tüm JavaScript URL'lerini birleştir
    cat "$JS_DIR/js_files"/*.txt 2>/dev/null | sort -u > "$JS_DIR/js_files/all_js_urls.txt"
    TOTAL_JS=$(wc -l < "$JS_DIR/js_files/all_js_urls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Toplam $TOTAL_JS benzersiz JavaScript URL'si bulundu${NC}"
    
    if [ $TOTAL_JS -gt 0 ]; then
        # JavaScript dosyalarını indir
        echo -e "${BLUE}[+] JavaScript dosyaları indiriliyor...${NC}"
        mkdir -p "$JS_DIR/js_files/downloaded_js"
        
        if command -v aria2c &> /dev/null; then
            aria2c -d "$JS_DIR/js_files/downloaded_js" -i "$JS_DIR/js_files/all_js_urls.txt" --timeout=20 --max-tries=3 --retry-wait=3
            JS_FILES_COUNT=$(find "$JS_DIR/js_files/downloaded_js" -name "*.js" | wc -l)
            echo -e "${GREEN}[+] JavaScript dosyaları indirildi: $JS_FILES_COUNT dosya${NC}"
        else
            echo -e "${RED}[-] aria2c bulunamadı, JS dosyaları indirilemiyor${NC}"
            echo -e "${YELLOW}[!] Lütfen 'sudo apt install aria2' komutu ile aria2c'yi kurun${NC}"
        fi
    fi
    
    echo -e "${GREEN}[+] JavaScript Discovery tamamlandı${NC}"
    echo -e "${YELLOW}[!] JavaScript dosyalarını analiz etmek için js_analysis.sh modülünü çalıştırın${NC}"
fi

# Parameter Discovery işlemi
if $PARAM_DISCOVERY; then
    echo -e "${BLUE}[+] Parameter Discovery başlatılıyor...${NC}"
    
    # URL listesini kullan (zaten yukarıda belirledik)
    URLS_COUNT=$(wc -l < "$URL_LIST")
    echo -e "${GREEN}[+] $URLS_COUNT URL üzerinde parametre keşfi yapılacak${NC}"
    
    # 1. ParamSpider ile parametre keşfi
    echo -e "${BLUE}[+] ParamSpider çalıştırılıyor...${NC}"
    if command -v paramspider &> /dev/null; then
        # URL dosyasının tam yolunu al
        ABSOLUTE_URL_LIST=$(realpath "$URL_LIST")
        
        cd "$JS_DIR/param_files" || exit
        paramspider -l "$ABSOLUTE_URL_LIST"
        cd - > /dev/null || exit
        
        if [ -d "$JS_DIR/param_files/results" ]; then
            cat "$JS_DIR/param_files/results"/*.txt 2>/dev/null | sort -u > "$JS_DIR/param_files/paramspider_urls.txt"
            PARAMS_COUNT=$(wc -l < "$JS_DIR/param_files/paramspider_urls.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] ParamSpider tamamlandı: $PARAMS_COUNT parametreli URL bulundu${NC}"
        else
            echo -e "${YELLOW}[!] ParamSpider herhangi bir sonuç bulamadı${NC}"
        fi
    else
        echo -e "${RED}[-] ParamSpider bulunamadı${NC}"
    fi
    
    # 2. x8 ile parametre keşfi
    echo -e "${BLUE}[+] x8 çalıştırılıyor...${NC}"
    if command -v x8 &> /dev/null; then
        x8 -u "$URL_LIST" -o "$JS_DIR/param_files/x8_results.txt"
        if [ -f "$JS_DIR/param_files/x8_results.txt" ]; then
            X8_PARAMS_COUNT=$(wc -l < "$JS_DIR/param_files/x8_results.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] x8 tamamlandı: $X8_PARAMS_COUNT parametreli URL bulundu${NC}"
        else
            echo -e "${YELLOW}[!] x8 herhangi bir sonuç bulamadı${NC}"
        fi
    else
        echo -e "${RED}[-] x8 bulunamadı${NC}"
    fi
    
    # 3. Arjun ile URL'lerde bilinmeyen parametreleri bul
    echo -e "${BLUE}[+] Arjun çalıştırılıyor...${NC}"
    if command -v arjun &> /dev/null; then
        arjun -i "$URL_LIST" -oT "$JS_DIR/param_files/arjun_hidden_params.txt"
        if [ -f "$JS_DIR/param_files/arjun_hidden_params.txt" ]; then
            ARJUN_PARAMS_COUNT=$(wc -l < "$JS_DIR/param_files/arjun_hidden_params.txt" 2>/dev/null || echo 0)
            echo -e "${GREEN}[+] Arjun tamamlandı: $ARJUN_PARAMS_COUNT gizli parametre bulundu${NC}"
        else
            echo -e "${YELLOW}[!] Arjun herhangi bir sonuç bulamadı${NC}"
        fi
    else
        echo -e "${RED}[-] Arjun bulunamadı${NC}"
    fi
    
    # Tüm parametreli URL'leri birleştir
    cat "$JS_DIR/param_files"/*_urls.txt "$JS_DIR/param_files"/*_output/*.txt 2>/dev/null | sort -u > "$JS_DIR/param_files/all_param_urls.txt"
    TOTAL_PARAMS=$(wc -l < "$JS_DIR/param_files/all_param_urls.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Toplam $TOTAL_PARAMS benzersiz parametreli URL bulundu${NC}"

    echo -e "${GREEN}[+] Parameter Discovery tamamlandı${NC}"
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
echo -e "${CYAN}[+] Toplam keşif süresi: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- JavaScript ve Parameter Discovery tamamlandı: $DOMAIN -------###${NC}" 
