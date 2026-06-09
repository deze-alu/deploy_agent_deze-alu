#!/bin/bash
#
# Summative Lab - Student Attendance Tracker
# setup_project.sh
#
set -euo pipefail

# Global state
input=""
project=""

# Color setup. 
# Code gotten from: https://unix.stackexchange.com/a/249379
if [[ -t 1 ]]; then
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[1;33m'
    RED=$'\033[0;31m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    GREEN='' YELLOW='' RED='' BLUE='' BOLD='' RESET=''
fi

# Tiny print helpers so each message states its intent and the color/reset
# logic lives in exactly one place.
success() { echo "${GREEN}$*${RESET}"; }
warn()    { echo "${YELLOW}$*${RESET}"; }
info()    { echo "${BLUE}$*${RESET}"; }
err()     { echo "${RED}$*${RESET}" >&2; }

cleanup() {
  warn "Interrupt received. Rolling back..."
  if [[ -n "$project" && -d "$project" ]]; then
    local archive="${project}_archive"
    info "Archiving partial workspace to ${archive}..."
    tar -czf "$archive" "$project"
    info "Removing incomplete directory ${project}..."
    rm -rf "$project"
    success "Rollback complete. Snapshot saved as ${archive}."
  else
    warn "No workspace created yet. Nothing to clean up."
  fi
  exit 1
}

get_suffix_input() {
  read -rp "Enter a name for this project workspace: " input
  if [[ -z "$input" ]]; then
    err "No name supplied. Aborting."
    exit 1
  fi

  project="attendance_tracker_${input}"
  if [[ -e "$project" ]]; then
    err "A path named '$project' already exists. Please choose another name."
    exit 1
  fi
}

build_directory_structure() {
  info "Creating workspace '$project'..."
  mkdir -p "$project/Helpers" "$project/reports"
  success "Directory structure created at ${project}/"
}

generate_source_files() {
    cat > "$project/attendance_checker.py" << 'PYEOF'
import csv
import json
import os
from datetime import datetime

def run_attendance_check():
    # 1. Load Config
    with open('Helpers/config.json', 'r') as f:
        config = json.load(f)

    # 2. Archive old reports.log if it exists
    if os.path.exists('reports/reports.log'):
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        os.rename('reports/reports.log', f'reports/reports_{timestamp}.log.archive')

    # 3. Process Data
    with open('Helpers/assets.csv', mode='r') as f, open('reports/reports.log', 'w') as log:
        reader = csv.DictReader(f)
        total_sessions = config['total_sessions']

        log.write(f"--- Attendance Report Run: {datetime.now()} ---\n")

        for row in reader:
            name = row['Names']
            email = row['Email']
            attended = int(row['Attendance Count'])

            # Simple Math: (Attended / Total) * 100
            attendance_pct = (attended / total_sessions) * 100

            message = ""
            if attendance_pct < config['thresholds']['failure']:
                message = f"URGENT: {name}, your attendance is {attendance_pct:.1f}%. You will fail this class."
            elif attendance_pct < config['thresholds']['warning']:
                message = f"WARNING: {name}, your attendance is {attendance_pct:.1f}%. Please be careful."

            if message:
                if config['run_mode'] == "live":
                    log.write(f"[{datetime.now()}] ALERT SENT TO {email}: {message}\n")
                    print(f"Logged alert for {name}")
                else:
                    print(f"[DRY RUN] Email to {email}: {message}")

if __name__ == "__main__":
    run_attendance_check()
PYEOF

    cat > "$project/Helpers/assets.csv" << 'CSVEOF'
Email,Names,Attendance Count,Absence Count
alice@example.com,Alice Johnson,14,1
bob@example.com,Bob Smith,7,8
charlie@example.com,Charlie Davis,4,11
diana@example.com,Diana Prince,15,0
CSVEOF

    cat > "$project/Helpers/config.json" << 'JSONEOF'
{
    "thresholds": {
        "warning": 75,
        "failure": 50
    },
    "run_mode": "live",
    "total_sessions": 15
}
JSONEOF

    cat > "$project/reports/reports.log" << 'LOGEOF'
--- Attendance Report Run: 2026-02-06 18:10:01.468726 ---
[2026-02-06 18:10:01.469363] ALERT SENT TO bob@example.com: URGENT: Bob Smith, your attendance is 46.7%. You will fail this class.
[2026-02-06 18:10:01.469424] ALERT SENT TO charlie@example.com: URGENT: Charlie Davis, your attendance is 26.7%. You will fail this class.
LOGEOF

    success "Source files generated."
}

set_attendance_thresholds() {
  local warning_threshold prompt_answer failure_threshold config_path="$project/Helpers/config.json"

  read -rp "Do you want to update the attendance thresholds? (y/N) " prompt_answer
  if [[ "$prompt_answer" =~ ^[Yy]$ ]]; then
    read -rp "Enter warning threshold percentage (default 75): " warning_threshold
    read -rp "Enter failure threshold percentage (default 50): " failure_threshold

    # Set defaults if input is empty
    warning_threshold=${warning_threshold:-75}
    failure_threshold=${failure_threshold:-50}

    # Validate inputs
    if ! [[ "$warning_threshold" =~ ^[0-9]+$ ]] || ! [[ "$failure_threshold" =~ ^[0-9]+$ ]]; then
      err "Invalid input. Thresholds must be numeric."
      return
    fi

    if (( warning_threshold <= failure_threshold )); then
      err "Warning threshold must be greater than failure threshold."
      return
    fi

    # Update config.json
    if [[ -f "$config_path" ]]; then
      sed -i.bak -E "s/\"warning\": [0-9]+/\"warning\": $warning_threshold/" "$config_path"
      sed -i.bak -E "s/\"failure\": [0-9]+/\"failure\": $failure_threshold/" "$config_path"
      rm "${config_path}.bak"
      success "Thresholds updated in config.json. (Warning: $warning_threshold%, Failure: $failure_threshold%)"
    else
      err "Config file not found at $config_path. Cannot update thresholds."
    fi
  
  else
    info "No changes made to thresholds. Using defaults (Warning: 75%, Failure: 50%)."
  fi
}

health_checks() {
  info "Checking for Python 3 installation..."
  if python3 --version &>/dev/null; then
    success "Python 3 is installed."
  else
    err "Python 3 is not installed. Please install it to run the attendance checker."
    exit 1
  fi

  info "Verifying application directory structure..."
  local required_dirs=("$project" "$project/Helpers" "$project/reports")
  local required_files=("$project/attendance_checker.py" "$project/Helpers/assets.csv" "$project/Helpers/config.json")

  for dir in "${required_dirs[@]}"; do
    if [[ -d "$dir" ]]; then
      info "Directory '$dir' exists."
    else
      err "Directory '$dir' is missing. Please run the setup script again."
      exit 1
    fi
  done

  for file in "${required_files[@]}"; do
    if [[ -f "$file" ]]; then
      info "File '$file' exists."
    else
      err "File '$file' is missing. Please run the setup script again."
      exit 1
    fi
  done
}

main() {
    trap cleanup SIGINT

    get_suffix_input
    build_directory_structure
    generate_source_files

    sleep 2
    set_attendance_thresholds
    health_checks

    success "Project setup complete! You can now run the attendance checker with: python3 $project/attendance_checker.py"
}


# Run the main function with all arguments passed
main "$@"