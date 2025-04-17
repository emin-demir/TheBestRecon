#!/bin/bash

# Vulnerability Scanning Modülü
# TheBestRecon

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
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

# Varsayılan değerler
THREADS=5
RATE_LIMIT=10

# Output dizinini belirle
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# Vulnerability scan için dizin oluştur
VULN_SCAN_DIR="${OUTPUT_DIR}/vuln_scan"
mkdir -p "$VULN_SCAN_DIR"
mkdir -p "$VULN_SCAN_DIR/nuclei_results"
mkdir -p "$VULN_SCAN_DIR/smuggler_results"
mkdir -p "$VULN_SCAN_DIR/bfac_results"
mkdir -p "$VULN_SCAN_DIR/gochopchop_results"
mkdir -p "$VULN_SCAN_DIR/snallygaster_results"
mkdir -p "$VULN_SCAN_DIR/lazyhunter_results"
mkdir -p "$VULN_SCAN_DIR/corscanner_results"
mkdir -p "$VULN_SCAN_DIR/arjun_results"

echo -e "${BLUE}#==============================================================#${NC}"
echo -e "${BLUE}# ${GREEN}TheBestRecon - Kapsamlı Zafiyet Tarama${BLUE}                     #${NC}"
echo -e "${BLUE}#==============================================================#${NC}"
echo -e "${GREEN}[+] Hedef Domain: ${CYAN}$DOMAIN${NC}"
echo -e "${GREEN}[+] Çıktılar şu dizine kaydedilecek: ${CYAN}$VULN_SCAN_DIR${NC}"
echo -e "${GREEN}[+] Threadler: ${CYAN}$THREADS${NC}, Rate Limit: ${CYAN}$RATE_LIMIT${NC}"
echo

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
    echo -e "${YELLOW}[!] Ana domain kullanılıyor...${NC}"
    echo "$DOMAIN" > "$VULN_SCAN_DIR/single_domain.txt"
    LIVE_DOMAINS_FILE="$VULN_SCAN_DIR/single_domain.txt"
fi

DOMAINS_COUNT=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] $DOMAINS_COUNT canlı domain üzerinde zafiyet taraması yapılacak${NC}"

# URL Listesi oluştur
cat "$LIVE_DOMAINS_FILE" | sed 's/^/https:\/\//' > "$VULN_SCAN_DIR/https_urls.txt"
URL_LIST="$VULN_SCAN_DIR/https_urls.txt"
URLS_COUNT=$(wc -l < "$URL_LIST")
echo -e "${GREEN}[+] $URLS_COUNT URL üzerinde tarama yapılacak${NC}"

# IP listesini kontrol et (port tarama için)
IP_FILE=""
if [ -f "$OUTPUT_DIR/port_scan/resolved_ips.txt" ]; then
    IP_FILE="$OUTPUT_DIR/port_scan/resolved_ips.txt"
    echo -e "${BLUE}[+] Port scan modülünden IP listesi kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dns_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_enum/dns_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain enumeration modülünden IP listesi kullanılıyor${NC}"
else
    echo -e "${YELLOW}[!] IP listesi bulunamadı${NC}"
    echo -e "${YELLOW}[!] LazyHunter taraması atlanacak${NC}"
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

# İlerleme raporu fonksiyonu
report_progress() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local elapsed_formatted=$(format_time $elapsed)
    echo -e "${CYAN}[*] Geçen süre: $elapsed_formatted${NC}"
}

