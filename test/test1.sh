#!/bin/bash

readonly LOG_DIR="test_dir/log"

echo "Тест выполняет 2 проверки: случай, где нужна архивация и где не нужна"

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

total_size=$(df -B 1 "$LOG_DIR" | awk 'NR==2 {print $2}')
target_size=$((total_size / 2))
file_size=102400 
count=$((target_size / file_size))

echo "Общий размер: $total_size байт"
echo "Целевой размер: $target_size байт"

for ((i=0; i<=count; i++)); do
    dd if=/dev/zero of="test_dir/log/file$i.txt" bs=1024 count=100 status=none
done

echo "Заполнили папку на 50 процентов;"
echo "Запустили скрипт с аргументом 70%"
echo "---------------------------------"
P="/home/artem/artem/akos/scripts"
$P/scr.sh test_dir 70 
echo "---------------------------------"
echo " "
echo "Запустили скрипт с аргументом 40%"
echo "---------------------------------"
P="/home/artem/artem/akos/scripts"
$P/scr.sh test_dir 40
echo "---------------------------------"






