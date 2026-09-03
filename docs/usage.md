


# Using network-audit

`network-audit` is a network auditing tool that performs host discovery, port scanning, and structured generation of artifacts. Its goal is to provide a complete and organized audit of the local network.

---

## 1. Preparation

Install the required dependencies:

```bash
sudo apt install arp-scan nmap jq
```

Give execution permissions to the main script:

```bash
chmod +x src/network-audit.sh
```

---

## 2. Running the audit

Run the script:

```bash
./src/network-audit.sh
```

During execution, you will see messages indicating each phase of the process.  
The script behaves as follows:

### ✔ Start
The script displays a message indicating that the audit is starting and creates the directory structure under:

```
~/.network-audit/audits/audit_TIMESTAMP/
```

### ✔ Network discovery
`arp-scan` and a ping sweep are executed.  
Results are stored in:

```
discovery/
```

Typical message:

```
[INFO] Discovering hosts...
```

### ✔ Manufacturer resolution (MAC → vendor)
The script analyzes detected MAC addresses and stores vendor information in:

```
manufacturers/
```

### ✔ Port scanning
`nmap` is executed on the discovered hosts.  
Results are stored in:

```
ports/
```

Message:

```
[INFO] Running port scan...
```

### ✔ Normalization and artifact generation
The script processes all collected data and generates:

- CSV → `csv/`
- JSON → `json/`

Messages:

```
[INFO] Generating CSV...
[INFO] Generating JSON...
```

### ✔ Logical diagram generation
A `.mmd` file representing the detected topology is created in:

```
diagrams/
```

Message:

```
[INFO] Building logical diagram...
```

### ✔ Comparison with previous audits (user choice)
If previous audits exist, the script:

1. Detects that older audits are available.  
2. Asks whether you want to compare the current audit with the previous one.

Example:

```
A previous audit was found. Do you want to compare? (y/n):
```

- If you answer **y**, the comparison is generated in:

  ```
  changes/
  ```

  And you will see:

  ```
  [INFO] Comparing with previous audit...
  ```

- If you answer **n**, the script continues without generating changes.

### ✔ Alert generation (only if comparison was accepted)
If the comparison detects relevant differences, alerts are generated in:

```
alerts/
```

Message:

```
[INFO] Generating alerts...
```

### ✔ Technical report
A technical report (TXT and JSON) is generated inside:

```
reports/
```

Message:

```
[INFO] Generating report...
```

### ✔ Cleanup (user choice)
If older audits exist, the script offers cleanup options:

Example:

```
Do you want to delete old audits? (y/n):
```

If you answer **y**, the script:

- identifies older audit folders  
- deletes them from:

  ```
  ~/.network-audit/audits/
  ```

- always keeps the current audit, the immediately previous audit, and the audit that was used as the comparison source.
 
- displays messages such as:

  ```
  [INFO] Cleaning old audits...
  [INFO] Deleted: audit_YYYYMMDD_HHMM
  ```

If you answer **n**, nothing is removed.

### ✔ Finalization
The script closes logs and finishes:

```
[INFO] Audit completed successfully.
```

Logs are stored in:

```
logs/
```

---

## 3. Audit structure

Each audit contains the following folders:

- **alerts/** → generated alerts  
- **changes/** → detected changes  
- **csv/** → CSV exports  
- **diagrams/** → logical diagrams  
- **discovery/** → network discovery data  
- **json/** → structured audit JSON  
- **logs/** → execution logs  
- **manufacturers/** → MAC vendor resolution  
- **ports/** → port scan results  
- **reports/** → technical report  