# 1. Nuclei ile zafiyet tarama
echo -e "\n${MAGENTA}#----- Nuclei ile Zafiyet Tarama -----#${NC}"
if command -v nuclei &> /dev/null; then
    echo -e "${BLUE}[+] Nuclei taraması başlatılıyor...${NC}"
    echo -e "${CYAN}[*] Bu işlem birkaç dakika sürebilir${NC}"
    
    # Nuclei tarama başlangıç zamanı
    NUCLEI_START=$(date +%s)
    
    # Nuclei çalıştır - severity parametrelerini ekledik
    nuclei -l "$LIVE_DOMAINS_FILE" \
        -c "$THREADS" \
        -rate-limit "$RATE_LIMIT" \
        -bs 20 \
        -uc \
        -silent \
        -severity critical,high,medium,low,info \
        -o "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt"
    
    # Nuclei tarama bitiş zamanı
    NUCLEI_END=$(date +%s)
    NUCLEI_TIME=$((NUCLEI_END - NUCLEI_START))
    NUCLEI_TIME_FORMATTED=$(format_time $NUCLEI_TIME)
    
    # Sonuçları şiddet seviyesine göre ayır
    if [ -f "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" ]; then
        # Kritik
        grep -i "\[critical\]" "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" > "$VULN_SCAN_DIR/nuclei_results/critical.txt"
        CRIT_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_results/critical.txt" 2>/dev/null || echo 0)
        
        # Yüksek
        grep -i "\[high\]" "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" > "$VULN_SCAN_DIR/nuclei_results/high.txt"
        HIGH_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_results/high.txt" 2>/dev/null || echo 0)
        
        # Orta
        grep -i "\[medium\]" "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" > "$VULN_SCAN_DIR/nuclei_results/medium.txt"
        MED_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_results/medium.txt" 2>/dev/null || echo 0)
        
        # Düşük
        grep -i "\[low\]" "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" > "$VULN_SCAN_DIR/nuclei_results/low.txt"
        LOW_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_results/low.txt" 2>/dev/null || echo 0)
        
        # Bilgi
        grep -i "\[info\]" "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" > "$VULN_SCAN_DIR/nuclei_results/info.txt"
        INFO_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_results/info.txt" 2>/dev/null || echo 0)
        
        echo -e "${GREEN}[+] Nuclei taraması tamamlandı: Süre: $NUCLEI_TIME_FORMATTED${NC}"
        echo -e "${GREEN}[+] Sonuçlar:${NC}"
        echo -e "   ${RED}Kritik: $CRIT_COUNT${NC}"
        echo -e "   ${MAGENTA}Yüksek: $HIGH_COUNT${NC}"
        echo -e "   ${YELLOW}Orta: $MED_COUNT${NC}"
        echo -e "   ${BLUE}Düşük: $LOW_COUNT${NC}"
        echo -e "   ${CYAN}Bilgi: $INFO_COUNT${NC}"
    else
        echo -e "${YELLOW}[!] Nuclei sonuç dosyası oluşturulmadı${NC}"
    fi
else
    echo -e "${RED}[-] nuclei bulunamadı${NC}"
fi

report_progress

# 2. HTTP Smuggler ile HTTP request smuggling taraması
echo -e "\n${MAGENTA}#----- HTTP Smuggler Taraması -----#${NC}"
if command -v smuggler &> /dev/null; then
    echo -e "${BLUE}[+] HTTP Smuggling zafiyeti taraması başlatılıyor...${NC}"
    
    # HTTP Smuggler performans için daha küçük alt küme kullan
    MAX_SMUGGLER_URLS=20
    if [ $URLS_COUNT -gt $MAX_SMUGGLER_URLS ]; then
        echo -e "${YELLOW}[!] Performans için ilk $MAX_SMUGGLER_URLS URL taranacak${NC}"
        head -$MAX_SMUGGLER_URLS "$URL_LIST" > "$VULN_SCAN_DIR/smuggler_urls.txt"
    else
        cp "$URL_LIST" "$VULN_SCAN_DIR/smuggler_urls.txt"
    fi
    
    cat "$VULN_SCAN_DIR/smuggler_urls.txt" | smuggler > "$VULN_SCAN_DIR/smuggler_results/smuggler_output.txt"
    
    SMUGGLER_VULNS=$(grep -c "Vulnerable" "$VULN_SCAN_DIR/smuggler_results/smuggler_output.txt" 2>/dev/null || echo 0)
    
    if [ $SMUGGLER_VULNS -gt 0 ]; then
        grep -B 5 -A 2 "Vulnerable" "$VULN_SCAN_DIR/smuggler_results/smuggler_output.txt" > "$VULN_SCAN_DIR/smuggler_results/smuggler_vulnerabilities.txt"
        echo -e "${GREEN}[+] HTTP Smuggling taraması tamamlandı: $SMUGGLER_VULNS potansiyel zafiyet bulundu${NC}"
    else
        echo -e "${GREEN}[+] HTTP Smuggling taraması tamamlandı: Zafiyet bulunamadı${NC}"
    fi
else
    echo -e "${RED}[-] smuggler bulunamadı${NC}"
fi

report_progress

