#!/bin/bash

# Parameter Analysis Modülü
# TheBestRecon

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

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
    echo "Kullanım: $0 <domain> [-o output_dir] [-t threads]"
    exit 1
fi

# Varsayılan değerler
THREADS=5

# Output dizinini belirle
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# Parametre analizi için dizin oluştur
PARAM_ANALYSIS_DIR="${OUTPUT_DIR}/param_analysis"
mkdir -p "$PARAM_ANALYSIS_DIR"

echo -e "${GREEN}###------- Parametre Analizi başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $PARAM_ANALYSIS_DIR${NC}"

# Başlangıç zamanını kaydet
START_TIME=$(date +%s)

# Parametre URL'lerini kontrol et
PARAM_URLS_FILE=""
if [ -f "${OUTPUT_DIR}/js_param_discovery/param_files/paramspider_urls.txt" ]; then
    PARAM_URLS_FILE="${OUTPUT_DIR}/js_param_discovery/param_files/paramspider_urls.txt"
    echo -e "${BLUE}[+] JS & Param Discovery modülünden parametreli URL'ler kullanılıyor${NC}"
    PARAMS_COUNT=$(wc -l < "$PARAM_URLS_FILE")
    echo -e "${GREEN}[+] $PARAMS_COUNT parametreli URL analiz edilecek${NC}"
else
    echo -e "${YELLOW}[!] Parametreli URL listesi bulunamadı${NC}"
    echo -e "${YELLOW}[!] Önce --param-discovery parametresi ile js_and_param_discovery.sh çalıştırın${NC}"
    
    # Alternatif: URL keşfinden parametreli URL'leri çıkar
    if [ -f "$OUTPUT_DIR/url_discovery/all_unique_urls.txt" ]; then
        echo -e "${BLUE}[+] URL Discovery modülünden parametreli URL'ler çıkartılıyor...${NC}"
        cat "$OUTPUT_DIR/url_discovery/all_unique_urls.txt" | grep -P "\?" | sort -u > "$PARAM_ANALYSIS_DIR/grep_param_urls.txt"
        GREP_PARAMS_COUNT=$(wc -l < "$PARAM_ANALYSIS_DIR/grep_param_urls.txt" 2>/dev/null || echo 0)
        
        if [ $GREP_PARAMS_COUNT -gt 0 ]; then
            echo -e "${GREEN}[+] URL listesinden $GREP_PARAMS_COUNT parametreli URL çıkartıldı${NC}"
            PARAM_URLS_FILE="$PARAM_ANALYSIS_DIR/grep_param_urls.txt"
        else
            echo -e "${RED}[-] Parametreli URL bulunamadı${NC}"
            exit 1
        fi
    else
        echo -e "${RED}[-] URL listesi bulunamadı${NC}"
        exit 1
    fi
fi

