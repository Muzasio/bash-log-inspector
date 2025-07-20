#!/usr/bin/env bash
# PRO Log Inspector (Industry-Ready Edition)
# Bash log analyzer with modular design, CLI flags, JSON export, scrubbing, syslog support, and automation features

# ========== GLOBAL CONFIG ==========
REPORT_DIR="$HOME/log_reports"
TIMESTAMP=$(date '+%Y-%m-%d_%H-%M-%S')
mkdir -p "$REPORT_DIR"
LOG_TARGET=""
MODE="full"
GEN_JSON=false
GEN_SCRUB=false
LOG_FILE=""
VERBOSE=false

# ========== FUNCTIONS ==========
usage() {
cat << EOF
Usage: $0 [OPTIONS]

Options:
  -f FILE       Specify log file to scan (default: ask user if not set)
  -m MODE       Mode: full, minimal, custom, syslog
  -s            Enable scrubbing sensitive data
  -j            Enable JSON export
  -v            Verbose output (debug mode)
  -h            Show this help message and exit

Examples:
  $0 -f /var/log/syslog -m full -s -j
  $0 -m syslog -j
EOF
}

log_info() {
    [[ $VERBOSE == true ]] && echo "[INFO] $1"
    logger -t log_inspector "$1"
}

check_dependencies() {
    command -v jq >/dev/null || { echo "Missing dependency: jq"; exit 1; }
}

setup_paths() {
    REPORT_FILE="$REPORT_DIR/log_report_$TIMESTAMP.txt"
    SCRUBBED_FILE="$REPORT_DIR/log_report_$TIMESTAMP-SAFE.txt"
    JSON_FILE="$REPORT_DIR/log_report_$TIMESTAMP.json"
    HOSTNAME=$(hostname)
    USERNAME=$(whoami)
}

load_log_file() {
    case "$MODE" in
        syslog)
            LOG_FILE="/var/log/syslog"
            ;;
        *)
            if [[ ! -f "$LOG_FILE" ]]; then
                echo "❌ Log file not found: $LOG_FILE"
                exit 1
            fi
            ;;
    esac
}

generate_full_report() {
    echo "🛠️ LOG INSPECTOR PRO (Full Report)" > "$REPORT_FILE"
    echo "🔍 File: $LOG_FILE" >> "$REPORT_FILE"

    echo -e "\n🔐 [SENSITIVE INFO CHECK]" >> "$REPORT_FILE"
    SENSITIVE_HITS=$(grep -iE "$HOSTNAME|$USERNAME" "$LOG_FILE" | tee -a "$REPORT_FILE" | wc -l)

    declare -A CATEGORY_PATTERNS=(
  ["Authentication"]="authentication failure|failed password|invalid user|unauthorized|denied"
  ["Service Failures"]="failed to start|systemd: failed|unit failed|core dumped"
  ["Kernel / Crashes"]="kernel panic|segfault|memory dump|crash"
  ["Network Issues"]="connection refused|host unreachable|dns failure|unreachable"
  ["Proxy Errors"]="proxy error|proxy failure"
  ["Timeouts"]="timeout|timed out"
  ["Permissions"]="permission denied|operation not permitted"
  ["Aborted Jobs"]="aborted|terminated unexpectedly"
)

echo -e "\n🔥 [CATEGORIZED CRITICAL EVENTS]" >> "$REPORT_FILE"

declare -A CATEGORY_COUNTS

# Categorize and count
for category in "${!CATEGORY_PATTERNS[@]}"; do
  pattern="${CATEGORY_PATTERNS[$category]}"
  MATCHES=$(grep -iE "$pattern" "$LOG_FILE" | sort | uniq -c | sort -nr)
  
  if [[ -n "$MATCHES" ]]; then
    COUNT=$(echo "$MATCHES" | wc -l)
    CATEGORY_COUNTS["$category"]=$COUNT
    echo -e "\n📂 $category ($COUNT unique occurrences):" >> "$REPORT_FILE"
    echo "$MATCHES" >> "$REPORT_FILE"
  fi
done

CRIT_COUNT=$(IFS=+; echo "$((${CATEGORY_COUNTS[*]}))")  # Total critical categories


    echo -e "\n📊 [TOP REPEATED LINES]" >> "$REPORT_FILE"
    TOP_LINES=$(sort "$LOG_FILE" | uniq -c | sort -nr | head -20)
    echo "$TOP_LINES" >> "$REPORT_FILE"
    LINE_COUNT=$(echo "$TOP_LINES" | wc -l)

    echo -e "\n🕒 [TIMESTAMP OVERVIEW]" >> "$REPORT_FILE"
    TIME_CLUSTERS=$(grep -oP '\\b\\d{2}:\\d{2}:\\d{2}\\b' "$LOG_FILE" | sort | uniq -c | sort -nr | head -10)
    echo "$TIME_CLUSTERS" >> "$REPORT_FILE"
    TIME_COUNT=$(echo "$TIME_CLUSTERS" | wc -l)
}

