#!/bin/bash

# TheBestRecon - Kapsamlı Recon Aracı
# Tüm modülleri kontrol eden ana betik

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "  _______ _          ____            _   _____                      "
echo " |__   __| |        |  _ \          | | |  __ \                     "
echo "    | |  | |__   ___| |_) | ___  ___| |_| |__) |___  ___ ___  _ __  "
echo "    | |  | '_ \ / _ \  _ < / _ \/ __| __|  _  // _ \/ __/ _ \| '_ \ "
echo "    | |  | | | |  __/ |_) |  __/\__ \ |_| | \ \  __/ (_| (_) | | | |"
echo "    |_|  |_| |_|\___|____/ \___||___/\__|_|  \_\___|\___\___/|_| |_|"
echo -e "${NC}"
echo -e "${YELLOW}Kapsamlı Recon Aracı${NC}"
echo -e "${YELLOW}------------------------------------------${NC}"
echo ""

# Loglama fonksiyonu
log() {
    local log_level=$1
    local message=$2
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    # Ekrana yazdır
    case $log_level in
        "INFO")
            echo -e "${BLUE}[+] ${message}${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[+] ${message}${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}[!] ${message}${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[-] ${message}${NC}"
            ;;
    esac
    
    # Log dosyasına yaz
    mkdir -p logs
    echo "[$timestamp] [$log_level] $message" >> "logs/recon_$(date +%Y%m%d).log"
}

# Fonksiyonlar
show_help() {
    echo -e "${YELLOW}TheBestRecon - Kapsamlı Recon Aracı${NC}"
    echo ""
    echo -e "Kullanım: ${CYAN}$0 [seçenekler]${NC}"
    echo ""
    echo -e "${BLUE}Seçenekler:${NC}"
    echo -e "  ${GREEN}-d, --domain${NC} <domain>        Hedef domain (zorunlu, birden fazla belirtilebilir fakat tavsiye edilmez.)"
    echo -e "  ${GREEN}-o, --output${NC} <dizin>         Çıktı dizini (varsayılan: output/)"
    echo -e "  ${GREEN}-h, --help${NC}                   Kullanım talimatları (Help Menüsü)"
    echo -e "  ${GREEN}-a, --api-config${NC} <dosya>     API anahtarları için yapılandırma dosyası"
    echo ""
    echo -e "${BLUE}Tarama Modları:${NC}"
    echo -e "  ${MAGENTA}--short-scan${NC}               Kısa tarama - Sadece kritik öneme sahip 10 subdomaini tarar"
    echo -e "  ${MAGENTA}--medium-scan${NC}              Orta tarama - 30-50 önemli subdomaini tarar"
    echo -e "  ${MAGENTA}--big-scan${NC}                 Büyük tarama - Tüm subdomainleri tarar (varsayılan)"
    echo ""
    echo -e "${BLUE}Modüller:${NC}"
    echo -e "  ${CYAN}--all-modules, -all${NC}          Tüm modülleri çalıştır"
    echo -e "  ${CYAN}--sub-enum, -sE${NC}              Subdomain enumeration çalıştır (assetfinder, subfinder, sublist3r, vb)"
    echo -e "  ${CYAN}--sub-brute, -sB${NC}             Subdomain bruteforce çalıştır (gobuster, amass)"
    echo -e "  ${CYAN}--subs-live, -sL${NC}             Canlı subdomain kontrolü çalıştır (httpx, httprobe)"
    echo -e "  ${CYAN}--screen-shoot, -sS${NC}          Ekran görüntüsü al (aquatone)"
    echo -e "  ${CYAN}--url-discovery, -uD${NC}         URL Keşfi çalıştır (gau, waymore, katana, feroxbuster vb.)"
    echo -e "  ${CYAN}--js-discovery, -jD${NC}          JavaScript dosyalarını keşfet (subjs, getJS, Secretfinder)"
    echo -e "  ${CYAN}--param-discovery, -pD${NC}       Parametre keşfi çalıştır (ParamSpider, Arjun)"
    echo -e "  ${CYAN}--js-analysis, -jS${NC}           JavaScript dosyalarında değerli veriler aranır. (TruffleHog, Linkfinder, Grep)"
    echo -e "  ${CYAN}--param-analysis, -pmS${NC}        Parametreler üzerinde XSS zafiyet tespiti yapar (KXSS, Dalfox, XSStrike)"
    echo -e "  ${CYAN}--port-scan, -pS${NC}             Port tarama çalıştır (nmap, masscan, naabu)"
    echo -e "  ${CYAN}--vuln-scan, -vS${NC}             Zafiyet tarama çalıştır (nuclei, corscanner, smuggler, bfac)"
    echo ""
    echo -e "${YELLOW}Örnekler:${NC}"
    echo -e "  ${CYAN}$0 -d example.com -sE -pS${NC}"
    echo -e "  ${CYAN}$0 -d example.com --short-scan -all ${NC}"
    echo -e "  ${CYAN}$0 -d example.com --medium-scan -vS ${NC}"
    echo -e "  ${CYAN}$0 -d example.com -d example2.com -all ${NC}"
    echo -e "  ${CYAN}$0 -d example.com -all -a api_keys.txt ${NC}"
    echo -e "  ${CYAN}$0 -d example.com -sE -sL -sS -uD -jD -pD${NC}"
    exit 0
}


