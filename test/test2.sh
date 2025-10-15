#!/bin/bash

if [ -d "test_dir" ]; then
	sudo umount "test_dir/log"
	rm -rf test_dir
fi

echo "Поведене скрипта, ксли в качестве аргумента передать путь до пустого каталога"
echo "----------------------"
mkdir test_dir

PATHi="$(pwd)/test_dir"

P="/home/artem/artem/akos/scripts"
$P/scr.sh $PATHi 50

echo "---------------------"

