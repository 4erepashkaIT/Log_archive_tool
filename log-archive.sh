#!/usr/bin/env bash
set -euo pipefail
ARCHIVE_DIR="$HOME/projects/Log_archive_tool/archives"
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

echo "Папка с логами найдена: $LOG_DIR"

mkdir -p "$ARCHIVE_DIR"
echo "Папка с архивами: $ARCHIVE_DIR"

tar -czf "$ARCHIVE_DIR/$ARCHIVE_NAME" -C "$(dirname "$LOG_DIR")" "$(basename "$LOG_DIR")"
t_exit_code=$?

if  $t_exit_code; then
    ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE_DIR/$ARCHIVE_NAME")
    echo "$(date '+%Y-%m-%d %H:%M:%S') | $LOG_DIR -> $ARCHIVE_NAME | Размер архива: $ARCHIVE_SIZE байт | OK" >> "$ARCHIVE_DIR/archive.log"
else
    if [ $t_exit_code == 1 ]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $LOG_DIR -> $ARCHIVE_NAME | Размер архива: $ARCHIVE_SIZE байт | Ошибка прав" >> "$ARCHIVE_DIR/archive.log"
    else
        echo "$(date '+%Y-%m-%d %H:%M:%S') | $LOG_DIR -> $ARCHIVE_NAME | Размер архива: $ARCHIVE_SIZE байт | Архив создан, возможно с предупреждением" >> "$ARCHIVE_DIR/archive.log"
    fi
fi