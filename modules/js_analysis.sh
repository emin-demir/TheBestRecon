#!/bin/bash

# JavaScript Analiz Modülü
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
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# JavaScript analizi için dizin oluştur
JS_ANALYSIS_DIR="${OUTPUT_DIR}/js_analysis"
mkdir -p "$JS_ANALYSIS_DIR"

echo -e "${GREEN}###------- JavaScript Analizi başlatılıyor: $DOMAIN -------###${NC}"
echo -e "${BLUE}[+] Çıktılar şu dizine kaydedilecek: $JS_ANALYSIS_DIR${NC}"

# JS Discovery modülünden indirilen JS dosyalarını kontrol et
JS_FILES_DIR=""
if [ -d "${OUTPUT_DIR}/js_param_discovery/js_files/downloaded_js" ]; then
    JS_FILES_DIR="${OUTPUT_DIR}/js_param_discovery/js_files/downloaded_js"
    echo -e "${BLUE}[+] JS Discovery modülünden indirilen JavaScript dosyaları kullanılıyor${NC}"
    JS_FILES_COUNT=$(find "$JS_FILES_DIR" -name "*.js" | wc -l)
    echo -e "${GREEN}[+] $JS_FILES_COUNT JavaScript dosyası analiz edilecek${NC}"
else
    echo -e "${YELLOW}[!] Önceden indirilmiş JavaScript dosyaları bulunamadı${NC}"
    echo -e "${YELLOW}[!] Önce --js-discovery parametresi ile js_and_param_discovery.sh çalıştırın${NC}"

fi

# 1. TruffleHog ile JavaScript dosyalarında gizli bilgiler ara
if command -v trufflehog &> /dev/null && [ -d "$JS_FILES_DIR" ]; then
    echo -e "${BLUE}[+] TruffleHog çalıştırılıyor...${NC}"
    trufflehog filesystem "$JS_FILES_DIR" | tee "$JS_ANALYSIS_DIR/trufflehog_results.txt"
    if [ -s "$JS_ANALYSIS_DIR/trufflehog_results.txt" ]; then
        echo -e "${GREEN}[+] TruffleHog tamamlandı: Sonuçlar trufflehog_results.txt dosyasına kaydedildi${NC}"
    else
        echo -e "${YELLOW}[!] TruffleHog herhangi bir gizli bilgi bulamadı${NC}"
        rm "$JS_ANALYSIS_DIR/trufflehog_results.txt" 2>/dev/null
    fi
else
    echo -e "${RED}[-] TruffleHog bulunamadı veya JavaScript dosyaları mevcut değil${NC}"
fi

# 2. JS dosyalarında regex ile sensistif bilgiler ara
if [ -d "$JS_FILES_DIR" ]; then
    echo -e "${BLUE}[+] JavaScript dosyalarında regex ile duyarlı bilgiler aranıyor...${NC}"

    # API anahtarları, tokenlar, şifreler vs. için regex listesi (sadece eşleşen kısmı göster)
    grep -r -i -o -E "api[_-]?key\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}['\"]?|secret[_-]?key\s*[:=]\s*['\"]?[A-Za-z0-9_\-]{8,}['\"]?|password\s*[:=]\s*['\"]?[A-Za-z0-9!@#$%^&*()_+\-]{6,}['\"]?|auth[_-]?token\s*[:=]\s*['\"]?[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+\.[A-Za-z0-9\-_=]+['\"]?" "$JS_FILES_DIR" | tee "$JS_ANALYSIS_DIR/regex_results_sensitive_strings.txt"

    # URL'ler için regex
    grep -r -i -o -E "https?://[a-zA-Z0-9./?=_-]{10,}" "$JS_FILES_DIR" | tee "$JS_ANALYSIS_DIR/regex_results_urls.txt"

    # Endpoint'ler için regex
    grep -r -i -o -E "/api/[a-zA-Z0-9/_-]{2,}" "$JS_FILES_DIR" | tee "$JS_ANALYSIS_DIR/regex_results_endpoints.txt"

    REGEX_HITS=$(wc -l < "$JS_ANALYSIS_DIR/regex_results_sensitive_strings.txt" 2>/dev/null || echo 0)
    echo -e "${GREEN}[+] Regex araması tamamlandı: $REGEX_HITS potansiyel duyarlı bilgi bulundu${NC}"
else
    echo -e "${RED}[-] JavaScript dosyaları mevcut değil${NC}"
fi

# 3. LinkFinder ile JS dosyalarından endpoint çıkar
if command -v linkfinder &> /dev/null  && [ -d "$JS_FILES_DIR" ]; then
    echo -e "${BLUE}[+] LinkFinder çalıştırılıyor...${NC}"
    mkdir -p "$JS_ANALYSIS_DIR/linkfinder_results"
    find "$JS_FILES_DIR" -name "*.js" | while read -r js_file; do
        filename=$(basename "$js_file")
        linkfinder -i "$js_file" -o "$JS_ANALYSIS_DIR/linkfinder_results/${filename%.js}.html" > /dev/null 2>&1
    done
    
    LF_FILES_COUNT=$(find "$JS_ANALYSIS_DIR/linkfinder_results" -name "*.html" | wc -l)
    echo -e "${GREEN}[+] LinkFinder tamamlandı: $LF_FILES_COUNT dosya analiz edildi${NC}"
else
    echo -e "${RED}[-] LinkFinder bulunamadı veya JavaScript dosyaları mevcut değil${NC}"
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
echo -e "${CYAN}[+] Toplam JavaScript analiz süresi: ${TOTAL_TIME_FORMATTED}${NC}"

echo -e "${GREEN}###------- JavaScript analizi tamamlandı: $DOMAIN -------###${NC}" 