# 3. BFAC ile backup file taraması
echo -e "\n${MAGENTA}#----- Backup File Access Checker (BFAC) Taraması -----#${NC}"
if command -v bfac &> /dev/null; then
    echo -e "${BLUE}[+] BFAC taraması başlatılıyor...${NC}"
    
    # BFAC performans için daha küçük alt küme kullan
    MAX_BFAC_URLS=30
    if [ $URLS_COUNT -gt $MAX_BFAC_URLS ]; then
        echo -e "${YELLOW}[!] Performans için ilk $MAX_BFAC_URLS URL taranacak${NC}"
        head -$MAX_BFAC_URLS "$URL_LIST" > "$VULN_SCAN_DIR/bfac_urls.txt"
    else
        cp "$URL_LIST" "$VULN_SCAN_DIR/bfac_urls.txt"
    fi
    
    bfac --list "$VULN_SCAN_DIR/bfac_urls.txt" \
         --thread $THREADS \
         --level 3 \
         --detection-technique all \
         --no-text > "$VULN_SCAN_DIR/bfac_results/bfac_output.txt"
    
    BFAC_VULNS=$(grep -c "FOUND" "$VULN_SCAN_DIR/bfac_results/bfac_output.txt" 2>/dev/null || echo 0)
    
    if [ $BFAC_VULNS -gt 0 ]; then
        grep "FOUND" "$VULN_SCAN_DIR/bfac_results/bfac_output.txt" > "$VULN_SCAN_DIR/bfac_results/bfac_vulnerabilities.txt"
        echo -e "${GREEN}[+] BFAC taraması tamamlandı: $BFAC_VULNS potansiyel erişilebilir yedek dosya bulundu${NC}"
    else
        echo -e "${GREEN}[+] BFAC taraması tamamlandı: Erişilebilir yedek dosya bulunamadı${NC}"
    fi
else
    echo -e "${RED}[-] bfac bulunamadı${NC}"
fi

report_progress

# 4. GoChopChop ile zafiyetli endpoint taraması
echo -e "\n${MAGENTA}#----- GoChopChop Endpoint Taraması -----#${NC}"
if command -v gochopchop &> /dev/null; then
    echo -e "${BLUE}[+] GoChopChop taraması başlatılıyor...${NC}"
    
    gochopchop scan -t $THREADS -u "$LIVE_DOMAINS_FILE" > "$VULN_SCAN_DIR/gochopchop_results/gochopchop_output.txt"
    
    GOCHOP_VULNS=$(grep -c "Vulnerable" "$VULN_SCAN_DIR/gochopchop_results/gochopchop_output.txt" 2>/dev/null || echo 0)
    
    if [ $GOCHOP_VULNS -gt 0 ]; then
        grep -A 3 "Vulnerable" "$VULN_SCAN_DIR/gochopchop_results/gochopchop_output.txt" > "$VULN_SCAN_DIR/gochopchop_results/gochopchop_vulnerabilities.txt"
        echo -e "${GREEN}[+] GoChopChop taraması tamamlandı: $GOCHOP_VULNS zafiyetli endpoint bulundu${NC}"
    else
        echo -e "${GREEN}[+] GoChopChop taraması tamamlandı: Zafiyetli endpoint bulunamadı${NC}"
    fi
else
    echo -e "${RED}[-] gochopchop bulunamadı${NC}"
fi

report_progress

# 5. Snallygaster ile gizli dosya taraması
echo -e "\n${MAGENTA}#----- Snallygaster Gizli Dosya Taraması -----#${NC}"
if command -v snallygaster &> /dev/null; then
    echo -e "${BLUE}[+] Snallygaster taraması başlatılıyor...${NC}"
    
    snallygaster hosts "$LIVE_DOMAINS_FILE" > "$VULN_SCAN_DIR/snallygaster_results/snallygaster_output.txt"
    
    SNALLY_FINDINGS=$(wc -l < "$VULN_SCAN_DIR/snallygaster_results/snallygaster_output.txt" 2>/dev/null || echo 0)
    
    if [ $SNALLY_FINDINGS -gt 0 ]; then
        echo -e "${GREEN}[+] Snallygaster taraması tamamlandı: $SNALLY_FINDINGS potansiyel bulgu${NC}"
    else
        echo -e "${GREEN}[+] Snallygaster taraması tamamlandı: Gizli dosya bulunamadı${NC}"
    fi
else
    echo -e "${RED}[-] snallygaster bulunamadı${NC}"
fi

report_progress

