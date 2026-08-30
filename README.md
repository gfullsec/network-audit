# network-audit
Automated network auditing tool with host discovery, port scanning, service enumeration, and structured reporting.

network-audit.sh automates a security audit of a local network environment. Its goal is to detect active devices, identify manufacturers, analyze relevant ports, export results to CSV and JSON, compare one audit with another, generate change alerts, and leave the environment ready for maintenance and follow‑up. It is a tool designed for auditing and reviewing visible infrastructure in a local network, intended for practical use and change diagnostics.

## What the script does, block by block

### Block 1 — Environment Preparation
This block prepares the working structure for the current audit. Actions: creates the base audit directory at $HOME/Documentos/seguridad/auditorias; creates a specific folder for the current audit using the current date and time; generates subdirectories for discovery, manufacturers, ports, csv, json, changes, logs, alerts. It also prints the date and the path of the ongoing audit.

### Block 2 — Network Discovery + Manufacturers
This block performs the initial reconnaissance of the network. Steps: displays active IPv4 interfaces; asks the user to select one; calculates the associated network; allows confirmation or manual override; runs a host scan with Nmap using: nmap -sn -PR "$NETWORK" -oN "$DESC_FILE". Then it uses arp-scan to detect active devices and map IPs to MAC addresses and manufacturers: sudo arp-scan --interface="$IFACE" "$NETWORK". Results are processed to obtain IP → MAC(s) and IP+MAC → manufacturer. A single MAC/manufacturer is prioritized per IP. Final result stored in fabricantes/fabricantes_YYYY-MM-DD_HH-MM-SS.txt.

### Block 3 — Port Scanning
This block processes detected hosts and decides whether to run a fast or deep scan. Logic: reads IPs from discovery; finds manufacturer; decides scan type; runs fast scan (nmap -Pn --top-ports 100) or deep scan (nmap -A -p-). Results stored in puertos/<date>/ with one file per IP.

### Block 4 — CSV Generation
Converts port scan results into a CSV file: csv/auditoria_YYYY-MM-DD_HH-MM-SS.csv. Header: "IP";"Manufacturer";"Port";"Service";"State";"ScanType";"Date". For each port file: extracts IP; finds manufacturer; normalizes name; identifies scan type; includes only valid states (open, closed, filtered); generates one row per port. If no valid ports exist, writes N/A and no_open_ports.

### Block 5 — JSON Generation (Grouped by IP)
Creates json/auditoria_YYYY-MM-DD_HH-MM-SS.json. Each IP entry includes manufacturer, scanType, date, ports. Example: {"192.168.1.10":{"manufacturer":"Dell","scanType":"deep","date":"2026-08-29_20-28-46","ports":[{"port":22,"service":"ssh","state":"open"}]}}. Logic: read CSV; clean fields; create IP entry if missing; append ports.

### Block 6 — Comparison with Previous Audits
Compares current audit with a previous one. Actions: lists previous audits; asks user to select one; checks JSON validity; compares new devices, missing devices, new ports, closed ports, manufacturer changes, scan type changes. Results stored in cambios/cambios_YYYY-MM-DD_HH-MM-SS.txt and cambios/cambios_YYYY-MM-DD_HH-MM-SS.json.

### Block 7 — Alert Generation
Generates alerts based on detected changes. Files: alertas/alertas_YYYY-MM-DD_HH-MM-SS.txt and alertas/alertas_YYYY-MM-DD_HH-MM-SS.json. Alerts include: new devices, missing devices, new ports, closed ports, manufacturer changes, scan type changes. TXT includes sections like [ALERT] New device: ... JSON stores structured equivalents.

### Block 8 — Intelligent Cleanup
Asks whether to clean old audits. If confirmed: keeps current audit, previous audit, and the one used for comparison; deletes the rest. Goal: save space and keep relevant references. Logs cleanup operations in cleanup_YYYY-MM-DD_HH-MM-SS.log.

### Block 9 — Technical Report Generation
Generates comprehensive technical report combining all audit data. Creates two outputs: reports/report_YYYY-MM-DD_HH-MM-SS.txt (human-readable) and reports/report_YYYY-MM-DD_HH-MM-SS.json (structured). The report includes: summary of all generated files, unique device list with manufacturers, port inventory per device, detected changes (new/missing devices, new/closed ports, manufacturer changes, scan type changes), alerts summary, and cleanup summary. Aggregates data from CSV, JSON, changes, alerts, and cleanup logs.

### Block 10 — Finalization
Prints final summary: audit completion status, audit location, technical report paths, closing message thanking the user.

## Technologies and Tools Used
Bash, Nmap, arp-scan, jq, ip, grep, awk, sed, cut, xargs.

## What is this script used for?
Detect active devices; determine manufacturers; identify open ports and services; document infrastructure with CSV/JSON; compare audits; detect changes; generate basic security alerts.

## Final Output Structure
~/.network-audit/audits/  
└── YYYY-MM-DD_HH-MM-SS/  
    ├── discovery/  
    ├── manufacturers/  
    ├── ports/  
    ├── csv/  
    ├── json/  
    ├── changes/  
    ├── alerts/  
    ├── reports/  
    └── logs/

## Limitations
Depends on system/network permissions; requires nmap, arp-scan, jq; manufacturer detection may be approximate; comparison requires valid previous JSON; detection relies on parsed strings and heuristics.

## Legal and Ethical Considerations
Use only in authorized environments for auditing, administration, or security of your own infrastructure. Do not scan networks or systems without explicit consent.

