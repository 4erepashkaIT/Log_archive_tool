
#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_DIR="/var/log-archive"
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

if tar -czf "$ARCHIVE_DIR/$ARCHIVE_NAME" \
    -C "$(dirname "$LOG_DIR")" \
    "$(basename "$LOG_DIR")"; then

    ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE_DIR/$ARCHIVE_NAME")

    echo "$(date '+%Y-%m-%d %H:%M:%S') | $LOG_DIR -> $ARCHIVE_NAME | Размер архива: $ARCHIVE_SIZE байт | OK" >> "$ARCHIVE_DIR/archive.log"

    echo "Архив успешно создан: $ARCHIVE_NAME"

else
    t_exit_code=$?

    if [ "$t_exit_code" -eq 1 ]; then
        STATUS="Предупреждение: файлы изменились при архивации"
    else
        STATUS="Ошибка tar: код $t_exit_code"
    fi

    echo "$(date '+%Y-%m-%d %H:%M:%S') | $LOG_DIR -> $ARCHIVE_NAME | $STATUS" >> "$ARCHIVE_DIR/archive.log"

    echo "$STATUS" >&2
    exit "$t_exit_code"
fi
