#!/usr/bin/env bash

set -euo pipefail

if [ "$EUID" -ne 0 ]; then
    echo "Ошибка: этот скрипт должен быть запущен с правами root (sudo)." >&2
    exit 1
fi

ARCHIVE_DIR="/var/log-archive"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_TIME=$(date '+%Y-%m-%d %H:%M:%S')
ARCHIVE_NAME="logs_archive_${TIMESTAMP}.tar.gz"

cleanup_old_archives() {
    DELETED_COUNT=$(find "$ARCHIVE_DIR" -maxdepth 1 -type f \
        -name "logs_archive_*.tar.gz" \
        -mtime +"$RETENTION_DAYS" \
        -print -delete | wc -l)
    echo "Удалено архивов старше $RETENTION_DAYS дней: $DELETED_COUNT"
    echo "$LOG_TIME | Удалено архивов старше $RETENTION_DAYS дней: $DELETED_COUNT | OK" >> "$ARCHIVE_DIR/archive.log"
}

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

if tar -czf "$ARCHIVE_DIR/$ARCHIVE_NAME" \
    -C "$(dirname "$LOG_DIR")" \
    "$(basename "$LOG_DIR")"; then

    ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE_DIR/$ARCHIVE_NAME")

    echo "$LOG_TIME | $LOG_DIR -> $ARCHIVE_NAME | Размер архива: $ARCHIVE_SIZE байт | OK" >> "$ARCHIVE_DIR/archive.log"

    echo "Архив успешно создан: $ARCHIVE_NAME"

    cleanup_old_archives()

else
    T_EXIT_CODE=$?

    if [ "$T_EXIT_CODE" -eq 1 ]; then
        ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE_DIR/$ARCHIVE_NAME")
        echo "$LOG_TIME | $LOG_DIR -> $ARCHIVE_NAME | Размер архива: $ARCHIVE_SIZE байт | WARNING: файлы изменились при архивации" >> "$ARCHIVE_DIR/archive.log"
        echo "Предупреждение: файлы изменились при архивации (код 1). Архив сохранён: $ARCHIVE_NAME"
        exit 0
    else
        rm -f "$ARCHIVE_DIR/$ARCHIVE_NAME"
        echo "$LOG_TIME | $LOG_DIR -> $ARCHIVE_NAME | Ошибка tar: код $T_EXIT_CODE | Неполный архив удалён" >> "$ARCHIVE_DIR/archive.log"
        echo "Ошибка tar: код $T_EXIT_CODE. Неполный архив удалён: $ARCHIVE_NAME" >&2
        exit "$T_EXIT_CODE"
    fi
fi
