#!/bin/bash

log_file="$1"
ntfy_log_path="$2"

if [ ! -f "$log_file" ]; then
    usage
    exit 1
fi

usage() {
    echo "Usage: $0 <log_file> <ntfy_log_path>"
    echo "Example: $0 /var/log/requests_import.log ntfy.log"
}

echo "Logs import summary" > $ntfy_log_path
echo "-------------------" >> $ntfy_log_path

requests_imported=$(grep "requests imported successfully" "$log_file" | awk '{print $1}')
echo "$requests_imported requests importe1d successfully" >> $ntfy_log_path

download_requests=$(grep "requests were downloads" "$log_file" | awk '{print $1}')
echo "  $download_requests requests were downloads" >> $ntfy_log_path

ignored_requests=$(grep "requests ignored" "$log_file" | awk '{print $1}')
echo "  $ignored_requests requests were ignored :" >> $ntfy_log_path

print_non_zero() {
    if [ -n "$1" ] && [ "$1" -ne 0 ]; then
        echo "      $1 $2" >> $ntfy_log_path
    fi
}

extract_value() {
    grep "$2" "$1" | awk '{print $1}'
}

conditions=(
    "HTTP errors"
    "HTTP redirects"
    "invalid log lines"
    "filtered log lines"
    "requests did not match any known site"
    "requests did not match any --hostname"
    "requests done by bots, search engines..."
    "requests to static resources"
    "requests to file downloads did not match any --download-extensions"
)

for condition in "${conditions[@]}"; do
    value=$(extract_value "$log_file" "$condition")
    print_non_zero "$value" "$condition"
done

echo -e "\nWebsite import summary" >> $ntfy_log_path
echo "----------------------" >> $ntfy_log_path

total_requests_sites=$(grep "requests imported to" "$log_file" | awk '{print $1}')
echo "$total_requests_sites requests imported to sites" >> $ntfy_log_path

existing_sites=$(grep "sites already existed" "$log_file" | awk '{print $1}')
created_sites=$(grep "sites were created" "$log_file" | awk '{print $1}')
distinct_hostnames=$(grep "distinct hostnames" "$log_file" | awk '{print $1}')

print_non_zero "$existing_sites" "sites already existed"
print_non_zero "$created_sites" "sites were created"
print_non_zero "$distinct_hostnames" "distinct hostnames"

echo -e "\nPerformance summary" >> $ntfy_log_path
echo "-------------------" >> $ntfy_log_path

total_time=$(grep "Total time:" "$log_file" | awk '{print $3}')
requests_per_second=$(grep "Requests imported per second" "$log_file" | awk '{print $5}')

echo "Total time: $total_time seconds" >> $ntfy_log_path
echo "Requests imported per second: $requests_per_second requests per second" >> $ntfy_log_path