# Değişkenler
DOMAINS=()
OUTPUT_DIR="output"
# Sabit API config dosyası
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_CONFIG="$SCRIPT_DIR/config/config.json"
SUB_ENUM=false
SUB_BRUTE=false
PORT_SCAN=false
VULN_SCAN=false
JS_ANALYSIS=false
PARAM_ANALYSIS=false
SUBS_LIVE=false
SCREEN_SHOOT=false
URL_DISCOVERY=false
JS_DISCOVERY=false
PARAM_DISCOVERY=false
ALL_MODULES=false
# Tarama modunu belirle (varsayılan: big)
SCAN_MODE="big"

# Parametre kontrolü
if [[ $# -eq 0 ]]; then
    show_help
fi

# Ana dizin kontrolü
if [[ ! -d "modules" ]]; then
    log "ERROR" "'modules' dizini bulunamadı"
    log "ERROR" "Bu betiği TheBestRecon ana dizininde çalıştırın"
    exit 1
fi

# Parametreleri işle
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -d|--domain)
            DOMAINS+=("$2")
            shift
            shift
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift
            shift
            ;;
        -a|--api-config)
            # API_CONFIG parametresi artık kullanılmıyor, sabit değer kullanılıyor
            log "WARNING" "-a parametresi göz ardı ediliyor. Sabit API config dosyası kullanılıyor: $API_CONFIG"
            shift
            shift
            ;;
        -h|--help)
            show_help
            ;;
        --short-scan)
            SCAN_MODE="short"
            shift
            ;;
        --medium-scan)
            SCAN_MODE="medium"
            shift
            ;;
        --big-scan)
            SCAN_MODE="big"
            shift
            ;;
        --sub-enum|-sE)
            SUB_ENUM=true
            shift
            ;;
        --sub-brute|-sB)
            SUB_BRUTE=true
            shift
            ;;
        --port-scan|-pS)
            PORT_SCAN=true
            shift
            ;;
        --vuln-scan|-vS)
            VULN_SCAN=true
            shift
            ;;
        --js-analysis|-jS)
            JS_ANALYSIS=true
            shift
            ;;
        --param-analysis|-pmS)
            PARAM_ANALYSIS=true
            shift
            ;;
        --subs-live|-sL)
            SUBS_LIVE=true
            shift
            ;;
        --screen-shoot|-sS)
            SCREEN_SHOOT=true
            shift
            ;;
        --url-discovery|-uD)
            URL_DISCOVERY=true
            shift
            ;;
        --js-discovery|-jD)
            JS_DISCOVERY=true
            shift
            ;;
        --param-discovery|-pD)
            PARAM_DISCOVERY=true
            shift
            ;;
        --all-modules|-all)
            ALL_MODULES=true
            shift
            ;;
        *)
            log "ERROR" "Bilinmeyen parametre: $1"
            show_help
            ;;
    esac
done

# Domain parametresi kontrolü
if [[ ${#DOMAINS[@]} -eq 0 ]]; then
    log "ERROR" "En az bir domain parametresi gerekli"
    show_help
fi

# Tüm modüller seçilmişse
if $ALL_MODULES; then
    SUB_ENUM=true
    SUB_BRUTE=true
    PORT_SCAN=true
    VULN_SCAN=true
    JS_ANALYSIS=true
    PARAM_ANALYSIS=true
    SUBS_LIVE=true
    SCREEN_SHOOT=true
    URL_DISCOVERY=true
    JS_DISCOVERY=true
    PARAM_DISCOVERY=true
fi

# Output dizinini hazırla
mkdir -p "$OUTPUT_DIR"

# Python sanal ortamını aktif et
VENV_PATH="$SCRIPT_DIR/venv"
VENV_ACTIVATE="$VENV_PATH/bin/activate"

# Sanal ortam kontrolü ve aktivasyonu
if [ -d "$VENV_PATH" ] && [ -f "$VENV_ACTIVATE" ]; then
    echo -e "\033[0;34m[+] Python sanal ortamı aktif ediliyor...\033[0m"
    source "$VENV_ACTIVATE"
    echo -e "\033[0;32m[+] Python sanal ortamı aktif edildi\033[0m"
else
    echo -e "\033[0;31m[-] Python sanal ortamı bulunamadı: $VENV_ACTIVATE\033[0m"
    echo -e "\033[0;33m[!] Lütfen önce install_tools.sh çalıştırarak gerekli ortamı kurun.\033[0m"
fi

# Seçilen tarama modunu ekrana yazdır
case $SCAN_MODE in
    "short")
        log "INFO" "Kısa tarama modu seçildi - Sadece kritik öneme sahip subdomainler taranacak"
        ;;
    "medium")
        log "INFO" "Orta tarama modu seçildi - Önemli subdomainler taranacak"
        ;;
    "big")
        log "INFO" "Büyük tarama modu seçildi - Tüm subdomainler taranacak"
        ;;
