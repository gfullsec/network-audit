
# Network Audit Tool — Architecture Documentation

## 1. Introduction

The *Network Audit Tool* is a fully automated Bash-based auditing system designed to perform structured, reproducible, and portable network assessments.  
Its architecture is built around clear modular blocks, deterministic output, and strict separation of responsibilities.

The tool produces human-readable and machine-readable artifacts (TXT, JSON, CSV, Mermaid diagrams) and maintains a complete audit history under a timestamped folder structure.

### Objectives

- **Discover active devices** in a local network.
- **Identify open ports** and service exposure.
- **Detect changes** between audits.
- **Generate structured reports** for security analysis.
- **Provide a logical network diagram.**
- **Maintain a clean, timestamped audit archive.**

### Design principles

- **Portability:** Works on any Linux system without external dependencies beyond standard CLI tools.
- **Reproducibility:** Every audit is isolated in its own timestamped folder.
- **Zero assumptions:** No hardcoded IPs; router detection is dynamic.
- **Safety:** No unsafe concatenation; all JSON is generated via `jq`.
- **Professional reporting:** TXT + JSON outputs synchronized and complete.

### System requirements

- Bash 4+
- `nmap`
- `jq`
- `awk`
- `iproute2`
- Standard GNU utilities (`sed`, `find`, `sort`, etc.)

---

## 2. High-level architecture

The tool is composed of **11 execution blocks**, each responsible for a specific stage of the audit.  
The architecture follows a linear pipeline where each block produces artifacts consumed by the next.

### Execution flow overview

```text
1. Prepare environment / logs
2. Network discovery
3. Port scanning
4. CSV generation
5. JSON generation
6. Mermaid diagram generation
7. Comparison with previous scan
8. Change alerts
9. Cleanup
10. Technical report generation
11. Finalization
```

### Data flow

```text
discovery → manufacturers → ports → csv → json → diagram → comparison → alerts → report
```

### Folder structure

Each audit is stored under:

```text
~/.network-audit/audits/TIMESTAMP/
```

Containing:

```text
discovery/
manufacturers/
ports/
csv/
json/
diagrams/
changes/
alerts/
logs/
reports/
```

---

## 3. Module architecture (the 11 blocks)

### Block 1 — Prepare environment / logs

**Purpose:**  
Initialize the audit environment and create the folder structure.

**Inputs:**  
- None.

**Outputs:**
- Timestamped audit folder.
- Log files (`execution_TIMESTAMP.log`, `cleanup_TIMESTAMP.log`).
- Subdirectories for all subsequent blocks.

**Design notes:**
- Ensures isolation between audits.
- Prevents file collisions.
- Centralizes logging.

---

### Block 2 — Network discovery

**Purpose:**  
Identify active hosts in the local network.

**Inputs:**
- Local network interface.
- IP range.

**Outputs:**
- `discovery_TIMESTAMP.txt`.
- List of IPs for subsequent blocks.

**Design notes:**
- Uses ARP and/or ping sweep.
- No assumptions about topology.
- Discovery is the “source of truth” for the audit.

---

### Block 3 — Port scanning

**Purpose:**  
Perform port scans on each discovered device.

**Inputs:**
- List of IPs from Block 2.

**Outputs:**
- One file per device under `ports/TIMESTAMP/`.
- Port list for JSON generation.

**Design notes:**
- Supports quick and full scans.
- Normalizes port output for later processing.

---

### Block 4 — CSV generation

**Purpose:**  
Generate a tabular representation of the audit.

**Inputs:**
- Port scan results.
- Manufacturer data.

**Outputs:**
- `audit_TIMESTAMP.csv`.

**Design notes:**
- Useful for Excel, SIEM ingestion, or manual review.

---

### Block 5 — JSON generation

**Purpose:**  
Create the structured JSON representation of the audit.

**Inputs:**
- Discovery results.
- Manufacturer data.
- Port scan data.

**Outputs:**
- `audit_TIMESTAMP.json`.

**Design notes:**
- JSON is the canonical data source for comparison.
- Built entirely with `jq` to avoid injection risks.

---

### Block 6 — Mermaid diagram generation

**Purpose:**  
Generate a logical network diagram.

**Inputs:**
- `audit_TIMESTAMP.json`.
- Manufacturer data.
- Dynamic router detection via `ip route`.

**Outputs:**
- `network_logical_TIMESTAMP.mmd`.

**Design notes:**
- Router is detected dynamically (no hardcoding).
- Each node includes IP, MAC, manufacturer, and open ports.
- Diagram is rendered automatically on GitHub.

---

### Block 7 — Comparison with previous scan

**Purpose:**  
Detect changes between the current and previous audit.

**Inputs:**
- Current JSON.
- Previous JSON (if exists).

**Outputs:**
- `changes_TIMESTAMP.json`.
- `changes_TIMESTAMP.txt`.

**Design notes:**  
Detects:
- New devices.
- Missing devices.
- New ports.
- Closed ports.
- Manufacturer changes.
- Scan type changes.

---

### Block 8 — Change alerts

**Purpose:**  
Generate alert files based on detected changes.

