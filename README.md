# TheBestRecon
A system that makes all the work easier by using Recon, Discovery, Port scan, Vulnerability scan tools and running them all in a compatible way.

### Why?
I looked at the market and couldn't find a single automated tool that could run all of them, so I decided to make one myself.

## What Does It Do?

- ✅ Performs subdomain discovery
- ✅ Finds live subdomains
- ✅ Discovers URLs
- ✅ Analyzes JavaScript files
- ✅ Finds parameters and scans for XSS
- ✅ Performs port scanning
- ✅ Performs vulnerability scanning

## Installation 🔧

```bash
# Clone the repo
git clone https://github.com/emin-demir/TheBestRecon.git
cd TheBestRecon

# Install tools
chmod +x install_tools.sh
sudo ./install_tools.sh

# Give execution permission
chmod +x recon.sh
chmod +x modules/*.sh
```

## Usage

```bash
Usage: ./recon.sh [options]

Options:
  -d, --domain <domain>        Target domain (required, multiple can be specified but not recommended)
  -o, --output <directory>     Output directory (default: output/)
  -h, --help                   Usage instructions (Help Menu)
  -a, --api-config <file>      Configuration file for API keys

Scan Modes:
  --short-scan                 Short scan - Only scans 10 critical subdomains
  --medium-scan                Medium scan - Scans 30-50 important subdomains
  --big-scan                   Big scan - Scans all subdomains (default)

Modules:
  --all-modules, -all         Run all modules
  --sub-enum, -sE             Run subdomain enumeration (assetfinder, subfinder, sublist3r, etc)
  --sub-brute, -sB            Run subdomain bruteforce (gobuster, amass)
  --subs-live, -sL            Run live subdomain check (httpx, httprobe)
  --screen-shoot, -sS         Take screenshots (aquatone)
  --url-discovery, -uD        Run URL Discovery (gau, waymore, katana, feroxbuster etc.)
  --js-discovery, -jD         Discover JavaScript files (subjs, getJS, Secretfinder)
  --param-discovery, -pD      Run parameter discovery (ParamSpider, Arjun)
  --js-analysis, -jS          Search for valuable data in JavaScript files (TruffleHog, Linkfinder, Grep)
  --param-analysis, -pmS      Performs XSS vulnerability detection on parameters (KXSS, Dalfox, XSStrike)
  --port-scan, -pS            Run port scanning (nmap, masscan, naabu)
  --vuln-scan, -vS            Run vulnerability scanning (nuclei, corscanner, smuggler, bfac)

Examples:
  ./recon.sh -d example.com -sE -pS
  ./recon.sh -d example.com --short-scan -all
  ./recon.sh -d example.com --medium-scan -vS
  ./recon.sh -d example.com -d example2.com -all
  ./recon.sh -d example.com -all -a api_keys.txt
  ./recon.sh -d example.com -sE -sL -sS -uD -jD -pD
```

Since a python environment is used for the tool, after installing_tools.sh installation, it gives a command like source /root/Desktop/TheBestRecon/venv/bin/activate. If python commands don't work, don't forget to use the python environment.

## Tools Used

### Subdomain Discovery
- Subfinder, Assetfinder, Amass, Sublist3rV2, Shuffledns, Github-subdomains, Gobuster

### URL Discovery
- Gau, Waymore, Katana

### JavaScript and Parameter Discovery
- ParamSpider, Arjun, subjs, getJS, x8

### JavaScript Analysis
- TruffleHog, LinkFinder, Regex Search

### Parameter Analysis
- kXSS, XSStrike, Dalfox

### Port Scanning
- Naabu, Nmap

### Vulnerability Scanning
- Nuclei, LazyHunter, HTTP, GoChopChop, Smuggler, Snallygaster, BFAC

## Outputs

All results are stored in an organized way under `output/target.com_YYYYMMDD_HHMMSS/`:

```
output/target.com_20230421_120000/
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

## Example Usage Scenarios

### Comprehensive Scan
```bash
./recon.sh -d example.com -all
# But -all parameters are very slow. So be careful
```

### Only Vulnerability Scan
```bash
./recon.sh -d example.com --vuln-scan
```

### Subdomain Discovery and Live Check
```bash
./recon.sh -d example.com --sub-enum --subs-live
```

## Disclaimer

Use this tool **ONLY** on systems you have permission to test! The user is responsible for any consequences arising from illegal use. This tool is developed for testing and security research purposes, not for malicious use. 

❗️❗️❗️ There may be some errors while the system is running. I recommend that you use the parameters one by one. Since it is still in the development phase, it may sometimes give errors.

> **Remember:** Hack the planet, not the people!

# Contributing
If you say "Let's do justice to this tool", open a PR, let's develop it together!

---

<p align="center">
  <sub>Made with ❤️ by <a href="https://github.com/emin-demir">Emin Demir</a></sub>
</p>