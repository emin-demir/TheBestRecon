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

# Varsayılan değerler
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

# Output dizinini belirle
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="output/${DOMAIN}_$(date +%Y%m%d_%H%M%S)"
fi

# Vulnerability scan için dizin oluştur
VULN_SCAN_DIR="${OUTPUT_DIR}/vuln_scan"
mkdir -p "$VULN_SCAN_DIR"

echo -e "${BLUE}#==============================================================#${NC}"
echo -e "${BLUE}# ${GREEN}TheBestRecon - Kapsamlı Zafiyet Tarama${BLUE}                     #${NC}"
echo -e "${BLUE}#==============================================================#${NC}"
echo -e "${GREEN}[+] Hedef Domain: ${CYAN}$DOMAIN${NC}"
echo -e "${GREEN}[+] Tarama Modu: ${CYAN}$SCAN_MODE${NC}"
echo -e "${GREEN}[+] Çıktılar şu dizine kaydedilecek: ${CYAN}$VULN_SCAN_DIR${NC}"
echo

RESOLVER_FILE="$OUTPUT_DIR/../../config/resolvers.txt"
if [ ! -f "$RESOLVER_FILE" ]; then
    echo -e "${YELLOW}[!] Resolver dosyası ($RESOLVER_FILE) bulunamadı, oluşturuluyor...${NC}"
    wget -O "$RESOLVER_FILE" https://raw.githubusercontent.com/janmasarik/resolvers/master/resolvers.txt
fi

# Canlı subdomainler var mı kontrol et
LIVE_DOMAINS_FILE=""

# Tarama moduna göre URL listesini seç
TEMP_DIR="${OUTPUT_DIR}/temp"
mkdir -p "$TEMP_DIR"

# URL filtreleme modülünü çalıştır (eğer temp dizini yoksa)
if [ ! -f "$TEMP_DIR/short_urls.txt" ] || [ ! -f "$TEMP_DIR/medium_urls.txt" ]; then
    echo -e "${BLUE}[+] URL filtreleme modülü çalıştırılıyor...${NC}"
    bash "$OUTPUT_DIR/../../modules/filter_urls.sh" "$DOMAIN" -o "$OUTPUT_DIR"
fi

# Tarama moduna göre URL listesini seç
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
        ;;
esac

# Eğer hala LIVE_DOMAINS_FILE boşsa, varsayılan listeleri kontrol et
if [ -z "$LIVE_DOMAINS_FILE" ]; then
    if [ -f "$TEMP_DIR/all_urls.txt" ]; then
        LIVE_DOMAINS_FILE="$TEMP_DIR/all_urls.txt"
        echo -e "${BLUE}[+] Tüm URL'ler kullanılıyor${NC}"
    elif [ -f "$OUTPUT_DIR/subs_live/200-400-httpx-domains-clean.txt" ]; then
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
        echo "$DOMAIN" > "$VULN_SCAN_DIR/single_domain.txt"
        LIVE_DOMAINS_FILE="$VULN_SCAN_DIR/single_domain.txt"
    fi
fi

DOMAINS_COUNT=$(wc -l < "$LIVE_DOMAINS_FILE")
echo -e "${GREEN}[+] $DOMAINS_COUNT canlı domain üzerinde zafiyet taraması yapılacak${NC}"

# URL Listesi oluştur - doğrudan kopyalama yap
cp "$LIVE_DOMAINS_FILE" "$VULN_SCAN_DIR/domain_urls.txt"
URL_LIST="$VULN_SCAN_DIR/domain_urls.txt"
URLS_COUNT=$(wc -l < "$URL_LIST")
echo -e "${GREEN}[+] $URLS_COUNT URL üzerinde tarama yapılacak${NC}"

# IP listesini kontrol et
IP_FILE=""

# Tarama moduna göre temp dizinindeki IP listelerini kontrol et
if [ "$SCAN_MODE" = "short" ] && [ -f "$TEMP_DIR/short_ips.txt" ]; then
    IP_FILE="$TEMP_DIR/short_ips.txt"
    echo -e "${BLUE}[+] Short tarama modu için filtrelenmiş IP listesi kullanılıyor${NC}"
elif [ "$SCAN_MODE" = "medium" ] && [ -f "$TEMP_DIR/medium_ips.txt" ]; then
    IP_FILE="$TEMP_DIR/medium_ips.txt"
    echo -e "${BLUE}[+] Medium tarama modu için filtrelenmiş IP listesi kullanılıyor${NC}"
