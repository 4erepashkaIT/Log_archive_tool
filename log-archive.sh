#!/usr/bin/env bash
ARCHIVE_DIR="$HOME/projects/Log_archive_tool"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="logs_archive_${TIMESTAMP}.tar.gz"

if [ $# -ne 1 ]; then
    echo "Использование: $0 <папка-с-логами>" >&2
    exit 1
fi

LOG_DIR="$1"

if [ ! -d "$LOG_DIR" ]; then
    echo "Такой папки не существует: $LOG_DIR" >&2
    exit 1
fi

mkdir -p "$ARCHIVE_DIR"

echo "Папка с логами найдена: $LOG_DIR"
echo "Имя архива: $ARCHIVE_NAME"