esac

# Her domain için işlemleri sırayla çalıştır
for domain in "${DOMAINS[@]}"; do
    log "INFO" " Hedef domain işleniyor: $domain "
    # Zaman damgasını sadece tarih olarak değiştir (GG-AA-YYYY formatında)
    datestamp=$(date +%d-%m-%Y)
    domain_output_dir="${OUTPUT_DIR}/${domain}_${datestamp}"
    mkdir -p "$domain_output_dir"
    
    log "INFO" " Sonuçlar şu dizine kaydedilecek: $domain_output_dir "
    
    # 1. Subdomain Enumeration
    if $SUB_ENUM; then
        # Eğer SUB_BRUTE aktifse, subdomain_enum içindeki dnsx'i atla
        SKIP_DNSX_PARAM=""
        if $SUB_BRUTE; then
            SKIP_DNSX_PARAM="--skip-dnsx"
        fi
        
        bash modules/subdomain_enum.sh "$domain" -a "$API_CONFIG" -o "$domain_output_dir" $SKIP_DNSX_PARAM
    fi
    
    # 2. Subdomain Bruteforce - DNS Bruteforce dahil
    if $SUB_BRUTE; then
        bash modules/subdomain_brute.sh "$domain" -o "$domain_output_dir"
    fi
    
    # 3. Subdomain Live Check ve Screenshot
    if $SUBS_LIVE || $SCREEN_SHOOT; then
        LIVE_PARAM=""
        SCREENSHOT_PARAM=""
        
        if $SUBS_LIVE; then
            LIVE_PARAM="-l"
        fi
        
        if $SCREEN_SHOOT; then
            SCREENSHOT_PARAM="-s"
        fi
        
        bash modules/live_and_screenshot.sh "$domain" -o "$domain_output_dir" $LIVE_PARAM $SCREENSHOT_PARAM
    fi
    
    # Subdomain taraması yapılmış mı kontrol et
    SUBDOMAIN_SCANNED=false
    if $SUB_ENUM || $SUB_BRUTE || $SUBS_LIVE; then
        SUBDOMAIN_SCANNED=true
    fi
    
    # Diğer modüller çalıştırılacak mı kontrol et
    NEED_URL_FILTERING=false
    if $VULN_SCAN || $URL_DISCOVERY || $JS_DISCOVERY || $PARAM_DISCOVERY; then
        NEED_URL_FILTERING=true
    fi
    
    # Subdomain taraması ve diğer modüller çalıştırılacaksa, URL filtreleme modülünü çalıştır
    if $SUBDOMAIN_SCANNED || $NEED_URL_FILTERING; then
        log "INFO" "Subdomain taraması yapıldı ve gerekli modüller çalıştırılacak - URL filtreleme modülü çalıştırılıyor"
        bash modules/filter_urls.sh "$domain" -o "$domain_output_dir"
    fi
    
    # 4. URL Discovery
    if $URL_DISCOVERY; then
        bash modules/url_discovery.sh "$domain" -o "$domain_output_dir" --scan-mode "$SCAN_MODE"
    fi
    
    # 5. JavaScript ve Parameter Discovery
    if $JS_DISCOVERY || $PARAM_DISCOVERY; then
        JS_FLAG=""
        PARAM_FLAG=""
        
        if $JS_DISCOVERY; then
            JS_FLAG="-js"
        fi
        
        if $PARAM_DISCOVERY; then
            PARAM_FLAG="-p"
        fi
        
        bash modules/js_and_param_discovery.sh "$domain" -o "$domain_output_dir" $JS_FLAG $PARAM_FLAG --scan-mode "$SCAN_MODE"
    fi
    
    # 6. Port Scanning
    if $PORT_SCAN; then
        bash modules/port_scan.sh "$domain" -o "$domain_output_dir" --scan-mode "$SCAN_MODE"
    fi
    
    # 7. JavaScript Analysis
    if $JS_ANALYSIS; then
        bash modules/js_analysis.sh "$domain" -o "$domain_output_dir"
    fi
    
    # 8. Parameter Analysis
    if $PARAM_ANALYSIS; then
        bash modules/param_analysis.sh "$domain" -o "$domain_output_dir" 
    fi

    # 9. Vulnerability Scanning
    if $VULN_SCAN; then
        bash modules/vuln_scan.sh "$domain" -o "$domain_output_dir" --scan-mode "$SCAN_MODE"
    fi
done

log "SUCCESS" "###------- TheBestRecon tamamlandı. Sonuçlar: $OUTPUT_DIR -------###" 