elif [ -f "$TEMP_DIR/all_ips.txt" ]; then
    IP_FILE="$TEMP_DIR/all_ips.txt"
    echo -e "${BLUE}[+] Tüm filtrelenmiş IP listesi kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_brute/dnsx_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_brute/dnsx_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_brute modülünden IP listesi kullanılıyor${NC}"
elif [ -f "$OUTPUT_DIR/subdomain_enum/dnsx_ips_${DOMAIN}.txt" ]; then
    IP_FILE="$OUTPUT_DIR/subdomain_enum/dnsx_ips_${DOMAIN}.txt"
    echo -e "${BLUE}[+] Subdomain_enum modülünden IP listesi kullanılıyor${NC}"
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
    echo -e "${CYAN}[*] Bu işlem uzun sürebilir${NC}"
    
    # Nuclei tarama başlangıç zamanı
    NUCLEI_START=$(date +%s)
    
    # İstenen parametrelerle nuclei çalıştır
    nuclei -l "$LIVE_DOMAINS_FILE" -uc -v -as -nc -r "$RESOLVER_FILE" -rate-limit 5 -o "$VULN_SCAN_DIR/nuclei_results.txt"
    
    # Nuclei tarama bitiş zamanı
    NUCLEI_END=$(date +%s)
    NUCLEI_TIME=$((NUCLEI_END - NUCLEI_START))
    NUCLEI_TIME_FORMATTED=$(format_time $NUCLEI_TIME)
    
    # Sonuçları şiddet seviyesine göre ayır
    if [ -f "$VULN_SCAN_DIR/nuclei_results.txt" ]; then
        # Kritik
        grep -i "\[critical\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_critical.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_critical.txt"
        CRIT_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_critical.txt" 2>/dev/null || echo 0)
        
        # Yüksek
        grep -i "\[high\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_high.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_high.txt"
        HIGH_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_high.txt" 2>/dev/null || echo 0)
        
        # Orta
        grep -i "\[medium\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_medium.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_medium.txt"
        MED_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_medium.txt" 2>/dev/null || echo 0)
        
        # Düşük
        grep -i "\[low\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_low.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_low.txt"
        LOW_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_low.txt" 2>/dev/null || echo 0)
        
        # Bilgi
        grep -i "\[info\]" "$VULN_SCAN_DIR/nuclei_results.txt" > "$VULN_SCAN_DIR/nuclei_info.txt" 2>/dev/null || touch "$VULN_SCAN_DIR/nuclei_info.txt"
        INFO_COUNT=$(wc -l < "$VULN_SCAN_DIR/nuclei_info.txt" 2>/dev/null || echo 0)
        
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

# 2. LazyHunter ile IP tabanlı zafiyet taraması
echo -e "\n${MAGENTA}#----- LazyHunter IP Tabanlı Zafiyet Taraması -----#${NC}"
if command -v lazyhunter &> /dev/null && [ -n "$IP_FILE" ]; then
    echo -e "${BLUE}[+] LazyHunter taraması başlatılıyor...${NC}"
    echo -e "${CYAN}[*] Bu işlem biraz zaman alabilir${NC}"
    
    # İstenen parametrelerle LazyHunter çalıştır
    lazyhunter -f "$IP_FILE" --cve+ports --host | tee "$VULN_SCAN_DIR/lazyhunter_vulns.txt"
    
    # CVE sayısını tespit et
    LH_CVES=$(grep -c "CVE-" "$VULN_SCAN_DIR/lazyhunter_vulns.txt" 2>/dev/null || echo 0)
    
    if [ $LH_CVES -gt 0 ]; then
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

# 3. HTTP Smuggler ile HTTP request smuggling taraması
echo -e "\n${MAGENTA}#----- HTTP Smuggler Taraması -----#${NC}"
if command -v smuggler &> /dev/null; then
    echo -e "${BLUE}[+] HTTP Smuggling zafiyeti taraması başlatılıyor...${NC}"
    
    # Her URL için smuggler çalıştır
    while read -r url; do
        # URL'den protokol kısmını çıkart (http:// veya https://)
        domain=$(echo "$url" | sed 's/^https\?:\/\///')
        echo -e "${CYAN}[*] Smuggler: $domain taranıyor...${NC}"
        smuggler -u "$domain" --no-color | tee -a "$VULN_SCAN_DIR/smuggler_vulns.txt"
    done < "$URL_LIST"
    
    SMUGGLER_VULNS=$(grep -c "Vulnerable" "$VULN_SCAN_DIR/smuggler_vulns.txt" 2>/dev/null || echo 0)
    
    if [ $SMUGGLER_VULNS -gt 0 ]; then
        echo -e "${GREEN}[+] HTTP Smuggling taraması tamamlandı: $SMUGGLER_VULNS potansiyel zafiyet bulundu${NC}"
    else
        echo -e "${GREEN}[+] HTTP Smuggling taraması tamamlandı: Zafiyet bulunamadı${NC}"
    fi
