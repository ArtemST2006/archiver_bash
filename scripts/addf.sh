#!/bin/bash

TARGET_DIR="$1"
FILE_SIZE_KB="$2"
TARGET_PERCENT="$3"

if ! mountpoint -q "$TARGET_DIR"; then
	echo "no"
	exit 1;
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "no"
	exit 1
fi

if ! [[ "$FILE_SIZE_KB" =~ ^[0-9]+$ ]] || [ "$FILE_SIZE_KB" -lt 1 ]; then
    exit 1
fi

if ! [[ "$TARGET_PERCENT" =~ ^[0-9]+$ ]] || [ "$TARGET_PERCENT" -lt 1 ] || [ "$TARGET_PERCENT" -gt 95 ]; then
    exit 1
fi

fill_partition() {
    local dir="$1"
    local file_size_kb="$2"
    local target_percent="$3"
    
    local df_output=$(df -B 1 "$dir" 2>/dev/null | awk 'NR==2')
    if [ -z "$df_output" ]; then
        return 1
    fi
    
    local total_bytes=$(echo "$df_output" | awk '{print $2}')
    local used_bytes=$(echo "$df_output" | awk '{print $3}')
    local available_bytes=$(echo "$df_output" | awk '{print $4}')
    
    local current_percent=$((used_bytes * 100 / total_bytes))
    
    if [ "$current_percent" -ge "$target_percent" ]; then
        return 0
    fi
    
    local target_used_bytes=$((total_bytes * target_percent / 100))
    local needed_bytes=$((target_used_bytes - used_bytes))
    
    local safe_available_bytes=$((available_bytes * 98 / 100))
    if [ "$needed_bytes" -gt "$safe_available_bytes" ]; then
        needed_bytes="$safe_available_bytes"
    fi
    
    local file_bytes=$((file_size_kb * 1024))
    local file_count=$((needed_bytes / file_bytes))
    
    if [ "$file_count" -eq 0 ] && [ "$needed_bytes" -gt 0 ]; then
        file_count=1
        file_size_kb=$(( (needed_bytes + 1023) / 1024 ))
        file_bytes=$((file_size_kb * 1024))
    fi
    
    if [ "$file_count" -eq 0 ]; then
        return 0
    fi
    
    local success_count=0
    for ((i=1; i<=file_count; i++)); do
        local filename="${dir}/fill_file_$(date +%s%N)_${i}.dat"
        
        if dd if=/dev/zero of="$filename" bs=1024 count="$file_size_kb" status=none 2>/dev/null; then
            success_count=$((success_count + 1))
        else
            break
        fi
    done
}


main() {
    fill_partition "$TARGET_DIR" "$FILE_SIZE_KB" "$TARGET_PERCENT"
}

main
