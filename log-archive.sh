#!/usr/bin/env bash

echo "Привет, я log-archive"
echo "Мне передали: $1"
echo "Всего аргументов: $#"

if [ $# -ne 1 ]; then
    echo "Использование: $0 <папка-с-логами>" >&2
    exit 1
fi