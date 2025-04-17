# TheBestRecon
Recon, Discovery, Port scan, Vulnerability scan toollarını kullanıp hepsini birbiriyle uyumlu bir şekilde çalıştırıp bütün işi kolaylaştıran bir sistemdir. 

### Neden ?
Piyasaya baktım hepsini çalıştırabileceğim tek bir otomatize tool bulamadım kendim yapmaya karar verdim.

## Ne İşe Yarar? 

- ✅ Subdomain keşfi yapar
- ✅ Canlı subdomainleri bulur
- ✅ URL'leri keşfeder
- ✅ JavaScript dosyalarını analiz eder
- ✅ Parametreleri bulur ve XSS tarar
- ✅ Port taraması yapar
- ✅ Zafiyet taraması yapar

## Kurulum 🔧

```bash
# Repoyu indir
git clone https://github.com/emin-demir/TheBestRecon.git
cd TheBestRecon

# Araçları kur
chmod +x install_tools.sh
sudo ./install_tools.sh

# Çalıştırma izni ver
chmod +x recon.sh
chmod +x modules/*.sh
```

## Kullanım :

```bash
# Temel kullanım
./recon.sh hedef.com

# Tüm modülleri çalıştır
./recon.sh hedef.com -a

# Sadece subdomain keşfi
./recon.sh hedef.com --sub-enum
```
Tool için python environment kullanıldığı için çalıştırmak için installing_tools.sh kurulumu sonrasında bir komut veriyor. 
source /root/Desktop/TheBestRecon/venv/bin/activate gibi. Eğer python komutları çalışmazsa python environment ' ini kullanmayı unutmayın.

## Parametreler

| Parametre | Açıklama |
|-----------|----------|
| `-a`, `--all` | Tüm modülleri çalıştır |
| `--sub-enum` | Subdomain enumeration |
| `--sub-brute` | Subdomain bruteforce |
| `--subs-live` | Canlı subdomain kontrolü |
| `--url-discovery` | URL keşfi |
| `--js-discovery` | JavaScript keşfi |
| `--param-discovery` | Parametre keşfi |
| `--js-analysis` | JavaScript analizi |
| `--param-analysis` | Parametre analizi |
| `--port-scan` | Port taraması |
| `--vuln-scan` | Zafiyet taraması |

## Kullanılan Araçlar

### Subdomain Keşfi
- Subfinder, Assetfinder, Amass, Findomain, Sublist3r, crobat, Shosubgo, Shuffledns, Github-subdomains

### URL Keşfi
- Gau, Waymore, Fuzzuli, Feroxbuster, Katana, Hakrawler, Gospider

### JavaScript ve Parametre Keşfi
- ParamSpider, x8, Arjun

### JavaScript Analizi
- SecretFinder, TruffleHog, LinkFinder

### Parametre Analizi
- kXSS, XSStrike, Dalfox

### Port Tarama
- Naabu, Nmap

### Zafiyet Tarama
- Nuclei, Smuggler, BFAC, GoChopChop, Snallygaster, LazyHunter, CORScanner

## Çıktılar 

Bütün sonuçlar `output/hedef.com_YYYYMMDD_HHMMSS/` altında düzenli bir şekilde saklanır:

```
output/hedef.com_20230421_120000/
├── subdomain_enum/
├── subdomain_brute/
├── subs_live/
├── url_discovery/
├── js_param_discovery/
├── js_analysis/
├── param_analysis/
├── port_scan/
└── vuln_scan/
```

## Örnek Kullanım Senaryoları 

### Tam Kapsamlı Tarama
```bash
./recon.sh example.com -a
```

### Sadece Zafiyet Taraması
```bash
./recon.sh example.com --vuln-scan
```

### Subdomain Keşfi ve Canlı Kontrol
```bash
./recon.sh example.com --sub-enum --subs-live
```

## Sorumluluk Reddi 

Bu aracı **SADECE** izin verilen sistemlerde kullanın! Yasa dışı kullanımdan doğacak her türlü sonuçtan kullanıcı sorumludur. Bu araç test ve güvenlik araştırmaları amacıyla geliştirilmiştir, kötü niyetli kullanım için değil.

> **Unutma:** Hack the planet, not the people!

# Katkıda Bulunma
"Bu toolun hakkını verelim." diyorsan PR aç, beraber geliştirelim!

---

<p align="center">
  <sub>Made with ❤️ by <a href="https://github.com/emin-demir">Emin Demir</a></sub>
</p>