**Inputs:**
- `changes_TIMESTAMP.json`.

**Outputs:**
- `alerts_TIMESTAMP.json`.
- `alerts_TIMESTAMP.txt`.

**Design notes:**
- Alerts are separated from raw changes for clarity.
- TXT for human review, JSON for automated processing.

---

### Block 9 — Cleanup

**Purpose:**  
Handle cleanup of old audits if configured.

**Inputs:**
- Cleanup policy (user choice or configuration).

**Outputs:**
- `cleanup_TIMESTAMP.log`.

**Design notes:**
- Cleanup is logged for traceability.
- User can skip cleanup safely.

---

### Block 10 — Technical report generation

**Purpose:**  
Generate human-readable and machine-readable reports.

**Inputs:**
- All previous artifacts (JSON, changes, alerts, logs, etc.).

**Outputs:**
- `report_TIMESTAMP.txt`.
- `report_TIMESTAMP.json`.

**Design notes:**
- TXT and JSON are synchronized.
- JSON includes a complete `folder_tree` of all generated files.
- The deprecated `files` node was removed.
- `folder_tree` is generated after both reports to ensure completeness.
- `reports/` and `diagrams/` are fully represented.

---

### Block 11 — Finalization

**Purpose:**  
Gracefully close the audit.

**Inputs:**
- None.

**Outputs:**
- Final log entry indicating completion.

**Design notes:**
- Marks the end of the audit lifecycle.
- Ensures a clear boundary between audits.

---

## 4. Data flow details

### Discovery → Manufacturers

MAC addresses are extracted and matched against OUI/manufacturer data.  
This enriches each device with vendor information.

### Manufacturers → Ports

Manufacturer data is combined with port scan results to provide context on exposed services per vendor.

### Ports → CSV / JSON

Both CSV and JSON are generated from normalized port data, ensuring consistency across formats.

### JSON → Diagram

The JSON file is the authoritative source for the Mermaid diagram.  
Nodes are built from JSON entries, including IP, MAC, manufacturer, and ports.

### JSON → Comparison

Comparison logic uses only JSON to ensure deterministic behavior and avoid parsing TXT.

### Comparison → Alerts

Alerts are derived from change detection and exported in both TXT and JSON formats.

### All → Reports

The technical reports consolidate all relevant artifacts into a single TXT and JSON pair per audit.

---

## 5. Folder structure explained

### `discovery/`

Contains the list of active IPs discovered during the scan.

### `manufacturers/`

Contains manufacturer lookup results and raw OUI data used to enrich devices.

### `ports/`

Contains one file per device with open ports and scan details.

### `csv/`

Contains the CSV export (`audit_TIMESTAMP.csv`) for tabular analysis.

### `json/`

Contains the canonical audit JSON (`audit_TIMESTAMP.json`).

### `diagrams/`

Contains Mermaid diagrams (`network_logical_TIMESTAMP.mmd`) representing the logical network.

### `changes/`

Contains change detection outputs (`changes_TIMESTAMP.json` and `.txt`).

### `alerts/`

Contains alert outputs (`alerts_TIMESTAMP.json` and `.txt`).

### `logs/`

Contains execution and cleanup logs (`execution_TIMESTAMP.log`, `cleanup_TIMESTAMP.log`).

### `reports/`

Contains the technical reports (`report_TIMESTAMP.txt` and `report_TIMESTAMP.json`).

---

## 6. Generated artifacts

### TXT reports

Human-readable summaries of the audit, including device lists, port summaries, changes, alerts, and cleanup information.

### JSON reports

Machine-readable structured data, including:

- Audit metadata.
- Folder tree.
- Device list.
- Port summary.
- Changes.
- Alerts.
- Cleanup summary.

### CSV files

Tabular representation of devices and ports, suitable for spreadsheets and SIEM ingestion.

### Mermaid diagrams

Logical network diagrams rendered from `.mmd` files, showing router, devices, MAC addresses, manufacturers, and open ports.

### Logs

Execution and cleanup logs for traceability and debugging.

### Change & alert files

Structured and human-readable change detection and alert information.

---

## 7. Design decisions

- **Dynamic router detection** using `ip route` instead of hardcoded IPs.
- **JSON as the single source of truth** for comparison and diagram generation.
- **Folder tree generated after report creation** to ensure all artifacts are included.
- **Removal of deprecated `files` node** from the JSON report structure.
- **Strict modular architecture** with clearly defined blocks.
- **Safe JSON generation** using `jq` to avoid injection and malformed structures.
- **Deterministic output structure** for every audit.

---

## 8. Known limitations

- No OS fingerprinting.
- No SNMP-based switch topology detection.
- No VLAN awareness.
- No mesh network detection.
- No deep service fingerprinting beyond port numbers.

---

## 9. Future improvements

- HTML report generation.
- REST API mode for remote triggering and retrieval.
- Grafana or dashboard integration.
- OS detection and service fingerprinting.
- Cloud and hybrid network scanning support.
- Modular rewrite in Python + Bash for extended logic.
- Direct SIEM integration (e.g., via JSON or CSV exports).

---

**End of Architecture Documentation**