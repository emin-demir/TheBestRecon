#!/bin/bash

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
# Exit on error
set -e

# Başlangıç zamanını kaydet
START_TIME=$(date +%s)

# Renk tanımlamaları
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Python sanal ortam dizini
VENV_DIR="$SCRIPT_DIR/venv"

# Check for root privileges
echo -e "${BLUE}[+] Checking for root privileges...${NC}"
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[-] This script must be run as root!${NC}"
   exit 1
fi

# Update package lists
echo -e "${BLUE}[+] Updating package lists...${NC}"
apt-get update
echo -e "${GREEN}[+] Package lists updated successfully${NC}"

# Setup klasörü kontrolü
if [ -d "$SCRIPT_DIR/setup" ]; then
    read -p "${RED}[?] 'setup' klasörü zaten mevcut. Silinsin mi? [Y/n] ${NC}" response
    response=${response:-Y}  # Varsayılan değer Y
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}[+] 'setup' klasörü siliniyor...${NC}"
        rm -rf "$SCRIPT_DIR/setup"
    else
        echo -e "${YELLOW}[!] İşlem iptal edildi. Kuruluma devam ediliyor...${NC}"
    fi
fi

# Check for required dependencies
echo -e "${BLUE}[+] Checking for required dependencies...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${BLUE}[+] Installing Python3...${NC}"
    apt-get install -y python3 python3-pip python3-venv
else
    apt-get install -y python3-venv
    echo -e "${GREEN}[+] Python3 already installed${NC}"
    # Python3-venv'in yüklü olduğundan emin olalım
fi

# Python sanal ortamı kurulumu
if [ ! -d "$VENV_DIR" ]; then
    echo -e "${BLUE}[+] Setting up Python virtual environment...${NC}"
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}[+] Python virtual environment created at $VENV_DIR${NC}"
else
    echo -e "${GREEN}[+] Python virtual environment already exists at $VENV_DIR${NC}"
fi

# Sanal ortamı aktive et (shell script içinde source kullanılamaz, bu yüzden . operatörünü kullanıyoruz)
echo -e "${BLUE}[+] Activating Python virtual environment...${NC}"
. "$VENV_DIR/bin/activate"
echo -e "${GREEN}[+] Python virtual environment activated${NC}"

# pip güncelleme
echo -e "${BLUE}[+] Updating pip in virtual environment...${NC}"
python -m pip install --upgrade pip
echo -e "${GREEN}[+] pip updated successfully${NC}"

# pipx kurulumu
if ! command -v pipx &> /dev/null; then
    echo -e "${BLUE}[+] Installing pipx...${NC}"
    python -m pip install pipx
    echo -e "${GREEN}[+] pipx installed successfully${NC}"
    
    # pipx path'i ayarla
    echo -e "${BLUE}[+] Setting up pipx path...${NC}"
    pipx ensurepath
    echo -e "${GREEN}[+] pipx path setup completed${NC}"
else
    echo -e "${GREEN}[+] pipx is already installed${NC}"
    # Path'in doğru ayarlandığından emin ol
    pipx ensurepath
fi

# pipx kullanabilmek için PATH'i güncelleyelim
export PATH="$HOME/.local/bin:$PATH"
# httpx ile python httpx karışmaması için python environmentinde olan kaldıralım.
pip uninstall -y httpx 

if ! command -v go &> /dev/null; then
    echo -e "${BLUE}[+] Installing Go...${NC}"
    apt install -y golang
    echo -e "${BLUE}[+] Adding Go to PATH...${NC}"
    
    # Go PATH'i ekle
    if ! grep -q "/usr/local/go/bin" ~/.bashrc; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        echo 'export PATH=$PATH:~/go/bin' >> ~/.bashrc
    fi
    
    if ! grep -q "/usr/local/go/bin" ~/.zshrc 2>/dev/null; then
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.zshrc 2>/dev/null || true
        echo 'export PATH=$PATH:~/go/bin' >> ~/.zshrc 2>/dev/null || true
    fi
    
    # Geçici olarak PATH'e ekle
    export PATH=$PATH:/usr/local/go/bin
    export PATH=$PATH:~/go/bin
    
    echo -e "${GREEN}[+] Go $GO_VERSION installed successfully${NC}"
    echo -e "${BLUE}[+] Verifying Go installation...${NC}"
    if go version; then
        echo -e "${GREEN}[+] Go installation verified${NC}"
    else
        echo -e "${RED}[-] Go installation could not be verified${NC}"
        failed_tools+=("Go")
    fi
else
    echo -e "${GREEN}[+] Go is already installed${NC}"
fi

# Check for Ruby
if ! command -v ruby &> /dev/null; then
    echo -e "${BLUE}[+] Installing Ruby...${NC}"
    apt-get install -y ruby
else
    echo -e "${GREEN}[+] Ruby is already installed${NC}"
fi

# Create setup directory for GitHub repositories in the same directory as the script
echo -e "${BLUE}[+] Creating setup directory for GitHub repositories...${NC}"
mkdir -p "$SCRIPT_DIR/setup"

# Create array to track installation failures
declare -a failed_tools


# Install aria2 for JavaScript downloads
echo -e "${BLUE}[+] Checking aria2...${NC}"
if ! command -v aria2c &> /dev/null; then
    echo -e "${BLUE}[+] Installing aria2...${NC}"
    sudo apt install -y aria2
else
    echo -e "${GREEN}[+] aria2 is already installed${NC}"
fi

# Install Go tools
echo -e "${BLUE}[+] Installing Go tools...${NC}"
# github-subdomains - GitHub subdomain finder
if go install github.com/gwen001/github-subdomains@latest &> /dev/null; then
    echo -e "${GREEN}[+] github-subdomains installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing github-subdomains...${NC}"
    if go install github.com/gwen001/github-subdomains@latest; then
        echo -e "${GREEN}[+] github-subdomains installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install github-subdomains${NC}"
        failed_tools+=("github-subdomains")
    fi
fi

# getjs - JavaScript file finder
if go install github.com/003random/getJS/v2@latest &> /dev/null; then
    echo -e "${GREEN}[+] getjs installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing getjs...${NC}"
    if go install github.com/003random/getJS/v2@latest; then
        echo -e "${GREEN}[+] getjs installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install getjs${NC}"
        failed_tools+=("getjs")
    fi
fi

# ChopChop - API security scanner
if command -v chopchop &> /dev/null; then
    echo -e "${GREEN}[+] ChopChop is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing ChopChop...${NC}"
    if [ -d "$SCRIPT_DIR/setup/ChopChop" ]; then
        echo -e "${YELLOW}[!] ChopChop directory exists, building from existing source...${NC}"
        cd "$SCRIPT_DIR/setup/ChopChop" && \
        go mod download && \
        go build . && \
        chmod +x gochopchop && \
        mv ./gochopchop /root/go/bin/chopchop && \
        cd - > /dev/null
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[+] ChopChop installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to build ChopChop${NC}"
            failed_tools+=("ChopChop")
        fi
    else
        if git clone https://github.com/michelin/ChopChop.git "$SCRIPT_DIR/setup/ChopChop" && \
           cd "$SCRIPT_DIR/setup/ChopChop" && \
           go mod download && \
           go build . && \
           chmod +x gochopchop && \
           mv ./gochopchop /root/go/bin/chopchop && \
           cd - > /dev/null; then
            echo -e "${GREEN}[+] ChopChop installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install ChopChop${NC}"
            failed_tools+=("ChopChop")
        fi
    fi
fi