# 6. LazyHunter ile IP tabanlı zafiyet taraması
echo -e "\n${MAGENTA}#----- LazyHunter IP Tabanlı Zafiyet Taraması -----#${NC}"
if command -v lazyhunter &> /dev/null && [ -n "$IP_FILE" ]; then
    echo -e "${BLUE}[+] LazyHunter taraması başlatılıyor...${NC}"
    echo -e "${CYAN}[*] Bu işlem biraz zaman alabilir${NC}"
    
    lazyhunter -f "$IP_FILE" --cve+ports --host > "$VULN_SCAN_DIR/lazyhunter_results/lazyhunter_output.txt"
    
    # CVE sayısını tespit et
    LH_CVES=$(grep -c "CVE-" "$VULN_SCAN_DIR/lazyhunter_results/lazyhunter_output.txt" 2>/dev/null || echo 0)
    
    if [ $LH_CVES -gt 0 ]; then
        grep -B 2 -A 2 "CVE-" "$VULN_SCAN_DIR/lazyhunter_results/lazyhunter_output.txt" > "$VULN_SCAN_DIR/lazyhunter_results/lazyhunter_cves.txt"
        echo -e "${GREEN}[+] LazyHunter taraması tamamlandı: $LH_CVES potansiyel CVE bulundu${NC}"
    else
        echo -e "${GREEN}[+] LazyHunter taraması tamamlandı: CVE bulunamadı${NC}"
    fi
elif [ -z "$IP_FILE" ]; then
    echo -e "${YELLOW}[!] IP listesi bulunamadığı için LazyHunter taraması atlandı${NC}"
else
    echo -e "${RED}[-] lazyhunter bulunamadı${NC}"
fi

report_progress

