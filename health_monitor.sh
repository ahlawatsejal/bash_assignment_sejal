#!/bin/bash

LOG_FILE="/var/log/health_monitor.log"
SERVICE_FILE="services.txt"
DRY_RUN=false

# Check for dry-run flag
if [[ "$1" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# Error handling
if [[ ! -f "$SERVICE_FILE" ]]; then
    echo "Error: services.txt file not found!"
    exit 1
fi

if [[ ! -s "$SERVICE_FILE" ]]; then
    echo "Error: services.txt is empty!"
    exit 1
fi

# Counters
total=0
healthy=0
recovered=0
failed=0

# Logging function
log_event() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp [$1] $2" | sudo tee -a "$LOG_FILE" > /dev/null
}

echo "--------------------------------------"
echo "Service Health Monitor Started"
echo "User: $(whoami) | Host: $(hostname)"
echo "--------------------------------------"

while read -r service; do
    ((total++))

    status=$(systemctl is-active "$service" 2>/dev/null)

    if [[ "$status" == "active" ]]; then
        echo -e "\e[32m✔ $service is running\e[0m"
        ((healthy++))
    else
        echo -e "\e[31m✖ $service is NOT running\e[0m"

        if [[ "$DRY_RUN" == true ]]; then
            echo "[DRY-RUN] Would restart $service"
            log_event "INFO" "$service simulated restart"
            ((failed++))
        else
            echo "Attempting restart..."
            sudo systemctl restart "$service"

            sleep 5

            new_status=$(systemctl is-active "$service" 2>/dev/null)

            if [[ "$new_status" == "active" ]]; then
                echo -e "\e[32m✔ $service RECOVERED\e[0m"
                log_event "RECOVERED" "$service restarted successfully"
                ((recovered++))
            else
                echo -e "\e[31m✖ $service FAILED\e[0m"
                log_event "FAILED" "$service could not be restarted"
                ((failed++))
            fi
        fi
    fi

    echo "--------------------------------------"

done < "$SERVICE_FILE"

echo ""
echo "========= SUMMARY ========="
echo "Total Checked : $total"
echo "Healthy       : $healthy"
echo "Recovered     : $recovered"
echo "Failed        : $failed"
echo "==========================="