generate_scrubbed_report() {
    sed -E "s|$HOME|~|g; s|$USERNAME|user|g; s|$HOSTNAME|your-host|g" "$REPORT_FILE" > "$SCRUBBED_FILE"
}

generate_json_report() {
    jq -n \
        --arg file "$LOG_FILE" \
        --arg full "$REPORT_FILE" \
        --arg safe "$SCRUBBED_FILE" \
        --arg time "$TIMESTAMP" \
        --argjson sensitive "$SENSITIVE_HITS" \
        --argjson critical "$CRIT_COUNT" \
        --argjson top_lines "$LINE_COUNT" \
        --argjson timestamps "$TIME_COUNT" \
        '{
            scanned_file: $file,
            report_time: $time,
            full_report_path: $full,
            scrubbed_report_path: $safe,
            stats: {
                sensitive_hits: $sensitive,
                critical_events: $critical,
                top_repeated_lines: $top_lines,
                timestamp_clusters: $timestamps
            }
        }' > "$JSON_FILE"
}

run_mode() {
    case "$MODE" in
        full)
            generate_full_report
            [[ $GEN_SCRUB == true ]] && generate_scrubbed_report
            [[ $GEN_JSON == true ]] && generate_json_report
            ;;
        minimal)
            echo -e "\n🔥 [CRITICAL EVENTS]" > "$REPORT_FILE"
            grep -iE "fail|error|panic|crash|segfault|fatal|timeout|aborted|unauthorized|denied|terminated|unreachable|core dumped|rejected|invalid user|proxy error" "$LOG_FILE" | sort | uniq >> "$REPORT_FILE"
            ;;
        custom)
            generate_full_report
            [[ $GEN_SCRUB == true ]] && generate_scrubbed_report
            [[ $GEN_JSON == true ]] && generate_json_report
            ;;
        syslog)
            generate_full_report
            [[ $GEN_JSON == true ]] && generate_json_report
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

# ========== MAIN ENTRY ==========
while getopts ":f:m:sjvh" opt; do
  case ${opt} in
    f) LOG_FILE="$OPTARG" ;;
    m) MODE="$OPTARG" ;;
    s) GEN_SCRUB=true ;;
    j) GEN_JSON=true ;;
    v) VERBOSE=true ;;
    h) usage; exit 0 ;;
    :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; usage; exit 1 ;;
  esac
done

check_dependencies
setup_paths
load_log_file
run_mode

log_info "Log inspection complete for file $LOG_FILE"
echo "✅ Done. Report saved to $REPORT_DIR"
[[ $GEN_SCRUB == true ]] && echo "🧼 Scrubbed: $SCRUBBED_FILE"
[[ $GEN_JSON == true ]] && echo "📊 JSON: $JSON_FILE"
