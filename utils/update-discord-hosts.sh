#!/bin/bash
# Обновляет /etc/hosts блоками для Discord (резолв доменов в IP).
# Блок помечен маркерами для безопасного удаления/обновления.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DOMAINS_FILE="${1:-$REPO_DIR/lists/domains.txt}"

MARKER_START="# >>> zapret-discord-youtube-macos discord"
MARKER_END="# <<< zapret-discord-youtube-macos discord"
HOSTS="/etc/hosts"

# Собрать только Discord-домены (секция между "# Discord" и "# YouTube" / "# Прочее")
get_discord_domains() {
    local in_discord=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*Discord ]]; then
            in_discord=1
            continue
        fi
        if [[ "$line" =~ ^[[:space:]]*#[[:space:]]*(YouTube|Прочее) ]]; then
            in_discord=0
            continue
        fi
        line="${line%%#*}"
        line="$(echo "$line" | tr -d ' \t\r\n')"
        [[ -z "$line" ]] && continue
        if [[ "$in_discord" = 1 ]]; then
            echo "$line"
        fi
    done < "$DOMAINS_FILE"
}

if [[ ! -f "$DOMAINS_FILE" ]]; then
    echo "Ошибка: не найден $DOMAINS_FILE"
    exit 1
fi

echo "Резолв Discord-доменов из $DOMAINS_FILE..."
TMP=$(mktemp)
trap "rm -f '$TMP'" EXIT

printf '%s\n' "$MARKER_START" >> "$TMP"
while read -r domain; do
    for ip in $(dig +short "$domain" A 2>/dev/null); do
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            printf '%s\t%s\n' "$ip" "$domain" >> "$TMP"
        fi
    done
done < <(get_discord_domains)
printf '%s\n' "$MARKER_END" >> "$TMP"

LINES=$(wc -l < "$TMP")
if (( LINES <= 2 )); then
    echo "Нет записей для добавления (резолв пуст или домены не Discord)."
    exit 0
fi

# Удалить старый блок из /etc/hosts и вставить новый
sudo python3 - "$HOSTS" "$TMP" << 'PYEND'
import sys
hosts_path, block_path = sys.argv[1], sys.argv[2]
start = "# >>> zapret-discord-youtube-macos discord"
end = "# <<< zapret-discord-youtube-macos discord"

with open(hosts_path) as f:
    lines = f.readlines()
with open(block_path) as f:
    new_block = f.read()

out, skip = [], False
for line in lines:
    if start in line:
        skip = True
        continue
    if skip:
        if end in line:
            skip = False
        continue
    out.append(line)

# Убрать лишний trailing newline у существующего файла перед вставкой
if out and not out[-1].endswith("\n"):
    out[-1] += "\n"
out.append(new_block)
if not new_block.endswith("\n"):
    out.append("\n")

with open(hosts_path, "w") as f:
    f.writelines(out)
PYEND

echo "Готово: /etc/hosts обновлён (блок Discord)."
echo "Перезапуск zapret не обязателен; при проблемах с голосом — перезапустите Discord."
