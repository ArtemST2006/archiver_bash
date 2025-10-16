#!/bin/bash


readonly PATH_DIR=$1
PERCENT=$2
N=${3:--1}

mkdir -p "$PATH_DIR/log"
mkdir -p "$PATH_DIR/backup"

mount_point="$PATH_DIR/log"
backup_dir="$PATH_DIR/backup"


if ! mountpoint -q "$mount_point"; then
    	echo "Необходимо примонтировать раздел к папке"
        if [ -n "$(ls -A "$mount_point" 2>/dev/null)" ]; then
	        mkdir -p "$PATH_DIR/tmp_dir"
       	        sudo cp -rp "$mount_point"/* "$PATH_DIR/tmp_dir/" 2>/dev/null
                sudo rm -rf "$mount_point"/*
    	fi

        img_file="$PATH_DIR/log_disk.img"
        sudo dd if=/dev/zero of="$img_file" bs=1M count=20 status=progress
	sudo mkfs.ext4 -F "$img_file"
    	sudo mount -o loop "$img_file" "$mount_point"

        if [ -d "$PATH_DIR/tmp_dir" ]; then
                sudo cp -rp "$PATH_DIR/tmp_dir"/* "$mount_point/" 2>/dev/null
        	sudo rm -rf "$PATH_DIR/tmp_dir"
         
	fi
fi 


CAPACITY=$(df -B 1 "$PATH_DIR/log" | awk 'NR==2 {print $2}')
size_dir=$(du -sb "$mount_point" | cut -f1)
echo "Всего места - $CAPACITY byte"
echo "Занято места - $size_dir byte       $((size_dir * 100 / CAPACITY))%"
echo "всего $(ls -1 "$PATH_DIR/log" | wc -l) фалйов в  log"
echo " "
if [ $size_dir -gt $((CAPACITY * PERCENT / 100)) ]; then
	name="$backup_dir/$(date +%Y-%m-%d_%H-%M-%S-%N).tar"
        tar -cf "$name" --warning=no-file-ignored --files-from /dev/null
else
	echo "без преобразований"
	exit 0
fi 


mapfile -t files < <(find "$mount_point" -type f -printf '%T@ %p\n' | sort -n | cut -d' ' -f2-)

for file_path in "${files[@]}"; do
    if [ "$size_dir" -le "$((CAPACITY * PERCENT / 100))" ]; then
        break
    fi

    tar -rf "$name" --warning=no-file-ignored  "$file_path" 2>/dev/null   
    rm "$file_path"
	
    N=$((N-1))
    if [ $N -eq 0 ]; then
	    echo "Заархивировано $N самый старых фалов"
	    break
    fi

    size_dir=$(du -sb "$mount_point" | cut -f1)
done

echo "Архивация выполнена"
echo "осталось $(ls -1 "$PATH_DIR/log" | wc -l) фалйов после архивации     $((size_dir * 100 / CAPACITY))%"
gzip "$name"

