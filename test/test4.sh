#!/bin/bash


echo "тест на производителность"
size_f=${1:-100}

add_files () {
	local dir="test_dir/log"

    	read total used available <<< $(df -B 1 "$dir" | awk 'NR==2 {print $2, $3, $4}')

    	target_used=$((total * 90 / 100))
    	needed_bytes=$((target_used - used))
    	file_bytes=$((size_f * 1024))
    	count=$(( (needed_bytes + file_bytes - 1) / file_bytes ))
   
    	for ((i=0; i<count; i++)); do
        	filename="$dir/file$(date +%s%N)$i.txt"
        	dd if=/dev/zero of="$filename" bs=1024 count=$size_f status=none
    	done
}

run_script() {
	local pr=$1
	local PATH_SC="/home/artem/artem/akos/scripts/scr.sh"
	local PATH_DIR="$(pwd)/test_dir"
	add_files
	
	echo ""
	echo "------------------"
	local start_time=$(date +%s.%N)
	"$PATH_SC" "$PATH_DIR" "$pr"
	local end_time=$(date +%s.%N)
	local duration=$(echo "$end_time - $start_time" | bc)
	echo "------------------"
	echo "для $pr% - $duration"
}


if [ -d "test_dir" ]; then
	sudo umount "test_dir/log"
	rm -rf test_dir
fi

mkdir test_dir
mkdir test_dir/log test_dir/backup

img_file="test_dir/log_disk.img"
sudo dd if=/dev/zero of="$img_file" bs=1M count=20 status=progress
sudo mkfs.ext4 -F "$img_file"
sudo mount -o loop "$img_file" "test_dir/log"

run_script 0
run_script 25
run_script 50
run_script 75
run_script 100


