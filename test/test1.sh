#!/bin/bash

readonly LOG_DIR="test_dir/log"
FILE_SIZE=${1:-100}

echo "Тест выполняет 2 проверки: случай, где нужна архивация и где не нужна"

zpln() {
	total_size=$(df -B 1 "$LOG_DIR" | awk 'NR==2 {print $2}')
	target_size=$((total_size / 2))
	file_size=1024*$FILE_SIZE 
	count=$((target_size / file_size))

	echo "Общий размер: $total_size байт"
	echo "Целевой размер: $target_size байт"

	for ((i=0; i<=count; i++)); do
    		dd if=/dev/zero of="test_dir/log/file$i.txt" bs=1024 count=$FILE_SIZE status=none
	done

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

P="/home/artem/artem/akos/scripts"

echo "=== Тест 1: Порог 70% ==="
zpln
echo "Заполнили папку на ~50%; Запускаем скрипт с порогом 70%"
echo "Ожидание: архивация НЕ должна сработать"
echo "---------------------------------"
$P/scr.sh test_dir 70
echo "---------------------------------"
echo ""

echo "=== Тест 2: Порог 40% ==="
zpln
echo "Заполнили папку на ~50%; Запускаем скрипт с порогом 40%"
echo "Ожидание: архивация ДОЛЖНА сработать"
echo "---------------------------------"
$P/scr.sh test_dir 40
echo "---------------------------------"

echo "=== Тест 3: Порог 40% с параметром 30 ==="
zpln
echo "Заполнили папку на ~50%; Запускаем скрипт с порогом 40% и дополнительным параметром 30"
echo "Ожидание: архивация ДОЛЖНА сработать с дополнительным параметром"
echo "---------------------------------"
$P/scr.sh test_dir 40 30
echo "---------------------------------"