# Dalfox - XSS scanner
if go install github.com/hahwul/dalfox/v2@latest &> /dev/null; then
    echo -e "${GREEN}[+] Dalfox installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing Dalfox...${NC}"
    if go install github.com/hahwul/dalfox/v2@latest; then
        echo -e "${GREEN}[+] Dalfox installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Dalfox${NC}"
        failed_tools+=("Dalfox")
    fi
fi

# GAU - URL fetcher
if go install github.com/lc/gau/v2/cmd/gau@latest &> /dev/null; then
    echo -e "${GREEN}[+] GAU installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing GAU...${NC}"
    if go install github.com/lc/gau/v2/cmd/gau@latest; then
        echo -e "${GREEN}[+] GAU installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install GAU${NC}"
        failed_tools+=("GAU")
    fi
fi

# Brutespray - Service bruteforcer
if go install github.com/x90skysn3k/brutespray@latest &> /dev/null; then
    echo -e "${GREEN}[+] Brutespray installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing Brutespray...${NC}"
    if go install github.com/x90skysn3k/brutespray@latest; then
        echo -e "${GREEN}[+] Brutespray installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Brutespray${NC}"
        failed_tools+=("Brutespray")
    fi
fi

# httpx - HTTP toolkit
if go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest &> /dev/null; then
    echo -e "${GREEN}[+] httpx installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing httpx...${NC}"
    if go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest; then
        echo -e "${GREEN}[+] httpx installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install httpx${NC}"
        failed_tools+=("httpx")
    fi
fi

# nuclei - Vulnerability scanner
if go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest &> /dev/null; then
    echo -e "${GREEN}[+] nuclei installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing nuclei...${NC}"
    if go install -v github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest; then
        echo -e "${GREEN}[+] nuclei installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install nuclei${NC}"
        failed_tools+=("nuclei")
    fi
fi

# subfinder - Subdomain discovery tool
if go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest &> /dev/null; then
    echo -e "${GREEN}[+] subfinder installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing subfinder...${NC}"
    if go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest; then
        echo -e "${GREEN}[+] subfinder installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install subfinder${NC}"
        failed_tools+=("subfinder")
    fi
fi

# gospider - Web spider
if go install github.com/jaeles-project/gospider@latest &> /dev/null; then
    echo -e "${GREEN}[+] gospider installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing gospider...${NC}"
    if go install github.com/jaeles-project/gospider@latest; then
        echo -e "${GREEN}[+] gospider installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install gospider${NC}"
        failed_tools+=("gospider")
    fi
fi

# ffuf - Web fuzzer
if go install github.com/ffuf/ffuf/v2@latest &> /dev/null; then
    echo -e "${GREEN}[+] ffuf installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing ffuf...${NC}"
    if go install github.com/ffuf/ffuf/v2@latest; then
        echo -e "${GREEN}[+] ffuf installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install ffuf${NC}"
        failed_tools+=("ffuf")
    fi
fi

# hakrawler - Web crawler
if go install github.com/hakluke/hakrawler@latest &> /dev/null; then
    echo -e "${GREEN}[+] hakrawler installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing hakrawler...${NC}"
    if go install github.com/hakluke/hakrawler@latest; then
        echo -e "${GREEN}[+] hakrawler installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install hakrawler${NC}"
        failed_tools+=("hakrawler")
    fi
fi

# assetfinder - Subdomain finder
if go install -v github.com/tomnomnom/assetfinder@latest &> /dev/null; then
    echo -e "${GREEN}[+] assetfinder installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing assetfinder...${NC}"
    if go install -v github.com/tomnomnom/assetfinder@latest; then
        echo -e "${GREEN}[+] assetfinder installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install assetfinder${NC}"
        failed_tools+=("assetfinder")
    fi
fi

# chaos - Subdomain discovery
if go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest &> /dev/null; then
    echo -e "${GREEN}[+] chaos installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing chaos...${NC}"
    if go install -v github.com/projectdiscovery/chaos-client/cmd/chaos@latest; then
        echo -e "${GREEN}[+] chaos installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install chaos${NC}"
        failed_tools+=("chaos")
    fi
fi

# DnsX - DNS toolkit
if go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest &> /dev/null; then
    echo -e "${GREEN}[+] DnsX installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing DnsX...${NC}"
    if go install -v github.com/projectdiscovery/dnsx/cmd/dnsx@latest; then
        echo -e "${GREEN}[+] DnsX installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install DnsX${NC}"
        failed_tools+=("DnsX")
    fi
fi

# shuffledns - Subdomain bruteforcer
if go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest &> /dev/null; then
    echo -e "${GREEN}[+] shuffledns installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing shuffledns...${NC}"
    if go install -v github.com/projectdiscovery/shuffledns/cmd/shuffledns@latest; then
        echo -e "${GREEN}[+] shuffledns installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install shuffledns${NC}"
        failed_tools+=("shuffledns")
    fi
fi

# httprobe - HTTP probe
if go install github.com/tomnomnom/httprobe@latest &> /dev/null; then
    echo -e "${GREEN}[+] httprobe installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing httprobe...${NC}"
    if go install github.com/tomnomnom/httprobe@latest; then
        echo -e "${GREEN}[+] httprobe installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install httprobe${NC}"
        failed_tools+=("httprobe")
    fi
fi

# fuzzuli - Fuzzing tool
if go install -v github.com/musana/fuzzuli@latest &> /dev/null; then
    echo -e "${GREEN}[+] fuzzuli installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing fuzzuli...${NC}"
    if go install -v github.com/musana/fuzzuli@latest; then
        echo -e "${GREEN}[+] fuzzuli installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install fuzzuli${NC}"
        failed_tools+=("fuzzuli")
    fi
fi

# katana - Web crawler
if go install github.com/projectdiscovery/katana/cmd/katana@latest &> /dev/null; then
    echo -e "${GREEN}[+] katana installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing katana...${NC}"
    if go install github.com/projectdiscovery/katana/cmd/katana@latest; then
        echo -e "${GREEN}[+] katana installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install katana${NC}"
        failed_tools+=("katana")
    fi
fi

# subjs - JavaScript files discovery
if go install -v github.com/lc/subjs@latest &> /dev/null; then
    echo -e "${GREEN}[+] subjs installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing subjs...${NC}"
    if go install -v github.com/lc/subjs@latest; then
        echo -e "${GREEN}[+] subjs installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install subjs${NC}"
        failed_tools+=("subjs")
    fi
fi

# brutespray - Service bruteforcer (if not already installed)
if ! command -v brutespray &> /dev/null; then
    echo -e "${BLUE}[+] Installing brutespray...${NC}"
    if go install github.com/x90skysn3k/brutespray@latest ; then
        echo -e "${GREEN}[+] brutespray installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install brutespray${NC}"
        failed_tools+=("brutespray")
    fi
else
    echo -e "${GREEN}[+] brutespray is already installed${NC}"
fi

# kxss - XSS scanner
if go install github.com/Emoe/kxss@latest &> /dev/null; then
    echo -e "${GREEN}[+] kxss installed successfully${NC}"
else
    echo -e "${BLUE}[+] Installing kxss...${NC}"
    if go install github.com/Emoe/kxss@latest; then
        echo -e "${GREEN}[+] kxss installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install kxss${NC}"
        failed_tools+=("kxss")
    fi
fi

# gf - Pattern finder (doğrudan GitHub'dan klonlayarak)
echo -e "${BLUE}[+] Installing gf...${NC}"

# gf binary kontrolü
GF_INSTALLED=false
if command -v gf &> /dev/null; then
    echo -e "${GREEN}[+] gf is already installed${NC}"
    GF_INSTALLED=true
else
    echo -e "${BLUE}[+] gf binary not found, will install${NC}"
