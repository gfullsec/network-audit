flowchart TB

%% ============================================================
%% 1. EXECUTION PIPELINE (ISOLATED, NO CROSS-LINES)
%% ============================================================
subgraph PIPELINE["1. Execution Pipeline"]
    direction TB

    A["Start Audit"]
    B["Block 1: Prepare Environment<br/>Create folders, logs, timestamp"]
    C["Block 2: Network Discovery<br/>ARP + Ping Sweep"]
    D["Block 3: Port Scanning<br/>Quick + Full scans"]
    E["Block 4: CSV Generation<br/>Tabular export"]
    F["Block 5: JSON Generation<br/>Canonical audit JSON"]
    G["Block 6: Mermaid Diagram<br/>Dynamic router detection<br/>Logical network map"]
    H["Block 7: Comparison<br/>Detect changes vs previous audit"]
    I["Block 8: Alerts<br/>TXT + JSON alerts"]
    J["Block 9: Cleanup<br/>Optional retention policy"]
    K["Block 10: Technical Report<br/>TXT + JSON<br/>Folder tree included"]
    L["Block 11: Finalization<br/>Close logs and exit"]

    A --> B --> C --> D --> E --> F --> G --> H --> I --> J --> K --> L

    %% Artifacts (inside the same subgraph to avoid cross-lines)
    subgraph ART["Artifacts"]
        direction TB
        CSV["audit_TIMESTAMP.csv"]
        JSON["audit_TIMESTAMP.json"]
        DIAG["network_logical_TIMESTAMP.mmd"]
        CHG["changes_TIMESTAMP.json/txt"]
        ALT["alerts_TIMESTAMP.json/txt"]
        REP["report_TIMESTAMP.txt/json"]
    end

    E --> CSV
    F --> JSON
    G --> DIAG
    H --> CHG
    I --> ALT
    K --> REP
end


%% ============================================================
%% 2. LAYERED ARCHITECTURE (ISOLATED)
%% ============================================================
subgraph LAYERED["2. Layered Architecture"]
    direction TB

    subgraph L1["Layer 1: Data Acquisition"]
        LA1["Network Discovery"]
        LA2["Manufacturer Lookup"]
        LA3["Port Scanning"]
    end

    subgraph L2["Layer 2: Data Processing"]
        LB1["Normalize Device Data"]
        LB2["Normalize Port Data"]
        LB3["Generate CSV"]
        LB4["Generate JSON"]
    end

    subgraph L3["Layer 3: Analysis & Intelligence"]
        LC1["Logical Diagram Generation"]
        LC2["Comparison Engine"]
        LC3["Alert Engine"]
    end

    subgraph L4["Layer 4: Reporting & Output"]
        LD1["TXT Report"]
        LD2["JSON Report"]
        LD3["Logs"]
    end

    LA1 --> LB1
    LA2 --> LB1
    LA3 --> LB2
    LB1 --> LB4
    LB2 --> LB4
    LB4 --> LC1
    LB4 --> LC2
    LC2 --> LC3
    LC1 --> LD1
    LC2 --> LD1
    LC3 --> LD1
    LD1 --> LD2
    LD2 --> LD3
end


%% ============================================================
%% 3. COMPONENT-ORIENTED ARCHITECTURE (ISOLATED)
%% ============================================================
subgraph COMPONENTS["3. Component-Oriented Architecture"]
    direction TB

    subgraph DISCOVERY["Discovery Component"]
        DC1["ARP Scanner"]
        DC2["Ping Sweep"]
        DC3["Host Collector"]
    end

    subgraph MANUF["Manufacturer Component"]
        MC1["MAC Extractor"]
        MC2["OUI Lookup"]
        MC3["Vendor Resolver"]
    end

    subgraph PORTS["Port Scanning Component"]
        PC1["Quick Scan"]
        PC2["Full Scan"]
        PC3["Port Normalizer"]
    end

    subgraph PROC["Processing Component"]
        PR1["Device Normalizer"]
        PR2["Port Normalizer"]
        PR3["CSV Generator"]
        PR4["JSON Generator"]
    end

    subgraph DIAG["Diagram Component"]
        DG1["Router Detector"]
        DG2["Mermaid Node Builder"]
        DG3["Diagram Generator"]
    end

    subgraph ANALYSIS["Analysis Component"]
        AC1["Comparison Engine"]
        AC2["Change Classifier"]
        AC3["Alert Generator"]
    end

    subgraph REPORT["Reporting Component"]
        RC1["TXT Report Builder"]
        RC2["JSON Report Builder"]
        RC3["Log Writer"]
    end

    DC1 --> MC1
    MC1 --> PC1
    PC1 --> PR1
    PR1 --> DG1
    PR1 --> AC1
    AC1 --> RC1
    DG1 --> RC1
end
