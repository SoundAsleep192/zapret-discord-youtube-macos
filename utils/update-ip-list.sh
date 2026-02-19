#!/bin/bash
# Генерирует zapret-ip.txt и zapret-ip6.txt из lists/domains.txt
# Вызывается из install.command и update-ip-list.command

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LISTS_DIR="$REPO_DIR/lists"
DOMAINS_FILE="${1:-$LISTS_DIR/domains.txt}"

# Путь к zapret (проверяем оба варианта)
ZAPRET_DIR=""
for d in /opt/zapret /usr/local/etc/zapret; do
    if [[ -d "$d" && -d "$d/ipset" ]]; then
        ZAPRET_DIR="$d"
        break
    fi
done

if [[ -z "$ZAPRET_DIR" ]]; then
    echo "Ошибка: zapret не найден. Сначала запустите Install.command"
    exit 1
fi

IPSET_DIR="$ZAPRET_DIR/ipset"
IP4_FILE="$IPSET_DIR/zapret-ip.txt"
IP6_FILE="$IPSET_DIR/zapret-ip6.txt"
HOSTS_USER_FILE="$IPSET_DIR/zapret-hosts-user.txt"

if [[ ! -f "$DOMAINS_FILE" ]]; then
    echo "Ошибка: не найден файл $DOMAINS_FILE"
    exit 1
fi

echo "Читаю домены из $DOMAINS_FILE..."
echo "Записываю IP в $IPSET_DIR (только Discord и YouTube)..."

# Временные файлы в репо, потом копируем с sudo
TMP4=$(mktemp)
TMP6=$(mktemp)
trap "rm -f '$TMP4' '$TMP6'" EXIT
: > "$TMP4"
: > "$TMP6"

while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    line="$(echo "$line" | tr -d ' \t\r\n')"
    [[ -z "$line" ]] && continue
    for ip in $(dig +short "$line" A 2>/dev/null); do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip" >> "$TMP4"
        fi
    done
    for ip in $(dig +short "$line" AAAA 2>/dev/null); do
        if [[ "$ip" == *:* ]]; then
            echo "$ip" >> "$TMP6"
        fi
    done
done < "$DOMAINS_FILE"

# Убираем дубликаты
sort -u "$TMP4" -o "$TMP4"
sort -u "$TMP6" -o "$TMP6"

# Копируем в zapret (скрипт вызывается с sudo, поэтому уже root)
cp "$TMP4" "$IP4_FILE"
cp "$TMP6" "$IP6_FILE"

# Список доменов для режима SOCKS (hostlist) — без комментариев и пустых строк
grep -v '^[[:space:]]*#' "$DOMAINS_FILE" | sed 's/#.*//; s/[[:space:]]//g' | grep -v '^$' | sort -u > "$HOSTS_USER_FILE"
HOSTS_COUNT=$(wc -l < "$HOSTS_USER_FILE")

COUNT4=$(wc -l < "$IP4_FILE")
COUNT6=$(wc -l < "$IP6_FILE")
echo "Готово: IPv4 — $COUNT4 адресов, IPv6 — $COUNT6 адресов, доменов (SOCKS) — $HOSTS_COUNT."

# Перезагрузка таблиц PF (если zapret уже установлен)
if [[ -f "$ZAPRET_DIR/init.d/macos/zapret" ]]; then
    echo "Перезагружаю таблицы фаервола..."
    bash "$ZAPRET_DIR/init.d/macos/zapret" reload-fw-tables 2>/dev/null || true
fi