fi

# ~/.gf dizini kontrolü
GF_DIR_EXISTS=false
if [ -d ~/.gf ] && [ "$(ls -A ~/.gf 2>/dev/null)" ]; then
    echo -e "${GREEN}[+] ~/.gf directory already exists and has content${NC}"
    GF_DIR_EXISTS=true
else
    echo -e "${BLUE}[+] ~/.gf directory does not exist or is empty, will create/populate${NC}"
fi

# .zshrc içinde gf-completion kontrolü
GF_COMPLETION_EXISTS=false
if grep -q "gf-completion.zsh" ~/.zshrc 2>/dev/null; then
    echo -e "${GREEN}[+] gf completion already exists in .zshrc${NC}"
    GF_COMPLETION_EXISTS=true
else
    echo -e "${BLUE}[+] gf completion not found in .zshrc, will add${NC}"
fi

# .bashrc içinde gf-completion kontrolü
GF_BASH_COMPLETION_EXISTS=false
if grep -q "gf-completion.bash" ~/.bashrc 2>/dev/null; then
    echo -e "${GREEN}[+] gf completion already exists in .bashrc${NC}"
    GF_BASH_COMPLETION_EXISTS=true
else
    echo -e "${BLUE}[+] gf completion not found in .bashrc, will add${NC}"
fi

# /go/gf dizini kontrolü
GO_GF_DIR_EXISTS=false
if [ -d /go/gf ] && [ "$(ls -A /go/gf 2>/dev/null)" ]; then
    echo -e "${GREEN}[+] /go/gf directory already exists and has content${NC}"
    GO_GF_DIR_EXISTS=true
else
    echo -e "${BLUE}[+] /go/gf directory does not exist or is empty, will create/populate${NC}"
fi

# Eğer her şey tamam ise, kurulumu atla
if $GF_INSTALLED && $GF_DIR_EXISTS && $GF_COMPLETION_EXISTS && $GF_BASH_COMPLETION_EXISTS && $GO_GF_DIR_EXISTS; then
    echo -e "${GREEN}[+] gf is fully installed and configured, skipping installation${NC}"
else
    # gf repo kontrolü
    if [ ! -d "$SCRIPT_DIR/setup/gf" ] || [ ! -d "$SCRIPT_DIR/setup/gf/examples" ]; then
        # Dizin var ama examples dizini yoksa, dizini sil
        if [ -d "$SCRIPT_DIR/setup/gf" ]; then
            echo -e "${BLUE}[+] gf directory exists but is incomplete, removing and re-cloning${NC}"
            rm -rf "$SCRIPT_DIR/setup/gf"
        fi
        
        # Repo klonlama
        echo -e "${BLUE}[+] Cloning gf repository${NC}"
        if ! git clone https://github.com/tomnomnom/gf.git "$SCRIPT_DIR/setup/gf"; then
            echo -e "${RED}[-] Failed to clone gf repository${NC}"
            failed_tools+=("gf")
            GF_REPO_CLONED=false
        else
            GF_REPO_CLONED=true
        fi
    else
        echo -e "${GREEN}[+] gf repository already exists${NC}"
        GF_REPO_CLONED=true
    fi
    
    # Binary kurulumu
    if ! $GF_INSTALLED && $GF_REPO_CLONED; then
        echo -e "${BLUE}[+] Installing gf binary${NC}"
        if ! go install -v github.com/tomnomnom/gf@latest; then
            echo -e "${RED}[-] Failed to install gf binary${NC}"
            failed_tools+=("gf")
        fi
    fi
    
    # ~/.gf dizini ve pattern dosyaları
    if ! $GF_DIR_EXISTS && $GF_REPO_CLONED; then
        echo -e "${BLUE}[+] Creating ~/.gf directory and copying patterns${NC}"
        mkdir -p ~/.gf
        if [ -d "$SCRIPT_DIR/setup/gf/examples" ]; then
            cp -r "$SCRIPT_DIR/setup/gf/examples/"* ~/.gf/ 2>/dev/null || true
        else
            echo -e "${RED}[-] Could not find examples directory${NC}"
        fi
    fi
    
    # /go/gf dizini oluşturma ve completion dosyalarını kopyalama
    if ! $GO_GF_DIR_EXISTS && $GF_REPO_CLONED; then
        echo -e "${BLUE}[+] Creating /go/gf directory and copying completion files${NC}"
        sudo mkdir -p /go/gf
        if [ -f "$SCRIPT_DIR/setup/gf/gf-completion.zsh" ]; then
            sudo cp "$SCRIPT_DIR/setup/gf/gf-completion.zsh" /go/gf/
            echo -e "${GREEN}[+] Copied gf-completion.zsh to /go/gf/${NC}"
        else
            echo -e "${RED}[-] Could not find gf-completion.zsh${NC}"
        fi
        
        if [ -f "$SCRIPT_DIR/setup/gf/gf-completion.bash" ]; then
            sudo cp "$SCRIPT_DIR/setup/gf/gf-completion.bash" /go/gf/
            echo -e "${GREEN}[+] Copied gf-completion.bash to /go/gf/${NC}"
        else
            echo -e "${RED}[-] Could not find gf-completion.bash${NC}"
        fi
    fi
    
    # .zshrc completion
    if ! $GF_COMPLETION_EXISTS && $GF_REPO_CLONED; then
        echo -e "${BLUE}[+] Adding gf completion to .zshrc${NC}"
        if [ -f /go/gf/gf-completion.zsh ]; then
            echo "source /go/gf/gf-completion.zsh" >> ~/.zshrc
            echo -e "${GREEN}[+] Added gf-completion.zsh source to .zshrc${NC}"
        else
            echo -e "${RED}[-] Could not find /go/gf/gf-completion.zsh${NC}"
        fi
    fi
    
    # .bashrc completion
    if ! $GF_BASH_COMPLETION_EXISTS && $GF_REPO_CLONED; then
        echo -e "${BLUE}[+] Adding gf completion to .bashrc${NC}"
        if [ -f /go/gf/gf-completion.bash ]; then
            echo "source /go/gf/gf-completion.bash" >> ~/.bashrc
            echo -e "${GREEN}[+] Added gf-completion.bash source to .bashrc${NC}"
        else
            echo -e "${RED}[-] Could not find /go/gf/gf-completion.bash${NC}"
        fi
    fi
    
    echo -e "${GREEN}[+] gf installation and configuration completed${NC}"
fi

# Install Python tools
echo -e "${BLUE}[+] Installing Python tools...${NC}"

# Waymore - URL fetcher
if [ -L "/usr/local/bin/waymore" ] || pip list 2>/dev/null | grep -q "waymore"; then
    echo -e "${GREEN}[+] Waymore is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Waymore via pip...${NC}"
    if pip install waymore; then
        echo -e "${GREEN}[+] Waymore installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Waymore${NC}"
        failed_tools+=("Waymore")
    fi
fi

# corscanner - CORS misconfiguration scanner
if [ -L "/usr/local/bin/corscanner" ] || pip list 2>/dev/null | grep -q "corscanner"; then
    echo -e "${GREEN}[+] corscanner is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing corscanner via pip...${NC}"
    if pip install corscanner; then
        echo -e "${GREEN}[+] corscanner installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install corscanner${NC}"
        failed_tools+=("corscanner")
    fi
fi

# ParamSpider - Parameter discovery
if command -v paramspider &> /dev/null; then
    echo -e "${GREEN}[+] ParamSpider is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing ParamSpider...${NC}"
    if git clone https://github.com/devanshbatham/paramspider.git "$SCRIPT_DIR/setup/ParamSpider" && \
       cd "$SCRIPT_DIR/setup/ParamSpider" && \
       pip install . && \
       cd - > /dev/null; then
        echo -e "${GREEN}[+] ParamSpider installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install ParamSpider${NC}"
        failed_tools+=("ParamSpider")
    fi
