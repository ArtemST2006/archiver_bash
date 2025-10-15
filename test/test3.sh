#!/bin/bash

PATH_DIR="$(pwd)"

if [ -d "test_dir" ]; then
	sudo umount "test_dir/log"
	rm -rf test_dir
fi 

echo "Поведение при передче каталога, в котором не смонтирован раздел к log"

mkdir "test_dir"
mkdir "test_dir/log"
mkdir "test_dir/backup"

PATHi="test_dir"

echo "---------------------"

P="/home/artem/artem/akos/scripts"
$P/scr.sh $PATHi 50

echo "---------------------"




