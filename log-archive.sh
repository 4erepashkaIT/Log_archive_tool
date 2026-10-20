#!/usr/bin/env bash

if [ $# -ne 1 ]; then
    echo "Использование: $0 <папка-с-логами>" >&2
    exit 1
fi

LOG_DIR="$1"

if [ ! -d "$LOG_DIR" ]; then
    echo "Такой папки не существует: $LOG_DIR" >&2
    exit 1
fi

echo "Папка с логами найдена: $LOG_DIR"