fi

# snallygaster - Security scanner
if [ -L "/usr/local/bin/snallygaster" ] || pip list 2>/dev/null | grep -q "snallygaster"; then
    echo -e "${GREEN}[+] snallygaster is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing snallygaster via pip...${NC}"
    if apt-get install -y python3-dnspython python3-urllib3 python3-bs4 && \
       pip install snallygaster; then
        echo -e "${GREEN}[+] snallygaster installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install snallygaster${NC}"
        failed_tools+=("snallygaster")
    fi
fi

# Lazy-Hunter - Security scanner
echo -e "${BLUE}[+] Checking Lazy-Hunter...${NC}"
if [ -L "/usr/local/bin/lazyhunter" ] && [ -d "$SCRIPT_DIR/setup/Lazy-Hunter" ]; then
    echo -e "${GREEN}[+] Lazy-Hunter is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Lazy-Hunter...${NC}"
    if [ -d "$SCRIPT_DIR/setup/Lazy-Hunter" ]; then
        echo -e "${YELLOW}[!] Lazy-Hunter directory exists, checking installation...${NC}"
        # Dizin var ama symlink yok, symlink oluşturalım
        if [ -f "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py" ]; then
            # os.system("clear") komutunu kaldır
            sed -i 's/os\.system("clear")/#os.system("clear")/g' "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py"
            echo -e "${GREEN}[+] Removed os.system(\"clear\") command from lazyhunter.py${NC}"
            
            chmod +x "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py"
            ln -sf "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py" /usr/local/bin/lazyhunter
            echo -e "${GREEN}[+] Lazy-Hunter symlink created successfully${NC}"
        else
            echo -e "${RED}[-] Lazy-Hunter script not found in the directory${NC}"
            # Dizini temizleyelim ve yeniden yüklemeyi deneyelim
            rm -rf "$SCRIPT_DIR/setup/Lazy-Hunter"
            if git clone https://github.com/iamunixtz/Lazy-Hunter.git "$SCRIPT_DIR/setup/Lazy-Hunter" && \
               [ -f "$SCRIPT_DIR/setup/Lazy-Hunter/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/Lazy-Hunter/requirements.txt" && \
               [ -f "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py" ]; then
                # os.system("clear") komutunu kaldır
                sed -i 's/os\.system("clear")/#os.system("clear")/g' "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py"
                echo -e "${GREEN}[+] Removed os.system(\"clear\") command from lazyhunter.py${NC}"
                
                chmod +x "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py"
                ln -sf "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py" /usr/local/bin/lazyhunter
                echo -e "${GREEN}[+] Lazy-Hunter installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install Lazy-Hunter${NC}"
                failed_tools+=("Lazy-Hunter")
            fi
        fi
    else
        # Dizin yok, tamamen yeni kurulum
        if git clone https://github.com/iamunixtz/Lazy-Hunter.git "$SCRIPT_DIR/setup/Lazy-Hunter" && \
           [ -f "$SCRIPT_DIR/setup/Lazy-Hunter/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/Lazy-Hunter/requirements.txt" && \
           [ -f "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py" ]; then
            # os.system("clear") komutunu kaldır
            sed -i 's/os\.system("clear")/#os.system("clear")/g' "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py"
            echo -e "${GREEN}[+] Removed os.system(\"clear\") command from lazyhunter.py${NC}"
            
            chmod +x "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py"
            ln -sf "$SCRIPT_DIR/setup/Lazy-Hunter/lazyhunter.py" /usr/local/bin/lazyhunter
            echo -e "${GREEN}[+] Lazy-Hunter installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install Lazy-Hunter${NC}"
            failed_tools+=("Lazy-Hunter")
        fi
    fi
fi

# Smuggler - HTTP request smuggling tool
echo -e "${BLUE}[+] Checking Smuggler...${NC}"
if [ -L "/usr/local/bin/smuggler" ] && [ -d "$SCRIPT_DIR/setup/smuggler" ]; then
    echo -e "${GREEN}[+] Smuggler is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Smuggler...${NC}"
    if [ -d "$SCRIPT_DIR/setup/smuggler" ]; then
        echo -e "${YELLOW}[!] Smuggler directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/smuggler/smuggler.py" ]; then
            chmod +x "$SCRIPT_DIR/setup/smuggler/smuggler.py"
            ln -sf "$SCRIPT_DIR/setup/smuggler/smuggler.py" /usr/local/bin/smuggler
            echo -e "${GREEN}[+] Smuggler symlink created successfully${NC}"
        else
            echo -e "${RED}[-] Smuggler script not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/smuggler"
            if git clone https://github.com/defparam/smuggler.git "$SCRIPT_DIR/setup/smuggler" && \
               [ -f "$SCRIPT_DIR/setup/smuggler/smuggler.py" ] && \
               chmod +x "$SCRIPT_DIR/setup/smuggler/smuggler.py" && \
               ln -sf "$SCRIPT_DIR/setup/smuggler/smuggler.py" /usr/local/bin/smuggler; then
                echo -e "${GREEN}[+] Smuggler installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install Smuggler${NC}"
                failed_tools+=("Smuggler")
            fi
        fi
    else
        if git clone https://github.com/defparam/smuggler.git "$SCRIPT_DIR/setup/smuggler" && \
           [ -f "$SCRIPT_DIR/setup/smuggler/smuggler.py" ] && \
           chmod +x "$SCRIPT_DIR/setup/smuggler/smuggler.py" && \
           ln -sf "$SCRIPT_DIR/setup/smuggler/smuggler.py" /usr/local/bin/smuggler; then
            echo -e "${GREEN}[+] Smuggler installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install Smuggler${NC}"
            failed_tools+=("Smuggler")
        fi
    fi
fi

# BFAC - Backup file artifacts checker
if command -v bfac &> /dev/null; then
    echo -e "${GREEN}[+] BFAC is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing BFAC...${NC}"
    if [ -d "$SCRIPT_DIR/setup/bfac" ]; then
        echo -e "${YELLOW}[!] BFAC directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/bfac/setup.py" ]; then
            cd "$SCRIPT_DIR/setup/bfac"
            python3 setup.py install
            cd - > /dev/null
            echo -e "${GREEN}[+] BFAC installed successfully${NC}"
        else
            echo -e "${RED}[-] BFAC setup.py not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/bfac"
            if git clone https://github.com/mazen160/bfac.git "$SCRIPT_DIR/setup/bfac" && \
               cd "$SCRIPT_DIR/setup/bfac" && \
               python3 setup.py install && \
               pip install -r requirements.txt && \
               cd - > /dev/null; then
                echo -e "${GREEN}[+] BFAC installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install BFAC${NC}"
                failed_tools+=("BFAC")
            fi
        fi
    else
        if git clone https://github.com/mazen160/bfac.git "$SCRIPT_DIR/setup/bfac" && \
           cd "$SCRIPT_DIR/setup/bfac" && \
           python3 setup.py install && \
           pip install -r requirements.txt && \
           cd - > /dev/null; then
            echo -e "${GREEN}[+] BFAC installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install BFAC${NC}"
            failed_tools+=("BFAC")
        fi
    fi
fi

