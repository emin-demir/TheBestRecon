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

# Varsayılan değerler
OUTPUT_DIR=""
JS_DISCOVERY=false
PARAM_DISCOVERY=false

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
        *)
            DOMAIN="$1"
            shift
            ;;
    esac
done

# Domain parametresi kontrolü
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[-] Domain parametresi gerekli${NC}"
    echo "Kullanım: $0 <domain> [-o output_dir] [-js/--javascript] [-p/--params]"
    exit 1
fi

# Output dizini hazırla
JS_DIR="${OUTPUT_DIR}/js_param_discovery"
mkdir -p "$JS_DIR"
mkdir -p "$JS_DIR/js_files"
mkdir -p "$JS_DIR/param_files"

echo -e "${GREEN}###------- JavaScript ve Parameter Discovery başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $JS_DIR${NC}"

# URL listesini belirle (önce URL discovery modülünden, yoksa canlı subdomain listelerinden)
URL_LIST=""

if [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt" ]; then
    URL_LIST="$OUTPUT_DIR/subs_live/200-400-httpx-httprobe-domains.txt"
    echo -e "${BLUE}[+] Subs_live modülünden canlı domainler kullanılıyor${NC}"
    # subs_live dosyası zaten URL formatında olduğu için direkt kopyala
    cp "$URL_LIST" "$JS_DIR/domain_urls.txt"
elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
    URL_LIST="$OUTPUT_DIR/subdomain_brute/dnsx_live_subdomains_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_brute modülünden canlı domainler kullanılıyor${NC}"
    # dnsx çıktısı için http/https ekle
    cat "$URL_LIST" | sed 's/^/http:\/\//' > "$JS_DIR/http_urls.txt"
    cat "$URL_LIST" | sed 's/^/https:\/\//' > "$JS_DIR/https_urls.txt"
    cat "$JS_DIR/http_urls.txt" "$JS_DIR/https_urls.txt" > "$JS_DIR/domain_urls.txt"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt" ]; then
    URL_LIST="$OUTPUT_DIR/subdomain_enum/dnsx_live_subdomains_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_enum modülünden canlı domainler kullanılıyor${NC}"
    # dnsx çıktısı için http/https ekle
    cat "$URL_LIST" | sed 's/^/http:\/\//' > "$JS_DIR/http_urls.txt"
    cat "$URL_LIST" | sed 's/^/https:\/\//' > "$JS_DIR/https_urls.txt"
    cat "$JS_DIR/http_urls.txt" "$JS_DIR/https_urls.txt" > "$JS_DIR/domain_urls.txt"
else
    echo -e "${YELLOW}[!] Canlı subdomain veya URL listesi bulunamadı${NC}"
    echo -e "${YELLOW}[!] Önce --subs-live, --sub-enum, --sub-brute veya --url-discovery çalıştırın${NC}"
    exit 1
fi

# domain_urls.txt'yi URL_LIST olarak kullan
URL_LIST="$JS_DIR/domain_urls.txt"
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
        cat "$JS_DIR/js_files/getjs_urls.txt" | grep -E "http|https" > "$JS_DIR/js_files/getjs_urls.txt"
        GETJS_URLS_COUNT=$(wc -l < "$JS_DIR/js_files/getjs_urls.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] getJS tamamlandı: $GETJS_URLS_COUNT JavaScript URL'si bulundu${NC}"
    else
        echo -e "${RED}[-] getJS bulunamadı${NC}"
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
            aria2c -d "$JS_DIR/js_files/downloaded_js" -i "$JS_DIR/js_files/all_js_urls.txt"
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
        cd "$JS_DIR/param_files" || exit
        paramspider -l "$URL_LIST"
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

echo -e "${GREEN}###------- JavaScript ve Parameter Discovery tamamlandı: $DOMAIN -------###${NC}" 