else
    echo -e "${RED}[-] smuggler bulunamadı${NC}"
fi

report_progress

# 4. GoChopChop ile zafiyetli endpoint taraması
echo -e "\n${MAGENTA}#----- GoChopChop Endpoint Taraması -----#${NC}"
if command -v chopchop &> /dev/null; then
    echo -e "${BLUE}[+] GoChopChop taraması başlatılıyor...${NC}"
    
    # ChopChop yapılandırma dosyası yolu
    CHOPCHOP_CONFIG="$OUTPUT_DIR/../../setup/ChopChop/chopchop.yml"
    
    if [ -f "$CHOPCHOP_CONFIG" ]; then
        echo -e "${GREEN}[+] ChopChop yapılandırma dosyası bulundu: $CHOPCHOP_CONFIG${NC}"
        
        # İstenen parametrelerle GoChopChop çalıştır (yapılandırma dosyası ile)
        chopchop scan -u "$URL_LIST" -k --threads 5 --config "$CHOPCHOP_CONFIG" --export-filename "$VULN_SCAN_DIR/chopchop_vulns.txt"
    else
        echo -e "${YELLOW}[!] ChopChop yapılandırma dosyası bulunamadı, indiriliyor...${NC}"
        
        # ChopChop yapılandırma dosyası dizinini kontrol et ve oluştur
        CONFIG_DIR=$(dirname "$CHOPCHOP_CONFIG")
        if [ ! -d "$CONFIG_DIR" ]; then
            mkdir -p "$CONFIG_DIR"
        fi
        
        # GitHub'dan chopchop.yml dosyasını indir
        if wget -q "https://raw.githubusercontent.com/michelin/ChopChop/refs/heads/master/chopchop.yml" -O "$CHOPCHOP_CONFIG"; then
            echo -e "${GREEN}[+] ChopChop yapılandırma dosyası başarıyla indirildi: $CHOPCHOP_CONFIG${NC}"
            
            # İndirilen yapılandırma dosyası ile GoChopChop çalıştır
            chopchop scan -u "$URL_LIST" -k --threads 5 --config "$CHOPCHOP_CONFIG" --export-filename "$VULN_SCAN_DIR/chopchop_vulns.txt"
        else
            echo -e "${RED}[-] ChopChop yapılandırma dosyası indirilemedi, varsayılan yapılandırma kullanılıyor${NC}"
            
            # Varsayılan yapılandırma ile GoChopChop çalıştır
            chopchop scan -u "$URL_LIST" -k --threads 5 --export-filename "$VULN_SCAN_DIR/chopchop_vulns.txt"
        fi
    fi
    
    if [ -f "$VULN_SCAN_DIR/chopchop_vulns.txt" ]; then
        GOCHOP_VULNS=$(grep -c "Vulnerable" "$VULN_SCAN_DIR/chopchop_vulns.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] GoChopChop taraması tamamlandı: $GOCHOP_VULNS zafiyetli endpoint bulundu${NC}"
    else
        echo -e "${GREEN}[+] GoChopChop taraması tamamlandı: Sonuç dosyası oluşturulamadı${NC}"
        GOCHOP_VULNS=0
    fi
else
    echo -e "${RED}[-] chopchop bulunamadı${NC}"
    GOCHOP_VULNS=0
fi

report_progress

# 5. Snallygaster ile gizli dosya taraması
echo -e "\n${MAGENTA}#----- Snallygaster Gizli Dosya Taraması -----#${NC}"
if command -v snallygaster &> /dev/null; then
    echo -e "${BLUE}[+] Snallygaster taraması başlatılıyor...${NC}"
    
    # Sadece domain isimlerini al (URL olmadan)
    cat "$LIVE_DOMAINS_FILE" > "$VULN_SCAN_DIR/snallygaster_domains.txt"
    
    # İstenen parametrelerle snallygaster çalıştır
    snallygaster --nohttp --json "$VULN_SCAN_DIR/snallygaster_domains.txt" > "$VULN_SCAN_DIR/snallygaster_json.txt" 2>/dev/null
    
    # Daha okunabilir format için JSON'dan metin çıktıya dönüştür
    if [ -f "$VULN_SCAN_DIR/snallygaster_json.txt" ]; then
        grep -o '"url":"[^"]*"' "$VULN_SCAN_DIR/snallygaster_json.txt" | \
        sed 's/"url":"//g' | sed 's/"//g' > "$VULN_SCAN_DIR/snallygaster_findings.txt"
        
        SNALLY_FINDINGS=$(wc -l < "$VULN_SCAN_DIR/snallygaster_findings.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] Snallygaster taraması tamamlandı: $SNALLY_FINDINGS potansiyel bulgu${NC}"
    else
        echo -e "${GREEN}[+] Snallygaster taraması tamamlandı: Gizli dosya bulunamadı${NC}"
        SNALLY_FINDINGS=0
    fi
else
    echo -e "${RED}[-] snallygaster bulunamadı${NC}"
    SNALLY_FINDINGS=0
fi

report_progress

# 6. BFAC ile backup file taraması
echo -e "\n${MAGENTA}#----- Backup File Access Checker (BFAC) Taraması -----#${NC}"
if command -v bfac &> /dev/null; then
    echo -e "${BLUE}[+] BFAC taraması başlatılıyor...${NC}"
    
    # İstenen parametrelerle BFAC çalıştır
    bfac --list "$LIVE_DOMAINS_FILE" \
         --threads 5 \
         --request-rate-throttling 10 \
         -ra \
         -o "$VULN_SCAN_DIR/bfac_vulns.txt"
    
    if [ -f "$VULN_SCAN_DIR/bfac_vulns.txt" ]; then
        BFAC_VULNS=$(grep -c "FOUND" "$VULN_SCAN_DIR/bfac_vulns.txt" 2>/dev/null || echo 0)
        echo -e "${GREEN}[+] BFAC taraması tamamlandı: $BFAC_VULNS potansiyel erişilebilir yedek dosya bulundu${NC}"
    else
        echo -e "${GREEN}[+] BFAC taraması tamamlandı: Erişilebilir yedek dosya bulunamadı${NC}"
        BFAC_VULNS=0
    fi
else
    echo -e "${RED}[-] bfac bulunamadı${NC}"
    BFAC_VULNS=0
fi

report_progress

# Özet rapor oluştur
echo -e "\n${MAGENTA}#============ Zafiyet Tarama Özeti ============#${NC}"
echo -e "${BLUE}Hedef:${NC} $DOMAIN"
echo -e "${BLUE}Taranan Subdomain Sayısı:${NC} $DOMAINS_COUNT"

# Nuclei sonuçları
if [ -f "$VULN_SCAN_DIR/nuclei_results.txt" ]; then
    NUCLEI_TOTAL=$(wc -l < "$VULN_SCAN_DIR/nuclei_results.txt" 2>/dev/null || echo 0)
    echo -e "${BLUE}Nuclei Bulguları:${NC} $NUCLEI_TOTAL"
    if [ $CRIT_COUNT -gt 0 ]; then echo -e "  ${RED}Kritik:${NC} $CRIT_COUNT"; fi
    if [ $HIGH_COUNT -gt 0 ]; then echo -e "  ${MAGENTA}Yüksek:${NC} $HIGH_COUNT"; fi
    if [ $MED_COUNT -gt 0 ]; then echo -e "  ${YELLOW}Orta:${NC} $MED_COUNT"; fi
    if [ $LOW_COUNT -gt 0 ]; then echo -e "  ${BLUE}Düşük:${NC} $LOW_COUNT"; fi
    if [ $INFO_COUNT -gt 0 ]; then echo -e "  ${CYAN}Bilgi:${NC} $INFO_COUNT"; fi
fi

# Diğer araçların bulguları
if [ -f "$VULN_SCAN_DIR/lazyhunter_vulns.txt" ]; then
    echo -e "${BLUE}LazyHunter Bulguları:${NC} $LH_CVES"
fi

if [ -f "$VULN_SCAN_DIR/smuggler_vulns.txt" ]; then
    echo -e "${BLUE}HTTP Smuggling Bulguları:${NC} $SMUGGLER_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/chopchop_vulns.txt" ]; then
    echo -e "${BLUE}GoChopChop Bulguları:${NC} $GOCHOP_VULNS"
fi

if [ -f "$VULN_SCAN_DIR/snallygaster_findings.txt" ]; then
    echo -e "${BLUE}Snallygaster Bulguları:${NC} $SNALLY_FINDINGS"
fi

if [ -f "$VULN_SCAN_DIR/bfac_vulns.txt" ]; then
    echo -e "${BLUE}BFAC Bulguları:${NC} $BFAC_VULNS"
fi

# Toplam süre
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
TOTAL_TIME_FORMATTED=$(format_time $TOTAL_TIME)
echo -e "${BLUE}Toplam Süre:${NC} $TOTAL_TIME_FORMATTED"

echo -e "\n${GREEN}###------- Zafiyet tarama tamamlandı: $DOMAIN -------###${NC}" 