# 1. KXSS ile parametre analizi
if command -v kxss &> /dev/null; then
    echo -e "${BLUE}[+] KXSS ile XSS taraması başlatılıyor...${NC}"
    
    # Toplam URL sayısını hesapla
    TOTAL_URLS=$(wc -l < "$PARAM_URLS_FILE")
    CURRENT_URL=0
    
    # Her URL'yi KXSS ile tara
    cat "$PARAM_URLS_FILE" | while read -r url; do
        CURRENT_URL=$((CURRENT_URL + 1))
        echo -e "${CYAN}[*] KXSS [${CURRENT_URL}/${TOTAL_URLS}]: $url taranıyor...${NC}"
        echo "$url" | kxss >> "$PARAM_ANALYSIS_DIR/kxss_raw_results.txt"
    done
    
    KXSS_VULNS=$(wc -l < "$PARAM_ANALYSIS_DIR/kxss_raw_results.txt" 2>/dev/null || echo 0)
    
    if [ $KXSS_VULNS -gt 0 ]; then
        echo -e "${GREEN}[+] KXSS tamamlandı: $KXSS_VULNS potansiyel XSS zafiyeti bulundu${NC}"
        
        # KXSS çıktısından URL'leri ayıkla
        echo -e "${BLUE}[+] KXSS çıktısından URL'ler ayıklanıyor...${NC}"
        grep -o "URL: [^[:space:]]*" "$PARAM_ANALYSIS_DIR/kxss_raw_results.txt" | sed 's/URL: //' > "$PARAM_ANALYSIS_DIR/kxss_extracted_urls.txt"
        EXTRACTED_URLS=$(wc -l < "$PARAM_ANALYSIS_DIR/kxss_extracted_urls.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] KXSS çıktısından ${EXTRACTED_URLS} URL ayıklandı${NC}"
        
        # Ayıklanan URL'leri XSStrike ve Dalfox için kullanılacak dosyaya kopyala
        cp "$PARAM_ANALYSIS_DIR/kxss_extracted_urls.txt" "$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    else
        echo -e "${GREEN}[+] KXSS tamamlandı: XSS zafiyeti bulunamadı${NC}"
        # Orijinal URL listesini kullan
        cp "$PARAM_URLS_FILE" "$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    fi
else
    echo -e "${RED}[-] KXSS bulunamadı${NC}"
    # Orijinal URL listesini kullan
    cp "$PARAM_URLS_FILE" "$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
fi

# 2. XSStrike ile parametre analizi
if command -v xsstrike &> /dev/null ; then
    echo -e "${BLUE}[+] XSStrike ile XSS taraması başlatılıyor...${NC}"
    
    # Ayıklanan URL'leri kullan
    XSSTRIKE_URL_LIST="$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    XSSTRIKE_URLS_COUNT=$(wc -l < "$XSSTRIKE_URL_LIST" 2>/dev/null || echo 0)
    echo -e "${BLUE}[+] XSStrike ${XSSTRIKE_URLS_COUNT} URL üzerinde çalıştırılacak...${NC}"
    
    # XSStrike'ı çalıştır
    xsstrike --seeds "$XSSTRIKE_URL_LIST" --threads "$THREADS" --log-file "$PARAM_ANALYSIS_DIR/xsstrike_vulnerable.log"
    
    if [ -f "$PARAM_ANALYSIS_DIR/xsstrike_vulnerable.log" ]; then
        echo -e "${GREEN}[+] XSStrike tamamlandı: Sonuçlar xsstrike_vulnerable.log dosyasına kaydedildi${NC}"
        
        # Zafiyetleri logdan çıkart
        XSS_VULNS=$(wc -l < "$PARAM_ANALYSIS_DIR/xsstrike_vulnerable.log" 2>/dev/null || echo 0)
        
        if [ $XSS_VULNS -gt 0 ]; then
            echo -e "${GREEN}[+] XSStrike: $XSS_VULNS potansiyel XSS zafiyeti bulundu${NC}"
        else
            echo -e "${GREEN}[+] XSStrike: XSS zafiyeti bulunamadı${NC}"
        fi
    else
        echo -e "${YELLOW}[!] XSStrike log dosyası oluşturulmadı${NC}"
    fi
else
    echo -e "${RED}[-] XSStrike bulunamadı. tools/XSStrike dizininde olmalı${NC}"
fi

# 3. Dalfox ile parametre analizi
if command -v dalfox &> /dev/null; then
    echo -e "${BLUE}[+] Dalfox ile XSS taraması başlatılıyor...${NC}"
    
    # Ayıklanan URL'leri kullan
    DALFOX_URL_LIST="$PARAM_ANALYSIS_DIR/xss_urls_for_tools.txt"
    DALFOX_URLS_COUNT=$(wc -l < "$DALFOX_URL_LIST" 2>/dev/null || echo 0)
    echo -e "${BLUE}[+] Dalfox ${DALFOX_URLS_COUNT} URL üzerinde çalıştırılacak...${NC}"
    
    # Dalfox ile tarama yap
    dalfox file "$DALFOX_URL_LIST" -o "$PARAM_ANALYSIS_DIR/dalfox_vulnerable.json" -b hahwul.xss.ht --format json -w 5 --skip-mining-all
    
    if [ -f "$PARAM_ANALYSIS_DIR/dalfox_vulnerable.json" ]; then
        echo -e "${GREEN}[+] Dalfox tamamlandı: Sonuçlar dalfox_vulnerable.json dosyasına kaydedildi${NC}"
        
        # JSON dosyasından zafiyetleri çıkar (basit grep, gerçek projede daha iyi bir JSON parser kullanılabilir)
        DALFOX_VULNS=$(grep -c "vulnerable" "$PARAM_ANALYSIS_DIR/dalfox_vulnerable.json" 2>/dev/null || echo 0)
        
        if [ $DALFOX_VULNS -gt 0 ]; then
            echo -e "${GREEN}[+] Dalfox: $DALFOX_VULNS XSS zafiyeti bulundu${NC}"
        else
            echo -e "${GREEN}[+] Dalfox: XSS zafiyeti bulunamadı${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Dalfox sonuç dosyası oluşturulmadı${NC}"
    fi
else
    echo -e "${RED}[-] Dalfox bulunamadı${NC}"
fi

TOTAL_VULNS=$(wc -l < "$KXSS_VULNS" 2>/dev/null || echo 0)

if [ $TOTAL_VULNS -gt 0 ]; then
    echo -e "${GREEN}[+] Toplam $TOTAL_VULNS potansiyel XSS zafiyeti bulundu${NC}"
    echo -e "${YELLOW}[!] Sonuçları $PARAM_ANALYSIS_DIR/all_vulnerabilities.txt dosyasında inceleyebilirsiniz${NC}"
else
    echo -e "${GREEN}[+] Hiç XSS zafiyeti bulunamadı${NC}"
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
echo -e "${CYAN}[+] Toplam parametre analiz süresi: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- Parametre analizi tamamlandı: $DOMAIN -------###${NC}"