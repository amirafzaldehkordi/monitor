#!/bin/bash

# Function to check CPU and Memory usage
check_cpu_and_memory_usage() {
    echo "========== CPU and Memory Usage =========="
    # Extract CPU and Memory usage information from top
    top -b -n1 | awk '
    /%Cpu/ {printf "CPU Usage: %.2f%%\n", $2 + $4}
    /^MiB Mem :/ || /^KiB Mem :/ {
        used=$6; total=$4; 
        printf "Used Memory: %.2f %s / Total Memory: %.2f %s (%.2f%%)\n", used, $5, total, $3, (used/total)*100
    }
    '
}

# Function to check Disk usage
check_disk_usage() {
    echo "========== Disk Usage =========="
    df -h | awk 'NR==1 || $NF == "/" {printf "%-20s %-10s %-10s %-10s %-10s\n", $1, $2, $3, $4, $5}'
    echo
}
# Function to check disk usage and report partitions over 70% usage
check70_disk_usage() {
    partitions=$(df -h --output=target,pcent | grep -vE '^Filesystem' | awk '{if ($2+0 > 70) print $1 " is " $2 " full."}')

    if [ -n "$partitions" ]; then
        echo "$partitions"
    else
        echo "No partition other than / is more than 70% used."
    fi
    echo
}

# Function to check Network speed using Speedtest
#check_network_speed() {
#    echo "---- Network Speed ----"
#    
#    # Check if speedtest-cli is available
#    if command -v speedtest-cli &>/dev/null; then
#        # Run Speedtest and capture download and upload speeds
#        speedtest-cli --simple | awk -F ': ' '
#        /Download/ {printf "Download Speed: %s\n", $2}
#        /Upload/ {printf "Upload Speed: %s\n", $2}
#        '
#    else
#        echo "Speedtest-cli is not installed on this server. Please install it to check network speed."
#    fi
#    echo
#}

# Function to list high-usage processes
list_high_usage_processes() {
    echo "========== High-Usage Processes =========="
    echo "Processes using >50% CPU or >50% Memory:"
    # Adjust the thresholds for CPU and Memory to 50%
    ps aux --sort=-%cpu,-%mem | awk '$3 > 50 || $4 > 50 {printf "%-10s %-8s %-8s %-8s %-s\n", $1, $2, $3, $4, $11}'
    echo
}

# Function to check service statuses
check_service_statuses() {
    echo "========== Service Statuses =========="
    
    services=("nginx" "apache2" "mysql" "postgresql" "sshd" "ssh" \
    "powerdns" "pureftpd" "pop" "mariadb" "lfd" "imap" "httpd" \
    "exim" "cpsrvd" "cpanel" "directadmin" "lsws")

    not_running=()
    running=()

    for service in "${services[@]}"; do
        if systemctl list-units --type=service | grep -q -E "($service|$service\.service)"; then
            if systemctl is-active --quiet "$service"; then
                running+=("$service: Running")
            else
                not_running+=("$service: Not Running")
            fi
        fi
    done

    if [ ${#not_running[@]} -gt 0 ]; then
        for service in "${not_running[@]}"; do
            echo "$service"
        done
    fi

    if [ ${#running[@]} -gt 0 ]; then
        for service in "${running[@]}"; do
            echo "$service"
        done
    fi
    echo
}
# Function to check server load and compare to CPU cores
check_server_load() {
    echo "==========      Server Load     =========="
    load=$(uptime | awk -F 'load average:' '{print $2}' | cut -d, -f1 | xargs)
    cores=$(nproc)
    echo "Load Averages (1, 5, 15 min): $(uptime | awk -F 'load average:' '{print $2}')"
    echo "CPU Cores: $cores"

    # Compare load to cores
    if (( $(echo "$load > $cores" | bc -l) )); then
        echo "WARNING: 1-minute load average ($load) exceeds the number of CPU cores ($cores)!"
    else
        echo "1-minute load average is within the safe range."
    fi
    echo
}

# Function to check swap usage
check_swap_usage() {
    swap_info=$(free -h | grep -i swap)
    total_swap=$(echo $swap_info | awk '{print $2}')
    
    if [ "$total_swap" = "0" ] || [ -z "$total_swap" ]; then
        echo "Swap is not configured."
    else
        used_swap=$(echo $swap_info | awk '{print $3}')
        swap_percentage=$(free | grep -i swap | awk '{if ($2>0) printf("%.2f", $3/$2 * 100)}')
        echo "Swap: $used_swap of $total_swap used ($swap_percentage% used)"
    fi
    echo
}

echo ---------------------------------------------------------------------- 
list_high_usage_processes
check_disk_usage
check70_disk_usage
#check_network_speed
check_server_load
check_cpu_and_memory_usage
check_swap_usage
check_service_statuses
echo ---------------------------------------------------------------------- 
