network-audit
Herramienta automatizada de auditoría de red con descubrimiento de hosts, escaneo de puertos, enumeración de servicios y generación estructurada de informes.

network-audit.sh automatiza una auditoría de seguridad en un entorno de red local. Su objetivo es detectar dispositivos activos, identificar fabricantes, analizar puertos relevantes, exportar resultados a CSV y JSON, comparar una auditoría con otra, generar alertas de cambios y dejar el entorno preparado para mantenimiento y seguimiento. Es una herramienta diseñada para auditar y revisar infraestructura visible en una red local, pensada para uso práctico y diagnóstico de cambios.

Qué hace el script, bloque por bloque
Bloque 1 — Preparación del entorno
Este bloque prepara la estructura de trabajo para la auditoría actual. Acciones: crea el directorio base de auditorías en $HOME/Documentos/seguridad/auditorias; crea una carpeta específica para la auditoría actual usando la fecha y hora; genera subdirectorios para descubrimiento, fabricantes, puertos, csv, json, cambios, logs y alertas. También imprime la fecha y la ruta de la auditoría en curso.

Bloque 2 — Descubrimiento de red + Fabricantes
Este bloque realiza el reconocimiento inicial de la red. Pasos: muestra las interfaces IPv4 activas; solicita al usuario que seleccione una; calcula la red asociada; permite confirmarla o introducir otra manualmente; ejecuta un escaneo de hosts con Nmap usando: nmap -sn -PR "$NETWORK" -oN "$DESC_FILE". Luego usa arp-scan para detectar dispositivos activos y relacionar IPs con direcciones MAC y fabricantes: sudo arp-scan --interface="$IFACE" "$NETWORK". Los resultados se procesan para obtener IP → MAC(s) y IP+MAC → fabricante. Se prioriza una MAC/fabricante por IP. El resultado final se guarda en fabricantes/fabricantes_YYYY-MM-DD_HH-MM-SS.txt.

Bloque 3 — Escaneo de puertos
Este bloque procesa los hosts detectados y decide si ejecutar un escaneo rápido o profundo. Lógica: lee las IPs del descubrimiento; busca el fabricante; decide el tipo de escaneo; ejecuta escaneo rápido (nmap -Pn --top-ports 100) o profundo (nmap -A -p-). Los resultados se guardan en puertos/<fecha>/ con un archivo por IP.

Bloque 4 — Generación de CSV
Convierte los resultados del escaneo de puertos en un archivo CSV: csv/auditoria_YYYY-MM-DD_HH-MM-SS.csv. Cabecera: "IP";"Manufacturer";"Port";"Service";"State";"ScanType";"Date". Para cada archivo de puertos: extrae la IP; busca el fabricante; normaliza el nombre; identifica el tipo de escaneo; incluye solo estados válidos (open, closed, filtered); genera una fila por puerto. Si no hay puertos válidos, escribe N/A y no_open_ports.

Bloque 5 — Generación de JSON (Agrupado por IP)
Crea json/auditoria_YYYY-MM-DD_HH-MM-SS.json. Cada entrada por IP incluye fabricante, scanType, fecha y puertos. Ejemplo: {"192.168.1.10":{"manufacturer":"Dell","scanType":"deep","date":"2026-08-29_20-28-46","ports":[{"port":22,"service":"ssh","state":"open"}]}}. Lógica: leer CSV; limpiar campos; crear entrada de IP si no existe; añadir puertos.

Bloque 6 — Comparación con auditorías anteriores
Compara la auditoría actual con una previa. Acciones: lista auditorías anteriores; solicita al usuario seleccionar una; comprueba si contiene JSON válido; compara dispositivos nuevos, dispositivos desaparecidos, puertos nuevos, puertos cerrados, cambios de fabricante y cambios de tipo de escaneo. Resultados en cambios/cambios_YYYY-MM-DD_HH-MM-SS.txt y cambios/cambios_YYYY-MM-DD_HH-MM-SS.json.

Bloque 7 — Generación de alertas
Genera alertas basadas en los cambios detectados. Archivos: alertas/alertas_YYYY-MM-DD_HH-MM-SS.txt y alertas/alertas_YYYY-MM-DD_HH-MM-SS.json. Las alertas incluyen: dispositivos nuevos, dispositivos desaparecidos, puertos nuevos, puertos cerrados, cambios de fabricante y cambios de tipo de escaneo. El TXT incluye secciones como [ALERTA] Nuevo dispositivo: ... El JSON almacena la misma información de forma estructurada.

Bloque 8 — Limpieza inteligente
Pregunta si se deben limpiar auditorías antiguas. Si se confirma: conserva la auditoría actual, la inmediatamente anterior y la usada para comparación; elimina el resto. Objetivo: ahorrar espacio y mantener solo referencias relevantes.

Bloque 9 — Resumen final y cierre
Imprime un resumen final: ubicación de la auditoría, archivos generados, ruta del log y mensaje de cierre.

Tecnologías y herramientas utilizadas
Bash, Nmap, arp-scan, jq, ip, grep, awk, sed, cut, xargs.

Para qué sirve este script
Detectar dispositivos activos; determinar fabricantes; identificar puertos abiertos y servicios; documentar infraestructura con CSV/JSON; comparar auditorías; detectar cambios; generar alertas básicas de seguridad.

Estructura final de salida
~/Documentos/seguridad/auditorias/
└── YYYY-MM-DD_HH-MM-SS/
├── descubrimiento/
├── fabricantes/
├── puertos/
├── csv/
├── json/
├── cambios/
├── alertas/
├── logs/
└── resumen_final

Limitaciones
Depende de permisos del sistema/red; requiere nmap, arp-scan y jq; la detección de fabricantes puede ser aproximada; la comparación requiere un JSON previo válido; la detección se basa en cadenas parseadas y heurísticas.

Consideraciones legales y éticas
Usar solo en entornos autorizados para auditoría, administración o seguridad de infraestructura propia. No escanear redes o sistemas sin consentimiento explícito.