# YENİ: 7. CORScanner ile CORS zafiyeti taraması
echo -e "\n${MAGENTA}#----- CORScanner CORS Zafiyet Taraması -----#${NC}"
if command -v corscanner &> /dev/null; then
    echo -e "${BLUE}[+] CORScanner taraması başlatılıyor...${NC}"
    
    # Maksimum URL sınırlaması
    MAX_CORS_URLS=100
    if [ $DOMAINS_COUNT -gt $MAX_CORS_URLS ]; then
        echo -e "${YELLOW}[!] Performans için ilk $MAX_CORS_URLS domain taranacak${NC}"
        head -$MAX_CORS_URLS "$LIVE_DOMAINS_FILE" > "$VULN_SCAN_DIR/cors_domains.txt"
        CORS_INPUT="$VULN_SCAN_DIR/cors_domains.txt"
    else
        CORS_INPUT="$LIVE_DOMAINS_FILE"
    fi
    
    # CORScanner çalıştır
    corscanner -i "$CORS_INPUT" -t "$THREADS" -o "$VULN_SCAN_DIR/corscanner_results/cors_vulnerabilities.txt"
    
    # Sonuçları kontrol et
    if [ -f "$VULN_SCAN_DIR/corscanner_results/cors_vulnerabilities.txt" ]; then
        CORS_VULNS=$(wc -l < "$VULN_SCAN_DIR/corscanner_results/cors_vulnerabilities.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] CORScanner taraması tamamlandı: $CORS_VULNS potansiyel CORS zafiyeti bulundu${NC}"
    else
        echo -e "${GREEN}[+] CORScanner taraması tamamlandı: CORS zafiyeti bulunamadı${NC}"
        CORS_VULNS=0
    fi
else
    echo -e "${RED}[-] corscanner bulunamadı${NC}"
    CORS_VULNS=0
fi

report_progress

# YENİ: 8. Arjun ile parametre keşfi
echo -e "\n${MAGENTA}#----- Arjun Parametre Keşfi -----#${NC}"
if command -v arjun &> /dev/null; then
    echo -e "${BLUE}[+] Arjun parametre keşfi başlatılıyor...${NC}"
    
    # Performans için URL sayısı sınırla
    MAX_ARJUN_URLS=10
    if [ $URLS_COUNT -gt $MAX_ARJUN_URLS ]; then
        echo -e "${YELLOW}[!] Performans için ilk $MAX_ARJUN_URLS URL taranacak${NC}"
        head -$MAX_ARJUN_URLS "$URL_LIST" > "$VULN_SCAN_DIR/arjun_urls.txt"
    else
        cp "$URL_LIST" "$VULN_SCAN_DIR/arjun_urls.txt"
    fi
    
    # Her URL için Arjun çalıştır
    mkdir -p "$VULN_SCAN_DIR/arjun_results/json"
    while read -r url; do
        url_hash=$(echo "$url" | md5sum | cut -d' ' -f1)
        echo -e "${CYAN}[*] Arjun: $url URL'inde parametreler aranıyor...${NC}"
        arjun -u "$url" -t "$THREADS" -o "$VULN_SCAN_DIR/arjun_results/json/${url_hash}.json"
    done < "$VULN_SCAN_DIR/arjun_urls.txt"
    
    # Sonuçları birleştir
    echo -e "${BLUE}[+] Arjun sonuçları analiz ediliyor...${NC}"
    ARJUN_FILES=$(find "$VULN_SCAN_DIR/arjun_results/json" -name "*.json" | wc -l)
    
    # Parametre sayısını bul
    PARAM_COUNT=0
    for file in "$VULN_SCAN_DIR/arjun_results/json"/*.json; do
        if [ -f "$file" ]; then
            # grep ile parametre sayısını bul (basit bir yaklaşım)
            params=$(grep -o '"[^"]*":' "$file" | wc -l)
            PARAM_COUNT=$((PARAM_COUNT + params))
        fi
    done
    
    echo -e "${GREEN}[+] Arjun taraması tamamlandı: $ARJUN_FILES URL tarandı, $PARAM_COUNT potansiyel parametre bulundu${NC}"
else
    echo -e "${RED}[-] arjun bulunamadı${NC}"
fi

report_progress

# Özet rapor oluştur
echo -e "\n${MAGENTA}#============ Zafiyet Tarama Özeti ============#${NC}"
echo -e "${BLUE}Hedef:${NC} $DOMAIN"
echo -e "${BLUE}Taranan Subdomain Sayısı:${NC} $DOMAINS_COUNT"

# Nuclei sonuçları
if [ -f "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" ]; then
    NUCLEI_TOTAL=$(wc -l < "$VULN_SCAN_DIR/nuclei_results/all_vulnerabilities.txt" 2>/dev/null || echo 0)
    echo -e "${BLUE}Nuclei Bulguları:${NC} $NUCLEI_TOTAL"
    if [ $CRIT_COUNT -gt 0 ]; then echo -e "  ${RED}Kritik:${NC} $CRIT_COUNT"; fi
    if [ $HIGH_COUNT -gt 0 ]; then echo -e "  ${MAGENTA}Yüksek:${NC} $HIGH_COUNT"; fi
    if [ $MED_COUNT -gt 0 ]; then echo -e "  ${YELLOW}Orta:${NC} $MED_COUNT"; fi
    if [ $LOW_COUNT -gt 0 ]; then echo -e "  ${BLUE}Düşük:${NC} $LOW_COUNT"; fi
    if [ $INFO_COUNT -gt 0 ]; then echo -e "  ${CYAN}Bilgi:${NC} $INFO_COUNT"; fi
fi

# Diğer araçların bulguları
if [ -f "$VULN_SCAN_DIR/smuggler_results/smuggler_output.txt" ]; then
    echo -e "${BLUE}HTTP Smuggling Bulguları:${NC} $SMUGGLER_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/bfac_results/bfac_output.txt" ]; then
    echo -e "${BLUE}BFAC Bulguları:${NC} $BFAC_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/gochopchop_results/gochopchop_output.txt" ]; then
    echo -e "${BLUE}GoChopChop Bulguları:${NC} $GOCHOP_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/snallygaster_results/snallygaster_output.txt" ]; then
    echo -e "${BLUE}Snallygaster Bulguları:${NC} $SNALLY_FINDINGS"
fi

if [ -f "$VULN_SCAN_DIR/lazyhunter_results/lazyhunter_output.txt" ]; then
    echo -e "${BLUE}LazyHunter Bulguları:${NC} $LH_CVES"
fi

# Yeni eklenen araçlar
echo -e "${BLUE}CORScanner Bulguları:${NC} $CORS_VULNS"
echo -e "${BLUE}Arjun Parametre Keşfi:${NC} $PARAM_COUNT parametre"

# Toplam süre
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_TIME_FORMATTED=$(format_time $TOTAL_TIME)
echo -e "${BLUE}Toplam Süre:${NC} $TOTAL_TIME_FORMATTED"

# Sonuçları HTML rapora çevirmek için seçenek
echo -e "\n${YELLOW}[!] HTML rapor oluşturmak için: ./$0 --format-html $OUTPUT_DIR${NC}"

echo -e "\n${GREEN}###------- Zafiyet tarama tamamlandı: $DOMAIN -------###${NC}" 