# GitDorker - GitHub dork scanner
echo -e "${BLUE}[+] Checking GitDorker...${NC}"
if [ -L "/usr/local/bin/gitdorker" ] && [ -d "$SCRIPT_DIR/setup/GitDorker" ]; then
    echo -e "${GREEN}[+] GitDorker is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing GitDorker...${NC}"
    if [ -d "$SCRIPT_DIR/setup/GitDorker" ]; then
        echo -e "${YELLOW}[!] GitDorker directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" ]; then
            if [ -f "$SCRIPT_DIR/setup/GitDorker/requirements.txt" ]; then
                pip install -r "$SCRIPT_DIR/setup/GitDorker/requirements.txt"
            fi
            chmod +x "$SCRIPT_DIR/setup/GitDorker/GitDorker.py"
            ln -sf "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" /usr/local/bin/gitdorker
            echo -e "${GREEN}[+] GitDorker symlink created successfully${NC}"
        else
            echo -e "${RED}[-] GitDorker script not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/GitDorker"
            if git clone https://github.com/obheda12/GitDorker.git "$SCRIPT_DIR/setup/GitDorker" && \
               [ -f "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" ] && \
               [ -f "$SCRIPT_DIR/setup/GitDorker/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/GitDorker/requirements.txt" && \
               chmod +x "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" && \
               ln -sf "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" /usr/local/bin/gitdorker; then
                echo -e "${GREEN}[+] GitDorker installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install GitDorker${NC}"
                failed_tools+=("GitDorker")
            fi
        fi
    else
        if git clone https://github.com/obheda12/GitDorker.git "$SCRIPT_DIR/setup/GitDorker" && \
           [ -f "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" ] && \
           [ -f "$SCRIPT_DIR/setup/GitDorker/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/GitDorker/requirements.txt" && \
           chmod +x "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" && \
           ln -sf "$SCRIPT_DIR/setup/GitDorker/GitDorker.py" /usr/local/bin/gitdorker; then
            echo -e "${GREEN}[+] GitDorker installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install GitDorker${NC}"
            failed_tools+=("GitDorker")
        fi
    fi
fi

# XSStrike - XSS scanner
echo -e "${BLUE}[+] Checking XSStrike...${NC}"
if [ -L "/usr/local/bin/xsstrike" ] && [ -d "$SCRIPT_DIR/setup/XSStrike" ]; then
    echo -e "${GREEN}[+] XSStrike is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing XSStrike...${NC}"
    if [ -d "$SCRIPT_DIR/setup/XSStrike" ]; then
        echo -e "${YELLOW}[!] XSStrike directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" ] && [ -f "$SCRIPT_DIR/setup/XSStrike/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/XSStrike/requirements.txt"
            chmod +x "$SCRIPT_DIR/setup/XSStrike/xsstrike.py"
            ln -sf "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" /usr/local/bin/xsstrike
            echo -e "${GREEN}[+] XSStrike symlink created successfully${NC}"
        else
            echo -e "${RED}[-] XSStrike script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/XSStrike"
            if git clone https://github.com/s0md3v/XSStrike.git "$SCRIPT_DIR/setup/XSStrike" && \
               [ -f "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" ] && \
               [ -f "$SCRIPT_DIR/setup/XSStrike/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/XSStrike/requirements.txt" && \
               chmod +x "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" && \
               ln -sf "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" /usr/local/bin/xsstrike; then
                echo -e "${GREEN}[+] XSStrike installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install XSStrike${NC}"
                failed_tools+=("XSStrike")
            fi
        fi
    else
        if git clone https://github.com/s0md3v/XSStrike.git "$SCRIPT_DIR/setup/XSStrike" && \
           [ -f "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" ] && \
           [ -f "$SCRIPT_DIR/setup/XSStrike/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/XSStrike/requirements.txt" && \
           chmod +x "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" && \
           ln -sf "$SCRIPT_DIR/setup/XSStrike/xsstrike.py" /usr/local/bin/xsstrike; then
            echo -e "${GREEN}[+] XSStrike installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install XSStrike${NC}"
            failed_tools+=("XSStrike")
        fi
    fi
fi

# Pinkerton - GitHub secret scanner
echo -e "${BLUE}[+] Checking Pinkerton...${NC}"
if [ -L "/usr/local/bin/pinkerton" ] && [ -d "$SCRIPT_DIR/setup/Pinkerton" ]; then
    echo -e "${GREEN}[+] Pinkerton is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Pinkerton...${NC}"
    if [ -d "$SCRIPT_DIR/setup/Pinkerton" ]; then
        echo -e "${YELLOW}[!] Pinkerton directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/Pinkerton/main.py" ] && [ -f "$SCRIPT_DIR/setup/Pinkerton/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/Pinkerton/requirements.txt"
            # Shebang satırını ekleme
            if ! grep -q "#!/usr/bin/python3" "$SCRIPT_DIR/setup/Pinkerton/main.py"; then
                sed -i '1i#!/usr/bin/python3' "$SCRIPT_DIR/setup/Pinkerton/main.py"
            fi
            chmod +x "$SCRIPT_DIR/setup/Pinkerton/main.py"
            ln -sf "$SCRIPT_DIR/setup/Pinkerton/main.py" /usr/local/bin/pinkerton
            echo -e "${GREEN}[+] Pinkerton symlink created successfully${NC}"
        else
            echo -e "${RED}[-] Pinkerton script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/Pinkerton"
            if git clone https://github.com/oppsec/pinkerton.git "$SCRIPT_DIR/setup/Pinkerton" && \
               [ -f "$SCRIPT_DIR/setup/Pinkerton/main.py" ] && \
               [ -f "$SCRIPT_DIR/setup/Pinkerton/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/Pinkerton/requirements.txt" && \
               sed -i '1i#!/usr/bin/python3' "$SCRIPT_DIR/setup/Pinkerton/main.py" && \
               chmod +x "$SCRIPT_DIR/setup/Pinkerton/main.py" && \
               ln -sf "$SCRIPT_DIR/setup/Pinkerton/main.py" /usr/local/bin/pinkerton; then
                echo -e "${GREEN}[+] Pinkerton installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install Pinkerton${NC}"
                failed_tools+=("Pinkerton")
            fi
        fi
    else
        if git clone https://github.com/oppsec/pinkerton.git "$SCRIPT_DIR/setup/Pinkerton" && \
           [ -f "$SCRIPT_DIR/setup/Pinkerton/main.py" ] && \
           [ -f "$SCRIPT_DIR/setup/Pinkerton/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/Pinkerton/requirements.txt" && \
           sed -i '1i#!/usr/bin/python3' "$SCRIPT_DIR/setup/Pinkerton/main.py" && \
           chmod +x "$SCRIPT_DIR/setup/Pinkerton/main.py" && \
           ln -sf "$SCRIPT_DIR/setup/Pinkerton/main.py" /usr/local/bin/pinkerton; then
            echo -e "${GREEN}[+] Pinkerton installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install Pinkerton${NC}"
            failed_tools+=("Pinkerton")
        fi
    fi
fi

# JSScanner - JavaScript scanner
echo -e "${BLUE}[+] Checking JSScanner...${NC}"
if [ -L "/usr/local/bin/jsscanner" ] && [ -d "$SCRIPT_DIR/setup/JSScanner" ]; then
    echo -e "${GREEN}[+] JSScanner is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing JSScanner...${NC}"
    if [ -d "$SCRIPT_DIR/setup/JSScanner" ]; then
        echo -e "${YELLOW}[!] JSScanner directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" ] && [ -f "$SCRIPT_DIR/setup/JSScanner/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/JSScanner/requirements.txt"
            chmod +x "$SCRIPT_DIR/setup/JSScanner/JSScanner.py"
            ln -sf "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" /usr/local/bin/jsscanner
            echo -e "${GREEN}[+] JSScanner symlink created successfully${NC}"
        else
            echo -e "${RED}[-] JSScanner script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/JSScanner"
            if git clone https://github.com/0x240x23elu/JSScanner.git "$SCRIPT_DIR/setup/JSScanner" && \
               [ -f "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" ] && \
               [ -f "$SCRIPT_DIR/setup/JSScanner/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/JSScanner/requirements.txt" && \
               chmod +x "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" && \
               ln -sf "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" /usr/local/bin/jsscanner; then
                echo -e "${GREEN}[+] JSScanner installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install JSScanner${NC}"
                failed_tools+=("JSScanner")
            fi
        fi
    else
        if git clone https://github.com/0x240x23elu/JSScanner.git "$SCRIPT_DIR/setup/JSScanner" && \
           [ -f "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" ] && \
           [ -f "$SCRIPT_DIR/setup/JSScanner/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/JSScanner/requirements.txt" && \
           chmod +x "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" && \
           ln -sf "$SCRIPT_DIR/setup/JSScanner/JSScanner.py" /usr/local/bin/jsscanner; then
            echo -e "${GREEN}[+] JSScanner installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install JSScanner${NC}"
            failed_tools+=("JSScanner")
        fi
    fi
fi

# SecretFinder - Find secrets in JavaScript files
echo -e "${BLUE}[+] Checking SecretFinder...${NC}"
if [ -L "/usr/local/bin/secretfinder" ] && [ -d "$SCRIPT_DIR/setup/secretfinder" ]; then
    echo -e "${GREEN}[+] SecretFinder is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing SecretFinder...${NC}"
    if [ -d "$SCRIPT_DIR/setup/secretfinder" ]; then
        echo -e "${YELLOW}[!] SecretFinder directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" ] && [ -f "$SCRIPT_DIR/setup/secretfinder/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/secretfinder/requirements.txt"
            chmod +x "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py"
            ln -sf "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" /usr/local/bin/secretfinder
            echo -e "${GREEN}[+] SecretFinder symlink created successfully${NC}"
        else
            echo -e "${RED}[-] SecretFinder script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/secretfinder"
            if git clone https://github.com/m4ll0k/SecretFinder.git "$SCRIPT_DIR/setup/secretfinder" && \
               [ -f "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" ] && \
               [ -f "$SCRIPT_DIR/setup/secretfinder/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/secretfinder/requirements.txt" && \
               chmod +x "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" && \
               ln -sf "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" /usr/local/bin/secretfinder; then
                echo -e "${GREEN}[+] SecretFinder installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install SecretFinder${NC}"
                failed_tools+=("SecretFinder")
            fi
        fi
    else
        if git clone https://github.com/m4ll0k/SecretFinder.git "$SCRIPT_DIR/setup/secretfinder" && \
           [ -f "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" ] && \
           [ -f "$SCRIPT_DIR/setup/secretfinder/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/secretfinder/requirements.txt" && \
           chmod +x "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" && \
           ln -sf "$SCRIPT_DIR/setup/secretfinder/SecretFinder.py" /usr/local/bin/secretfinder; then
            echo -e "${GREEN}[+] SecretFinder installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install SecretFinder${NC}"
            failed_tools+=("SecretFinder")
        fi
    fi
fi

# LinkFinder - Find links in JavaScript files
echo -e "${BLUE}[+] Checking LinkFinder...${NC}"
if [ -L "/usr/local/bin/linkfinder" ] && [ -d "$SCRIPT_DIR/setup/LinkFinder" ]; then
    echo -e "${GREEN}[+] LinkFinder is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing LinkFinder...${NC}"
    if [ -d "$SCRIPT_DIR/setup/LinkFinder" ]; then
        echo -e "${YELLOW}[!] LinkFinder directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py" ] && [ -f "$SCRIPT_DIR/setup/LinkFinder/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/LinkFinder/requirements.txt"
            cd "$SCRIPT_DIR/setup/LinkFinder" && python3 setup.py install && cd - > /dev/null
            chmod +x "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
            ln -sf "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py" /usr/local/bin/linkfinder
            echo -e "${GREEN}[+] LinkFinder symlink created successfully${NC}"
            
            # Web tarayıcı açma özelliklerini devre dışı bırak
            sed -i 's/webbrowser.open(file)/#webbrowser.open(file)\neprint("")/g' "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
            sed -i 's/subprocess.call(["xdg-open", file])/#subprocess.call(["xdg-open", file])\nprint("")/g' "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
            echo -e "${GREEN}[+] LinkFinder web tarayıcı açma özellikleri devre dışı bırakıldı${NC}"
        else
            echo -e "${RED}[-] LinkFinder script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/LinkFinder"
            if git clone https://github.com/GerbenJavado/LinkFinder.git "$SCRIPT_DIR/setup/LinkFinder" && \
               [ -f "$SCRIPT_DIR/setup/LinkFinder/setup.py" ] && \
               [ -f "$SCRIPT_DIR/setup/LinkFinder/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/LinkFinder/requirements.txt" && \
               cd "$SCRIPT_DIR/setup/LinkFinder" && python3 setup.py install && cd - > /dev/null && \
               chmod +x "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py" && \
               ln -sf "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py" /usr/local/bin/linkfinder; then
                echo -e "${GREEN}[+] LinkFinder installed successfully${NC}"
                
                # Web tarayıcı açma özelliklerini devre dışı bırak
                sed -i 's/webbrowser.open/#webbrowser.open\n/g' "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
                sed -i 's/subprocess.call(\["xdg-open"/#subprocess.call(\["xdg-open"\n/g' "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
                echo -e "${GREEN}[+] LinkFinder web tarayıcı açma özellikleri devre dışı bırakıldı${NC}"
            else
                echo -e "${RED}[-] Failed to install LinkFinder${NC}"
                failed_tools+=("LinkFinder")
            fi
        fi
    else
        if git clone https://github.com/GerbenJavado/LinkFinder.git "$SCRIPT_DIR/setup/LinkFinder" && \
           [ -f "$SCRIPT_DIR/setup/LinkFinder/setup.py" ] && \
           [ -f "$SCRIPT_DIR/setup/LinkFinder/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/LinkFinder/requirements.txt" && \
           cd "$SCRIPT_DIR/setup/LinkFinder" && python3 setup.py install && cd - > /dev/null && \
           chmod +x "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py" && \
           ln -sf "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py" /usr/local/bin/linkfinder; then
            echo -e "${GREEN}[+] LinkFinder installed successfully${NC}"
            
            # Web tarayıcı açma özelliklerini devre dışı bırak
            sed -i 's/webbrowser.open/#webbrowser.open\n/g' "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
            sed -i 's/subprocess.call(\["xdg-open"/#subprocess.call(\["xdg-open"\n/g' "$SCRIPT_DIR/setup/LinkFinder/linkfinder.py"
            echo -e "${GREEN}[+] LinkFinder web tarayıcı açma özellikleri devre dışı bırakıldı${NC}"
        else
            echo -e "${RED}[-] Failed to install LinkFinder${NC}"
            failed_tools+=("LinkFinder")
        fi
    fi
fi

# CORScanner - CORS misconfiguration scanner
echo -e "${BLUE}[+] Checking CORScanner...${NC}"
if [ -L "/usr/local/bin/corsscanner" ] && [ -d "$SCRIPT_DIR/setup/CORScanner" ]; then
    echo -e "${GREEN}[+] CORScanner is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing CORScanner...${NC}"
    if [ -d "$SCRIPT_DIR/setup/CORScanner" ]; then
        echo -e "${YELLOW}[!] CORScanner directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/CORScanner/cors_scan.py" ] && [ -f "$SCRIPT_DIR/setup/CORScanner/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/CORScanner/requirements.txt"
            chmod +x "$SCRIPT_DIR/setup/CORScanner/cors_scan.py"
            ln -sf "$SCRIPT_DIR/setup/CORScanner/cors_scan.py" /usr/local/bin/corsscanner
            echo -e "${GREEN}[+] CORScanner symlink created successfully${NC}"
        else
            echo -e "${RED}[-] CORScanner script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/CORScanner"
            if git clone https://github.com/chenjj/CORScanner.git "$SCRIPT_DIR/setup/CORScanner" && \
               [ -f "$SCRIPT_DIR/setup/CORScanner/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/CORScanner/requirements.txt" && \
               chmod +x "$SCRIPT_DIR/setup/CORScanner/cors_scan.py" && \
               ln -sf "$SCRIPT_DIR/setup/CORScanner/cors_scan.py" /usr/local/bin/corsscanner; then
                echo -e "${GREEN}[+] CORScanner installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install CORScanner${NC}"
                failed_tools+=("CORScanner")
            fi
        fi
    else
        if git clone https://github.com/chenjj/CORScanner.git "$SCRIPT_DIR/setup/CORScanner" && \
           [ -f "$SCRIPT_DIR/setup/CORScanner/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/CORScanner/requirements.txt" && \
           chmod +x "$SCRIPT_DIR/setup/CORScanner/cors_scan.py" && \
           ln -sf "$SCRIPT_DIR/setup/CORScanner/cors_scan.py" /usr/local/bin/corsscanner; then
            echo -e "${GREEN}[+] CORScanner installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install CORScanner${NC}"
            failed_tools+=("CORScanner")
        fi
    fi
fi

# GoogleDorker - Google dorks tool
if pip list 2>/dev/null | grep -q "GoogleDorker"; then
    echo -e "${GREEN}[+] GoogleDorker is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing GoogleDorker via pip...${NC}"
    if pip install --upgrade --upgrade-strategy eager --ignore-installed git+https://github.com/RevoltSecurities/GoogleDorker; then
        echo -e "${GREEN}[+] GoogleDorker installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install GoogleDorker${NC}"
        failed_tools+=("GoogleDorker")
    fi
fi

# Fast-Google-Dorks-Scan - Google dorks scanner
if [ -L "/usr/local/bin/fgds" ]; then
    echo -e "${GREEN}[+] Fast-Google-Dorks-Scan is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Fast-Google-Dorks-Scan...${NC}"
    if [ -d "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan" ]; then
        echo -e "${YELLOW}[!] Fast-Google-Dorks-Scan directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" ]; then
            chmod +x "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh"
            ln -sf "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" /usr/local/bin/fgds
            echo -e "${GREEN}[+] Fast-Google-Dorks-Scan symlink created successfully${NC}"
        else
            echo -e "${RED}[-] Fast-Google-Dorks-Scan script not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan"
            if git clone https://github.com/IvanGlinkin/Fast-Google-Dorks-Scan.git "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan" && \
               [ -f "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" ] && \
               chmod +x "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" && \
               ln -sf "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" /usr/local/bin/fgds; then
                echo -e "${GREEN}[+] Fast-Google-Dorks-Scan installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install Fast-Google-Dorks-Scan${NC}"
                failed_tools+=("Fast-Google-Dorks-Scan")
            fi
        fi
    else
        if git clone https://github.com/IvanGlinkin/Fast-Google-Dorks-Scan.git "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan" && \
           [ -f "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" ] && \
           chmod +x "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" && \
           ln -sf "$SCRIPT_DIR/setup/Fast-Google-Dorks-Scan/FGDS.sh" /usr/local/bin/fgds; then
            echo -e "${GREEN}[+] Fast-Google-Dorks-Scan installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install Fast-Google-Dorks-Scan${NC}"
            failed_tools+=("Fast-Google-Dorks-Scan")
        fi
    fi
fi

# Sublist3rV2 - Subdomain enumeration
echo -e "${BLUE}[+] Checking Sublist3rV2...${NC}"
if [ -L "/usr/local/bin/sublist3r" ] && [ -d "$SCRIPT_DIR/setup/sublist3rV2" ]; then
    echo -e "${GREEN}[+] Sublist3rV2 is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Sublist3rV2...${NC}"
    if [ -d "$SCRIPT_DIR/setup/sublist3rV2" ]; then
        echo -e "${YELLOW}[!] Sublist3rV2 directory exists, checking installation...${NC}"
        if [ -f "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py" ] && [ -f "$SCRIPT_DIR/setup/sublist3rV2/requirements.txt" ]; then
            pip install -r "$SCRIPT_DIR/setup/sublist3rV2/requirements.txt"
            pip install "$SCRIPT_DIR/setup/sublist3rV2"
            chmod +x "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py"
            ln -sf "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py" /usr/local/bin/sublist3r
            echo -e "${GREEN}[+] Sublist3rV2 symlink created successfully${NC}"
        else
            echo -e "${RED}[-] Sublist3rV2 script or requirements not found in the directory${NC}"
            rm -rf "$SCRIPT_DIR/setup/sublist3rV2"
            if git clone https://github.com/hxlxmj/sublist3rV2.git "$SCRIPT_DIR/setup/sublist3rV2" && \
               [ -f "$SCRIPT_DIR/setup/sublist3rV2/setup.py" ] && \
               [ -f "$SCRIPT_DIR/setup/sublist3rV2/requirements.txt" ] && \
               pip install -r "$SCRIPT_DIR/setup/sublist3rV2/requirements.txt" && \
               pip install "$SCRIPT_DIR/setup/sublist3rV2" && \
               chmod +x "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py" && \
               ln -sf "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py" /usr/local/bin/sublist3r; then
                echo -e "${GREEN}[+] Sublist3rV2 installed successfully${NC}"
            else
                echo -e "${RED}[-] Failed to install Sublist3rV2${NC}"
                failed_tools+=("Sublist3rV2")
            fi
        fi
    else
        if git clone https://github.com/hxlxmj/sublist3rV2.git "$SCRIPT_DIR/setup/sublist3rV2" && \
           [ -f "$SCRIPT_DIR/setup/sublist3rV2/setup.py" ] && \
           [ -f "$SCRIPT_DIR/setup/sublist3rV2/requirements.txt" ] && \
           pip install -r "$SCRIPT_DIR/setup/sublist3rV2/requirements.txt" && \
           pip install "$SCRIPT_DIR/setup/sublist3rV2" && \
           chmod +x "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py" && \
           ln -sf "$SCRIPT_DIR/setup/sublist3rV2/sublist3r.py" /usr/local/bin/sublist3r; then
            echo -e "${GREEN}[+] Sublist3rV2 installed successfully${NC}"
        else
            echo -e "${RED}[-] Failed to install Sublist3rV2${NC}"
            failed_tools+=("Sublist3rV2")
        fi
    fi
fi

# Install APT tools
echo -e "${BLUE}[+] Installing APT tools...${NC}"
# dnsrecon - DNS reconnaissance tool
if dpkg -l | grep -q "dnsrecon"; then
    echo -e "${GREEN}[+] dnsrecon is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing dnsrecon...${NC}"
    if apt-get install -y dnsrecon; then
        echo -e "${GREEN}[+] dnsrecon installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install dnsrecon${NC}"
        failed_tools+=("dnsrecon")
    fi
fi

# gobuster - Directory/DNS/subdomain bruteforcing tool
if dpkg -l | grep -q "gobuster"; then
    echo -e "${GREEN}[+] gobuster is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing gobuster...${NC}"
    if apt-get install -y gobuster; then
        echo -e "${GREEN}[+] gobuster installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install gobuster${NC}"
        failed_tools+=("gobuster")
    fi
fi

# massdns - DNS resolver and lookup tool
if dpkg -l | grep -q "massdns"; then
    echo -e "${GREEN}[+] massdns is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing massdns...${NC}"
    if apt-get install -y massdns; then
        echo -e "${GREEN}[+] massdns installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install massdns${NC}"
        failed_tools+=("massdns")
    fi
fi

# S3Scanner - S3 bucket scanner
if dpkg -l | grep -q "s3scanner"; then
    echo -e "${GREEN}[+] S3Scanner is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing S3Scanner...${NC}"
    if apt-get install -y s3scanner; then
        echo -e "${GREEN}[+] S3Scanner installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install S3Scanner${NC}"
        failed_tools+=("S3Scanner")
    fi
fi

# Cloud Enum - Cloud enumeration
if dpkg -l | grep -q "cloud-enum"; then
    echo -e "${GREEN}[+] Cloud Enum is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Cloud Enum...${NC}"
    if apt-get install -y cloud-enum; then
        echo -e "${GREEN}[+] Cloud Enum installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Cloud Enum${NC}"
        failed_tools+=("Cloud Enum")
    fi
fi

# Amass - Attack surface mapping
if dpkg -l | grep -q "amass"; then
    echo -e "${GREEN}[+] Amass is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Amass...${NC}"
    if apt-get update && apt-get install -y amass; then
        echo -e "${GREEN}[+] Amass installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Amass${NC}"
        failed_tools+=("Amass")
    fi
fi

# arjun - Parameter discovery tool
if command -v arjun &> /dev/null; then
    echo -e "${GREEN}[+] arjun is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing arjun via pipx...${NC}"
    if pipx install arjun; then
        echo -e "${GREEN}[+] arjun installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install arjun${NC}"
        failed_tools+=("arjun")
    fi
fi

# naabu - Port scanner
if command -v naabu &> /dev/null; then
    echo -e "${GREEN}[+] naabu is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing naabu...${NC}"
    if apt-get install -y naabu; then
        echo -e "${GREEN}[+] naabu installed successfully${NC}"
    else
        # Eğer apt ile yüklenemezse, go install ile deneyelim
        echo -e "${BLUE}[+] Trying to install naabu via go install...${NC}"
        if go install -v github.com/projectdiscovery/naabu/v2/cmd/naabu@latest; then
            echo -e "${GREEN}[+] naabu installed successfully via go${NC}"
        else
            echo -e "${RED}[-] Failed to install naabu${NC}"
            failed_tools+=("naabu")
        fi
    fi
fi

# Feroxbuster - Web content scanner
if dpkg -l | grep -q "feroxbuster"; then
    echo -e "${GREEN}[+] Feroxbuster is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Feroxbuster...${NC}"
    if apt-get install -y feroxbuster; then
        echo -e "${GREEN}[+] Feroxbuster installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Feroxbuster${NC}"
        failed_tools+=("Feroxbuster")
    fi
fi

# Aquatone - Visual inspection tool
if command -v aquatone &> /dev/null; then
    echo -e "${GREEN}[+] Aquatone is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing Aquatone...${NC}"
    AQUATONE_VERSION="1.7.0"
    AQUATONE_URL="https://github.com/michenriksen/aquatone/releases/download/v${AQUATONE_VERSION}/aquatone_linux_amd64_${AQUATONE_VERSION}.zip"
    AQUATONE_ZIP="$SCRIPT_DIR/setup/aquatone_linux_amd64_${AQUATONE_VERSION}.zip"

    if wget -q "$AQUATONE_URL" -O "$AQUATONE_ZIP" && \
       unzip -q "$AQUATONE_ZIP" -d "$SCRIPT_DIR/setup/aquatone" && \
       mv "$SCRIPT_DIR/setup/aquatone/aquatone" /usr/bin/ && \
       chmod +x /usr/bin/aquatone; then
        echo -e "${GREEN}[+] Aquatone installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install Aquatone${NC}"
        failed_tools+=("Aquatone")
    fi
fi

# trufflehog - Secret scanner
if dpkg -l | grep -q "trufflehog"; then
    echo -e "${GREEN}[+] trufflehog is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing trufflehog...${NC}"
    if apt-get install -y trufflehog; then
        echo -e "${GREEN}[+] trufflehog installed successfully${NC}"
    else
        echo -e "${RED}[-] Failed to install trufflehog${NC}"
        failed_tools+=("trufflehog")
    fi
fi

# Install Rust tools
echo -e "${BLUE}[+] Installing Rust tools...${NC}"
# Check if Rust is installed
if ! command -v cargo &> /dev/null; then
    echo -e "${BLUE}[+] Installing Rust...${NC}"
    apt-get install -y cargo || {
        echo -e "${BLUE}[+] Installing Rust via rustup...${NC}"
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    }
fi

# PATH'e Cargo bin dizinini ekle
if ! grep -q "/.cargo/bin" ~/.bashrc; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    echo -e "${GREEN}[+] Added Cargo bin directory to PATH in .bashrc${NC}"
fi

if ! grep -q "/.cargo/bin" ~/.zshrc 2>/dev/null; then
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.zshrc 2>/dev/null || true
    echo -e "${GREEN}[+] Added Cargo bin directory to PATH in .zshrc (if exists)${NC}"
fi

# Geçici olarak PATH'e ekle
export PATH="$HOME/.cargo/bin:$PATH"


# x8 - Hidden parameters discovery
if command -v x8 &> /dev/null; then
    echo -e "${GREEN}[+] x8 is already installed${NC}"
else
    echo -e "${BLUE}[+] Installing x8...${NC}"
    # Önce x8 bağımlılıklarını yükle
    if apt-get install -y pkg-config libssl-dev && \
       cargo install x8; then
        echo -e "${GREEN}[+] x8 installed successfully${NC}"
        echo -e "${GREEN}[+] Make sure to add $HOME/.cargo/bin to your PATH to run x8${NC}"
    else
        echo -e "${RED}[-] Failed to install x8${NC}"
        failed_tools+=("x8")
    fi
fi

# Installation summary
echo ""
echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}          INSTALLATION SUMMARY        ${NC}"
echo -e "${BLUE}======================================${NC}"

if [ ${#failed_tools[@]} -eq 0 ]; then
    echo -e "${GREEN}[+] All tools were installed successfully! 🚀${NC}"
else
    echo -e "${RED}[-] The following tools failed to install:${NC}"
    for tool in "${failed_tools[@]}"; do
        echo -e "${RED}    - $tool${NC}"
    done
    echo ""
    echo -e "${RED}[!] Please check the logs above for more details and try to install these tools manually.${NC}"
fi

# Kurulum süresini hesapla
END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
MINUTES=$((ELAPSED_TIME / 60))
SECONDS=$((ELAPSED_TIME % 60))

echo ""
echo -e "${GREEN}[+] Installation process completed in ${MINUTES} minutes and ${SECONDS} seconds.${NC}"

# Sanal ortamdan çık
deactivate

# Remind user to source the updated profile
echo -e "${BLUE}[+] To use the installed tools in the current session, run:${NC}"
echo -e "${GREEN}    source ~/.bashrc${NC}"
echo -e "${GREEN}    export PATH=\$PATH:/usr/local/go/bin:~/go/bin:\$HOME/.cargo/bin:\$HOME/.local/bin${NC}"

# Sanal ortamı aktifleştirmek için bilgi
echo -e "${YELLOW}[!] To activate the Python virtual environment, run:${NC}"
echo -e "${GREEN}    source $VENV_DIR/bin/activate${NC}"