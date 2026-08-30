#!/bin/bash

# 1. Prepare environment / logs (base folders, date, file names)
# 2. Network discovery
# 3. Port scanning
# 4. CSV generation
# 5. JSON generation
# 6. Comparison with previous scan
# 7. Change alerts
# 8. Cleanup
# 9. Technical report generation
# 10. Finalization


#!/bin/bash

# ============================================
#  BLOCK 1 — PREPARE ENVIRONMENT (structure by audit)
# ============================================

DATE_STAMP=$(date +"%Y-%m-%d_%H-%M-%S")

# Base folder where ALL audits are saved
BASE="$HOME/.network-audit/audits"

# Specific folder for THIS audit
OUT="$BASE/$DATE_STAMP"

# Create professional structure per audit
mkdir -p "$OUT/discovery"
mkdir -p "$OUT/manufacturers"
mkdir -p "$OUT/ports"
mkdir -p "$OUT/csv"
mkdir -p "$OUT/json"
mkdir -p "$OUT/changes"
mkdir -p "$OUT/logs"
mkdir -p "$OUT/alerts"
mkdir -p "$OUT/reports"

echo "Environment prepared."
echo "Audit date: $DATE_STAMP"
echo "Root folder for this audit: $OUT"
echo "--------------------------------------------------"

exec > >(tee "$OUT/logs/execution_$DATE_STAMP.log") 2>&1


# ============================================
#  BLOCK 2 — NETWORK DISCOVERY + MANUFACTURERS (professional version with Solution D)
# ============================================

echo "Detecting active network interfaces..."
echo

ip -4 a | grep "inet " | awk '{print NR ") " $2 " -> " $NF}'
echo
read -p "Select the network interface number you want to use: " IFACE_NUM

SELECTED=$(ip -4 a | grep "inet " | awk 'NR=='"$IFACE_NUM")
IP_CIDR=$(echo "$SELECTED" | awk '{print $2}')
IFACE=$(echo "$SELECTED" | awk '{print $NF}')
NETWORK=$(echo "$IP_CIDR" | cut -d'.' -f1-3).0/24

echo
echo "Selected interface: $IFACE"
echo "Detected IP: $IP_CIDR"
echo "Calculated network: $NETWORK"
echo

read -p "Use this network for scanning? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    read -p "Enter the network manually (e.g: 192.168.1.0/24): " NETWORK
fi

echo
echo "Using network: $NETWORK"
echo "--------------------------------------------------"

DISCOVERY_FILE="$OUT/discovery/discovery_$DATE_STAMP.txt"

echo "Starting network discovery..."
nmap -sn -PR "$NETWORK" -oN "$DISCOVERY_FILE"
echo "Discovery completed."
echo "--------------------------------------------------"

# ============================================
#  MANUFACTURER DETECTION (Solution D)
# ============================================

echo "Detecting manufacturers with arp-scan..."
echo

# Install arp-scan if it does not exist
if ! command -v arp-scan &> /dev/null; then
    echo "arp-scan is not installed. Installing it..."
    sudo apt update && sudo apt install -y arp-scan
fi

RAW_MANUFACTURERS="$OUT/manufacturers/raw_manufacturers_$DATE_STAMP.txt"
MANUFACTURERS_FILE="$OUT/manufacturers/manufacturers_$DATE_STAMP.txt"

sudo arp-scan --interface="$IFACE" "$NETWORK" > "$RAW_MANUFACTURERS"

echo "Processing manufacturers..."
echo

declare -A IP_TO_MACS
declare -A IP_TO_MANUFACTURERS

# ============================
# 1. Parse arp-scan
# ============================
while read -r IP MAC MANUFACTURER; do
    [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || continue

    # Save MAC and manufacturer in arrays
    IP_TO_MACS["$IP"]+="$MAC "
    IP_TO_MANUFACTURERS["$IP,$MAC"]="$MANUFACTURER"

done < <(grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+" "$RAW_MANUFACTURERS")

# ============================
# 2. MAC prioritization function
# ============================
prioritize_mac() {
    local ip="$1"
    local macs="${IP_TO_MACS[$ip]}"
    local best_mac=""
    local best_manufacturer=""

    # Convert to array
    read -r -a arr <<< "$macs"

    # Filter virtual MACs (02:xx:xx:xx:xx:xx)
    local real_macs=()
    for mac in "${arr[@]}"; do
        if [[ ! "$mac" =~ ^02: ]]; then
            real_macs+=("$mac")
        fi
    done

    # If no real MACs remain → use all
    [[ ${#real_macs[@]} -eq 0 ]] && real_macs=("${arr[@]}")

    # Prioritize known manufacturers
    local priority=("Intel" "Dell" "Samsung" "Quanta" "TP-Link" "Ubiquiti")

    for mac in "${real_macs[@]}"; do
        manufacturer="${IP_TO_MANUFACTURERS[$ip,$mac]}"
        for p in "${priority[@]}"; do
            if echo "$manufacturer" | grep -qi "$p"; then
                echo "$mac|$manufacturer"
                return
            fi
        done
    done

    # If there is no priority manufacturer but there is only one → use it
    if [[ ${#real_macs[@]} -eq 1 ]]; then
        mac="${real_macs[0]}"
        manufacturer="${IP_TO_MANUFACTURERS[$ip,$mac]}"
        echo "$mac|$manufacturer"
        return
    fi

    # If there are multiple and cannot decide → MULTIPLE-MAC
    echo "MULTIPLE-MAC|${IP_TO_MANUFACTURERS[$ip,${real_macs[0]}]}"
}

# ============================
# 3. Generate final manufacturers file
# ============================
> "$MANUFACTURERS_FILE"

for ip in "${!IP_TO_MACS[@]}"; do
    result=$(prioritize_mac "$ip")
    mac=$(echo "$result" | cut -d'|' -f1)
    manufacturer=$(echo "$result" | cut -d'|' -f2)

    echo -e "$ip\t$mac\t$manufacturer" >> "$MANUFACTURERS_FILE"
done

echo "Processed manufacturers:"
cat "$MANUFACTURERS_FILE"
echo "--------------------------------------------------"



# ============================================
#  BLOCK 3 — PORT SCANNING (TOP-100 + FULL SCAN)
# ============================================

echo "Extracting active IPs from discovery..."
echo

ACTIVE_IPS=$(grep "Nmap scan report for" "$DISCOVERY_FILE" | awk '{print $NF}' | tr -d '()')

if [[ -z "$ACTIVE_IPS" ]]; then
    echo "No active hosts found. Terminating."
    exit 1
fi

echo "Detected hosts:"
echo "$ACTIVE_IPS"
echo "--------------------------------------------------"

PORTS_DIR="$OUT/ports/$DATE_STAMP"
mkdir -p "$PORTS_DIR"

echo "Classifying devices and running scans..."
echo "--------------------------------------------------"

MANUFACTURERS_FILE="$OUT/manufacturers/manufacturers_$DATE_STAMP.txt"

for IP in $ACTIVE_IPS; do

    IP=$(echo "$IP" | tr -d '()')

    echo "Processing $IP ..."
    
    MANUFACTURER=$(grep "^$IP" "$MANUFACTURERS_FILE" | awk '{print $3, $4, $5}')
    MANUFACTURER=${MANUFACTURER:-"Unknown"}

    TEMPFILE="$PORTS_DIR/temp_$IP.txt"
    nmap -Pn --top-ports 100 "$IP" -oN "$TEMPFILE"

    RELEVANT_PORTS=$(grep -E "22/open|80/open|443/open|445/open|139/open|554/open|8008/open|8009/open|5000/open|5001/open|8080/open|8443/open" "$TEMPFILE")

    SCAN_TYPE="quick scan"

    if [[ "$MANUFACTURER" =~ "Samsung" || "$MANUFACTURER" =~ "Cisco" || "$MANUFACTURER" =~ "Dell" || "$MANUFACTURER" =~ "Intel" || "$MANUFACTURER" =~ "TP-Link" || "$MANUFACTURER" =~ "Ubiquiti" || "$MANUFACTURER" =~ "AzureWave" ]]; then
        SCAN_TYPE="full scan"
    fi

    if [[ ! -z "$RELEVANT_PORTS" ]]; then
        SCAN_TYPE="full scan"
    fi

    echo "Detected manufacturer: $MANUFACTURER"
    echo "Assigned scan type: $SCAN_TYPE"
    echo "--------------------------------------------------"

    if [[ "$SCAN_TYPE" == "full scan" ]]; then
        OUTFILE="$PORTS_DIR/full_$IP.txt"
        echo "Running full scan for $IP ..."
        nmap -A -p- "$IP" -oN "$OUTFILE"

        if [[ "$MANUFACTURER" =~ "Samsung" ]]; then
            if grep -qE "403 Forbidden|Script execution failed|connection reset|tls" "$OUTFILE"; then
                echo "Device $IP (Samsung) rejected the connection. Marked as SECURE." >> "$OUTFILE"
                echo "Status: Secure (device connection rejection)"
            fi
        fi

    else
        OUTFILE="$PORTS_DIR/ports_$IP.txt"
        echo "Running quick scan for $IP ..."
        mv "$TEMPFILE" "$OUTFILE"
    fi

    rm -f "$TEMPFILE"

done

echo "Port scanning completed."
echo "--------------------------------------------------"


# ============================================
#  BLOCK 4 — CSV GENERATION (ARMORED + EXACT MANUFACTURER)
# ============================================

echo "Generating CSV with results..."
CSV_FILE="$OUT/csv/audit_$DATE_STAMP.csv"

echo "\"IP\";\"Manufacturer\";\"Port\";\"Service\";\"Status\";\"ScanType\";\"Date\"" > "$CSV_FILE"

MANUFACTURERS_FILE="$OUT/manufacturers/manufacturers_$DATE_STAMP.txt"

for FILE in "$PORTS_DIR"/*.txt; do

    IP=$(basename "$FILE" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' | tr -d '()')

    RAW_MANUFACTURER=$(awk -F '\t' -v ip="$IP" '
        $1 == ip { print $3; exit }
    ' "$MANUFACTURERS_FILE")

    MANUFACTURER=${RAW_MANUFACTURER:-"Unknown"}

    MANUFACTURER=$(echo "$MANUFACTURER" | sed 's/[,:]/ /g' | sed 's/[()]//g' | sed 's/[[:space:]]\+/ /g' | xargs)

    if echo "$MANUFACTURER" | grep -qi "unknown"; then
        MANUFACTURER="Unknown"
    fi

    if [[ "$FILE" =~ "full" ]]; then
        SCAN_TYPE="full scan"
    else
        SCAN_TYPE="quick scan"
    fi

    VALID_PORTS=$(grep -v "Not shown" "$FILE" | grep -E "open|closed|filtered")

    if [[ -z "$VALID_PORTS" ]]; then
        echo "\"$IP\";\"$MANUFACTURER\";\"N/A\";\"N/A\";\"no_open_ports\";\"$SCAN_TYPE\";\"$DATE_STAMP\"" >> "$CSV_FILE"
        continue
    fi

    echo "$VALID_PORTS" | while read -r LINE; do

        PORT=$(echo "$LINE" | awk '{print $1}' | cut -d'/' -f1)

        RAW_SERVICE=$(echo "$LINE" | awk '{print $3}')
        SERVICE=$(echo "$RAW_SERVICE" | sed 's/[\/:?]/_/g' | sed 's/ //g')

        STATUS=$(echo "$LINE" | awk '{print $2}')

        if [[ "$MANUFACTURER" =~ "Samsung" ]]; then
            if echo "$LINE" | grep -qE "403|Script|reset|tls"; then
                STATUS="connection_rejected"
            fi
        fi

        echo "\"$IP\";\"$MANUFACTURER\";\"$PORT\";\"$SERVICE\";\"$STATUS\";\"$SCAN_TYPE\";\"$DATE_STAMP\"" >> "$CSV_FILE"
    done

done

echo "CSV generated at: $CSV_FILE"
echo "--------------------------------------------------"


# ============================================
#  BLOCK 5 — JSON GENERATION GROUPED BY IP
# ============================================

echo "Generating JSON grouped by IP..."

JSON_DIR="$OUT/json"
mkdir -p "$JSON_DIR"

JSON_FILE="$JSON_DIR/audit_$DATE_STAMP.json"

echo "{}" > "$JSON_FILE"

tail -n +2 "$CSV_FILE" | while IFS=';' read -r IP MANUFACTURER PORT SERVICE STATUS SCANTYPE DATE; do

    IP=$(echo "$IP" | sed 's/"//g')
    MANUFACTURER=$(echo "$MANUFACTURER" | sed 's/"//g')
    PORT=$(echo "$PORT" | sed 's/"//g')
    SERVICE=$(echo "$SERVICE" | sed 's/"//g')
    STATUS=$(echo "$STATUS" | sed 's/"//g')
    SCANTYPE=$(echo "$SCANTYPE" | sed 's/"//g')
    DATE=$(echo "$DATE" | sed 's/"//g')

    jq --arg ip "$IP" \
       --arg manufacturer "$MANUFACTURER" \
       --arg type "$SCANTYPE" \
       --arg date "$DATE" \
       '
       if .[$ip] == null then
           .[$ip] = {
               manufacturer: $manufacturer,
               scanType: $type,
               date: $date,
               ports: []
           }
       else
           .
       end
       ' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"

    if [[ "$PORT" == "N/A" ]]; then
        continue
    fi

    jq --arg ip "$IP" \
       --arg port "$PORT" \
       --arg service "$SERVICE" \
       --arg status "$STATUS" \
       '
       .[$ip].ports += [{
           port: ($port | tonumber),
           service: $service,
           status: $status
       }]
       ' "$JSON_FILE" > "$JSON_FILE.tmp" && mv "$JSON_FILE.tmp" "$JSON_FILE"

done

echo "JSON generated at: $JSON_FILE"
echo "--------------------------------------------------"

# ============================================
#  BLOCK 6 — AUDIT COMPARISON + JSON ALWAYS
# ============================================

echo "Searching for previous audits..."
echo

BASE="$HOME/.network-audit/audits"

PREVIOUS_AUDITS=$(ls "$BASE" | grep -v "$DATE_STAMP")

echo "Available options:"
echo "0) Skip comparison"
echo

i=1
declare -A MAP
for A in $PREVIOUS_AUDITS; do
    echo "$i) $A"
    MAP[$i]=$A
    ((i++))
done

echo
read -p "Select an option: " SEL

CURRENT_JSON="$OUT/json/audit_$DATE_STAMP.json"
CHANGES_TXT="$OUT/changes/changes_$DATE_STAMP.txt"
CHANGES_JSON="$OUT/changes/changes_$DATE_STAMP.json"

# ============================================================
# Initialize empty arrays for JSON ALWAYS
# ============================================================
NEW_DEVICES=""
MISSING_DEVICES=""

NEW_PORTS_JSON="[]"
CLOSED_PORTS_JSON="[]"

MANUFACTURER_CHANGES_JSON="[]"
SCAN_TYPE_CHANGES_JSON="[]"

GENERATE_TXT="no"

# ============================================================
# CASE 1 — User skips comparison
# ============================================================
if [[ "$SEL" == "0" ]]; then
    echo "Comparison skipped by user."
    echo "--------------------------------------------------"
    GENERATE_TXT="no"

else
    PREVIOUS_AUDIT="${MAP[$SEL]}"

    if [[ -z "$PREVIOUS_AUDIT" ]]; then
        echo "Invalid selection. No comparison will be performed."
        echo "--------------------------------------------------"
        GENERATE_TXT="no"

    else
        PREVIOUS_JSON="$BASE/$PREVIOUS_AUDIT/json/audit_$PREVIOUS_AUDIT.json"

        if [[ ! -f "$PREVIOUS_JSON" ]]; then
            echo "The selected audit does not have JSON. Cannot compare."
            echo "--------------------------------------------------"
            GENERATE_TXT="no"

        else
            GENERATE_TXT="yes"

            echo "Comparing current audit ($DATE_STAMP) with: $PREVIOUS_AUDIT"
            echo "--------------------------------------------------"

            # ============================================================
            # NEW DEVICES
            # ============================================================
            NEW_DEVICES=$(jq -r '
                . as $new |
                input as $old |
                ($new | keys[]) as $ip |
                if ($old[$ip] == null) then $ip else empty end
            ' "$CURRENT_JSON" "$PREVIOUS_JSON")

            # ============================================================
            # MISSING DEVICES
            # ============================================================
            MISSING_DEVICES=$(jq -r '
                . as $old |
                input as $new |
                ($old | keys[]) as $ip |
                if ($new[$ip] == null) then $ip else empty end
            ' "$PREVIOUS_JSON" "$CURRENT_JSON")

            # ============================================================
            # PORT CHANGES (without --argfile)
            # ============================================================
            NEW_PORTS_JSON=$(jq '
                [
                    . as $new |
                    input as $old |
                    ($new | keys[]) as $ip |
                    ($new[$ip].ports // []) as $newPorts |
                    ($old[$ip].ports // []) as $oldPorts |
                    $newPorts[]? as $p |
                    if ($oldPorts | map(.port) | index($p.port)) == null
                    then { ip: $ip, port: $p.port }
                    else empty end
                ]
            ' "$CURRENT_JSON" "$PREVIOUS_JSON")

            CLOSED_PORTS_JSON=$(jq '
                [
                    . as $new |
                    input as $old |
                    ($new | keys[]) as $ip |
                    ($new[$ip].ports // []) as $newPorts |
                    ($old[$ip].ports // []) as $oldPorts |
                    $oldPorts[]? as $p |
                    if ($newPorts | map(.port) | index($p.port)) == null
                    then { ip: $ip, port: $p.port }
                    else empty end
                ]
            ' "$CURRENT_JSON" "$PREVIOUS_JSON")

            # ============================================================
            # MANUFACTURER CHANGES
            # ============================================================
            MANUFACTURER_CHANGES_JSON=$(jq '
                [
                    . as $new |
                    input as $old |
                    ($new | keys[]) as $ip |
                    if ($old[$ip] != null and $new[$ip].manufacturer != $old[$ip].manufacturer)
                    then {
                        ip: $ip,
                        before: $old[$ip].manufacturer,
                        after: $new[$ip].manufacturer
                    }
                    else empty end
                ]
            ' "$CURRENT_JSON" "$PREVIOUS_JSON")

            # ============================================================
            # SCAN TYPE CHANGES
            # ============================================================
            SCAN_TYPE_CHANGES_JSON=$(jq '
                [
                    . as $new |
                    input as $old |
                    ($new | keys[]) as $ip |
                    if ($old[$ip] != null and $new[$ip].scanType != $old[$ip].scanType)
                    then {
                        ip: $ip,
                        before: $old[$ip].scanType,
                        after: $new[$ip].scanType
                    }
                    else empty end
                ]
            ' "$CURRENT_JSON" "$PREVIOUS_JSON")
        fi
    fi
fi

# ============================================================
# GENERATE TXT ONLY IF THERE IS REAL COMPARISON
# ============================================================
if [[ "$GENERATE_TXT" == "yes" ]]; then
    echo "Comparison between audits:" > "$CHANGES_TXT"
    echo "Current:  $CURRENT_JSON" >> "$CHANGES_TXT"
    echo "Previous: $PREVIOUS_JSON" >> "$CHANGES_TXT"
    echo "--------------------------------------------------" >> "$CHANGES_TXT"

    echo "New devices detected:" >> "$CHANGES_TXT"
    if [[ -z "$NEW_DEVICES" ]]; then
        echo "  None" >> "$CHANGES_TXT"
    else
        echo "$NEW_DEVICES" | sed 's/^/  + /' >> "$CHANGES_TXT"
    fi
    echo >> "$CHANGES_TXT"

    echo "Disappeared devices:" >> "$CHANGES_TXT"
    if [[ -z "$MISSING_DEVICES" ]]; then
        echo "  None" >> "$CHANGES_TXT"
    else
        echo "$MISSING_DEVICES" | sed 's/^/  - /' >> "$CHANGES_TXT"
    fi
    echo >> "$CHANGES_TXT"

    echo "Port changes:" >> "$CHANGES_TXT"
    echo "$NEW_PORTS_JSON" | jq -r '.[]? | "  + \(.ip) new port: \(.port)"' >> "$CHANGES_TXT"
    echo "$CLOSED_PORTS_JSON" | jq -r '.[]? | "  - \(.ip) closed port: \(.port)"' >> "$CHANGES_TXT"
    echo >> "$CHANGES_TXT"

    echo "Manufacturer changes:" >> "$CHANGES_TXT"
    echo "$MANUFACTURER_CHANGES_JSON" | jq -r '.[]? | "  * \(.ip): \(.before) → \(.after)"' >> "$CHANGES_TXT"
    echo >> "$CHANGES_TXT"

    echo "Scan type changes:" >> "$CHANGES_TXT"
    echo "$SCAN_TYPE_CHANGES_JSON" | jq -r '.[]? | "  * \(.ip): \(.before) → \(.after)"' >> "$CHANGES_TXT"
fi

# ============================================================
# GENERATE JSON ALWAYS (without advanced jq)
# ============================================================

# Convert simple lists to JSON
NEW_DEVICES_JSON=$(printf '%s\n' "$NEW_DEVICES" | jq -R -s 'split("\n") | map(select(length>0))')
MISSING_DEVICES_JSON=$(printf '%s\n' "$MISSING_DEVICES" | jq -R -s 'split("\n") | map(select(length>0))')

# Construir JSON final con Bash
echo "{
  \"newDevices\": $NEW_DEVICES_JSON,
  \"missingDevices\": $MISSING_DEVICES_JSON,
  \"newPorts\": $NEW_PORTS_JSON,
  \"closedPorts\": $CLOSED_PORTS_JSON,
  \"manufacturerChanges\": $MANUFACTURER_CHANGES_JSON,
  \"scanTypeChanges\": $SCAN_TYPE_CHANGES_JSON
}" > "$CHANGES_JSON"


echo
echo "JSON report generated at:"
echo "$CHANGES_JSON"
echo "--------------------------------------------------"

# ============================================
#  BLOCK 7 — AUTOMATIC ALERTS (TXT + JSON)
# ============================================

echo
echo "Generating alerts..."
echo "--------------------------------------------------"

CHANGES_JSON="$OUT/changes/changes_$DATE_STAMP.json"
ALERTS_TXT="$OUT/alerts/alerts_$DATE_STAMP.txt"
ALERTS_JSON="$OUT/alerts/alerts_$DATE_STAMP.json"

# Create TXT file
echo "Alerts generated in audit $DATE_STAMP" > "$ALERTS_TXT"
echo "--------------------------------------------------" >> "$ALERTS_TXT"

# Initialize empty JSON arrays
NEW_DEVICES_JSON="[]"
MISSING_DEVICES_JSON="[]"
NEW_PORTS_JSON="[]"
CLOSED_PORTS_JSON="[]"
MANUFACTURER_CHANGES_JSON="[]"
SCAN_TYPE_CHANGES_JSON="[]"

# ================================
# NEW DEVICES
# ================================
NEW_DEVICES=$(jq -r '.newDevices[]?' "$CHANGES_JSON")

echo "New devices detected:" >> "$ALERTS_TXT"
if [[ -z "$NEW_DEVICES" ]]; then
    echo "  None" >> "$ALERTS_TXT"
else
    echo "$NEW_DEVICES" | sed 's/^/  + /' >> "$ALERTS_TXT"
    echo "$NEW_DEVICES" | sed 's/^/[ALERT] New device: /'
    NEW_DEVICES_JSON=$(printf '%s\n' "$NEW_DEVICES" | jq -R -s 'split("\n") | map(select(length>0))')
fi
echo >> "$ALERTS_TXT"

# ================================
# MISSING DEVICES
# ================================
MISSING_DEVICES=$(jq -r '.missingDevices[]?' "$CHANGES_JSON")

echo "Disappeared devices:" >> "$ALERTS_TXT"
if [[ -z "$MISSING_DEVICES" ]]; then
    echo "  None" >> "$ALERTS_TXT"
else
    echo "$MISSING_DEVICES" | sed 's/^/  - /' >> "$ALERTS_TXT"
    echo "$MISSING_DEVICES" | sed 's/^/[ALERT] Missing device: /'
    MISSING_DEVICES_JSON=$(printf '%s\n' "$MISSING_DEVICES" | jq -R -s 'split("\n") | map(select(length>0))')
fi
echo >> "$ALERTS_TXT"

# ================================
# NEW PORTS
# ================================
NEW_PORTS=$(jq -r '.newPorts[]? | "\(.ip) \(.port)"' "$CHANGES_JSON")

echo "New ports:" >> "$ALERTS_TXT"
if [[ -z "$NEW_PORTS" ]]; then
    echo "  None" >> "$ALERTS_TXT"
else
    echo "$NEW_PORTS" | sed 's/^/  + /' >> "$ALERTS_TXT"
    echo "$NEW_PORTS" | sed 's/^/[ALERT] New port: /'
    NEW_PORTS_JSON=$(jq -r '.newPorts' "$CHANGES_JSON")
fi
echo >> "$ALERTS_TXT"

# ================================
# CLOSED PORTS
# ================================
CLOSED_PORTS=$(jq -r '.closedPorts[]? | "\(.ip) \(.port)"' "$CHANGES_JSON")

echo "Closed ports:" >> "$ALERTS_TXT"
if [[ -z "$CLOSED_PORTS" ]]; then
    echo "  None" >> "$ALERTS_TXT"
else
    echo "$CLOSED_PORTS" | sed 's/^/  - /' >> "$ALERTS_TXT"
    echo "$CLOSED_PORTS" | sed 's/^/[ALERT] Closed port: /'
    CLOSED_PORTS_JSON=$(jq -r '.closedPorts' "$CHANGES_JSON")
fi
echo >> "$ALERTS_TXT"

# ================================
# MANUFACTURER CHANGES
# ================================
MANUFACTURER_CHANGES=$(jq -r '.manufacturerChanges[]? | "\(.ip) \(.before) \(.after)"' "$CHANGES_JSON")

echo "Manufacturer changes:" >> "$ALERTS_TXT"
if [[ -z "$MANUFACTURER_CHANGES" ]]; then
    echo "  None" >> "$ALERTS_TXT"
else
    echo "$MANUFACTURER_CHANGES" | sed 's/^/  * /' >> "$ALERTS_TXT"
    echo "$MANUFACTURER_CHANGES" | sed 's/^/[ALERT] Manufacturer change: /'
    MANUFACTURER_CHANGES_JSON=$(jq -r '.manufacturerChanges' "$CHANGES_JSON")
fi
echo >> "$ALERTS_TXT"

# ================================
# SCAN TYPE CHANGES
# ================================
SCAN_TYPE_CHANGES=$(jq -r '.scanTypeChanges[]? | "\(.ip) \(.before) \(.after)"' "$CHANGES_JSON")

echo "Scan type changes:" >> "$ALERTS_TXT"
if [[ -z "$SCAN_TYPE_CHANGES" ]]; then
    echo "  None" >> "$ALERTS_TXT"
else
    echo "$SCAN_TYPE_CHANGES" | sed 's/^/  * /' >> "$ALERTS_TXT"
    echo "$SCAN_TYPE_CHANGES" | sed 's/^/[ALERT] Scan type change: /'
    SCAN_TYPE_CHANGES_JSON=$(jq -r '.scanTypeChanges' "$CHANGES_JSON")
fi
echo >> "$ALERTS_TXT"

# ================================
# GENERATE ALERTS JSON (ALWAYS)
# ================================
echo "{
  \"newDevices\": $NEW_DEVICES_JSON,
  \"missingDevices\": $MISSING_DEVICES_JSON,
  \"newPorts\": $NEW_PORTS_JSON,
  \"closedPorts\": $CLOSED_PORTS_JSON,
  \"manufacturerChanges\": $MANUFACTURER_CHANGES_JSON,
  \"scanTypeChanges\": $SCAN_TYPE_CHANGES_JSON
}" > "$ALERTS_JSON"

echo
echo "Alerts JSON generated at:"
echo "$ALERTS_JSON"
echo "--------------------------------------------------"

# ============================================
#  BLOCK 8 — INTELLIGENT CLEANUP
# ============================================

echo
echo "Do you want to clean up old audits? (y/n)"
read CLEANUP

# Cleanup log path
CLEANUP_LOG="$OUT/logs/cleanup_$DATE_STAMP.log"

# Start cleanup log
echo "Cleanup started at: $(date)" > "$CLEANUP_LOG"
echo "--------------------------------------------------" >> "$CLEANUP_LOG"

if [[ "$CLEANUP" == "y" || "$CLEANUP" == "Y" ]]; then

    echo "Performing intelligent cleanup..."
    echo "--------------------------------------------------"

    echo "Performing intelligent cleanup..." >> "$CLEANUP_LOG"
    echo >> "$CLEANUP_LOG"

    BASE="$HOME/.network-audit/audits"

    # Current audit
    CURRENT="$DATE_STAMP"

    # Audit used for comparison (if exists)
    COMPARED_AUDIT="$PREVIOUS_AUDIT"

    # Immediately previous audit
    PREVIOUS=$(ls "$BASE" | grep -v "$CURRENT" | sort | tail -n 1)

    echo "Keeping:"
    echo "  - Current audit: $CURRENT"
    echo "  - Immediately previous audit: $PREVIOUS"
    echo "  - Audit used for comparison: $COMPARED_AUDIT"
    echo

    echo "Keeping the following audits:" >> "$CLEANUP_LOG"
    echo "  - Current audit: $CURRENT" >> "$CLEANUP_LOG"
    echo "  - Immediately previous audit: $PREVIOUS" >> "$CLEANUP_LOG"
    echo "  - Audit used for comparison: $COMPARED_AUDIT" >> "$CLEANUP_LOG"
    echo >> "$CLEANUP_LOG"

    for A in $(ls "$BASE"); do
        if [[ "$A" != "$CURRENT" && "$A" != "$PREVIOUS" && "$A" != "$COMPARED_AUDIT" ]]; then
            echo "Removing old audit: $A"
            rm -rf "$BASE/$A"

            echo "Removed old audit: $A" >> "$CLEANUP_LOG"
        fi
    done

    echo >> "$CLEANUP_LOG"
    echo "Cleanup completed successfully." >> "$CLEANUP_LOG"
    echo "--------------------------------------------------" >> "$CLEANUP_LOG"

    echo
    echo "Cleanup completed."
    echo "--------------------------------------------------"

else
    echo "Cleanup skipped by user."
    echo "--------------------------------------------------"

    echo "Cleanup skipped by user." >> "$CLEANUP_LOG"
    echo "--------------------------------------------------" >> "$CLEANUP_LOG"
fi

# ============================================
#  BLOQUE 9 — TECHNICAL REPORT GENERATION
# ============================================

echo
echo "Generating technical report..."

REPORT_DIR="$OUT/reports"

REPORT_TXT="$REPORT_DIR/report_$DATE_STAMP.txt"
REPORT_JSON="$REPORT_DIR/report_$DATE_STAMP.json"

CSV_FILE="$OUT/csv/audit_$DATE_STAMP.csv"
JSON_FILE="$OUT/json/audit_$DATE_STAMP.json"
CHANGES_JSON="$OUT/changes/changes_$DATE_STAMP.json"
ALERTS_JSON="$OUT/alerts/alerts_$DATE_STAMP.json"
CLEANUP_LOG="$OUT/logs/cleanup_$DATE_STAMP.log"
EXEC_LOG="$OUT/logs/execution_$DATE_STAMP.log"

{
    echo "=================================================="
    echo "            NETWORK AUDIT TECHNICAL REPORT"
    echo "=================================================="
    echo
    echo "Audit date: $DATE_STAMP"
    echo "Audit folder: $OUT"
    echo
    echo "--------------------------------------------------"
    echo " 1. SUMMARY OF GENERATED FILES"
    echo "--------------------------------------------------"
    echo "Audit root folder:"
    echo "  $OUT"
    echo
    echo "Folder structure and generated files:"
    echo

    for DIR in discovery manufacturers ports csv json changes alerts logs reports; do
        echo "  $DIR/:"
        if [[ -d "$OUT/$DIR" ]]; then
            find "$OUT/$DIR" -type f | sed 's/^/    - /'
        else
            echo "    (folder not found)"
        fi
        echo
    done

    echo "--------------------------------------------------"
    echo " 2. DEVICE SUMMARY (unique devices)"
    echo "--------------------------------------------------"
    if [[ -f "$CSV_FILE" ]]; then
        awk -F';' 'NR>1 {print $1 "|" $2}' "$CSV_FILE" | sort -u | while IFS='|' read -r IP MAN; do
            echo " - $IP ($MAN)"
        done
    else
        echo "CSV file not found."
    fi
    echo
    echo "--------------------------------------------------"
    echo " 3. PORT SUMMARY (per device)"
    echo "--------------------------------------------------"
    if [[ -f "$JSON_FILE" ]]; then
        jq -r '
            to_entries[] |
            .key as $ip |
            "Device: " + $ip,
            ( .value.ports // [] | map("   - " + (.port|tostring))[] ),
            ""
        ' "$JSON_FILE"
    else
        echo "JSON file not found."
    fi
    echo
    echo "--------------------------------------------------"
    echo " 4. CHANGES DETECTED"
    echo "--------------------------------------------------"
    jq -r '
        "New devices:",
        (.newDevices[]? | " - " + .),
        "",
        "Missing devices:",
        (.missingDevices[]? | " - " + .),
        "",
        "New ports:",
        (.newPorts[]? | " - " + .ip + ": " + (.port|tostring)),
        "",
        "Closed ports:",
        (.closedPorts[]? | " - " + .ip + ": " + (.port|tostring)),
        "",
        "Manufacturer changes:",
        (.manufacturerChanges[]? | " - " + .ip + ": " + .before + " -> " + .after),
        "",
        "Scan type changes:",
        (.scanTypeChanges[]? | " - " + .ip + ": " + .before + " -> " + .after)
    ' "$CHANGES_JSON"
    echo
    echo "--------------------------------------------------"
    echo " 5. ALERTS"
    echo "--------------------------------------------------"
    jq -r '
        "New devices alerts:",
        (.newDevices[]? | " - " + .),
        "",
        "Missing devices alerts:",
        (.missingDevices[]? | " - " + .),
        "",
        "New ports alerts:",
        (.newPorts[]? | " - " + .ip + ": " + (.port|tostring)),
        "",
        "Closed ports alerts:",
        (.closedPorts[]? | " - " + .ip + ": " + (.port|tostring)),
        "",
        "Manufacturer change alerts:",
        (.manufacturerChanges[]? | " - " + .ip + ": " + .before + " -> " + .after),
        "",
        "Scan type change alerts:",
        (.scanTypeChanges[]? | " - " + .ip + ": " + .before + " -> " + .after)
    ' "$ALERTS_JSON"
    echo
    echo "--------------------------------------------------"
    echo " 6. CLEANUP SUMMARY"
    echo "--------------------------------------------------"
    cat "$CLEANUP_LOG"
    echo
    echo "=================================================="
    echo "            END OF TECHNICAL REPORT"
    echo "=================================================="
} > "$REPORT_TXT"

# --------------------------------------------
# Generate JSON report
# --------------------------------------------
jq -n \
    --arg date "$DATE_STAMP" \
    --arg folder "$OUT" \
    --arg csv "$CSV_FILE" \
    --arg json "$JSON_FILE" \
    --arg changes "$CHANGES_JSON" \
    --arg alerts "$ALERTS_JSON" \
    --arg cleanup "$CLEANUP_LOG" \
    --arg exec "$EXEC_LOG" \
    --argjson devices "$(jq '.' "$JSON_FILE")" \
    '
    {
        audit_date: $date,
        audit_folder: $folder,
        files: {
            csv: $csv,
            json: $json,
            changes_json: $changes,
            alerts_json: $alerts,
            cleanup_log: $cleanup,
            execution_log: $exec
        },
        devices: $devices
    }
    ' > "$REPORT_JSON"

echo "Technical report generated:"
echo " - TXT:  $REPORT_TXT"
echo " - JSON: $REPORT_JSON"
echo

# ============================================
#  BLOQUE 10 — FINALIZATION
# ============================================

echo
echo "=================================================="
echo "              AUDIT COMPLETED SUCCESSFULLY"
echo "=================================================="
echo
echo "Audit folder:"
echo "  $OUT"
echo
echo "Technical report generated:"
echo "  - TXT:  $REPORT_TXT"
echo "  - JSON: $REPORT_JSON"
echo
echo "All audit data has been processed, compared, analyzed,"
echo "cleaned, and summarized in the final technical report."
echo
echo "Thank you for using the automatic audit system."
echo "=================================================="
echo
