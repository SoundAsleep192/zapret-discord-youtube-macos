#!/bin/bash
# Применяет стратегию к zapret: патчит TPWS_OPT в config и перезапускает

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STRATEGIES_DIR="$SCRIPT_DIR/strategies"

# Проверка zapret
ZAPRET_DIR=""
for d in /opt/zapret /usr/local/etc/zapret; do
    if [[ -d "$d" && -f "$d/config" ]]; then
        ZAPRET_DIR="$d"
        break
    fi
done

if [[ -z "$ZAPRET_DIR" ]]; then
    echo "Ошибка: zapret не найден. Сначала запустите Install.command"
    exit 1
fi

CONFIG="$ZAPRET_DIR/config"
STRATEGY_NUM="${1:-0}"

if [[ -z "$STRATEGY_NUM" ]]; then
    echo "Использование: $0 <номер стратегии 1-13>"
    exit 1
fi

# Найти файл стратегии (11-alt11.txt или 1-default.txt)
STRATEGY_FILE=""
for f in "$STRATEGIES_DIR/$STRATEGY_NUM"*.txt; do
    [[ -f "$f" ]] && STRATEGY_FILE="$f" && break
done

if [[ -z "$STRATEGY_FILE" ]]; then
    echo "Ошибка: стратегия $STRATEGY_NUM не найдена (допустимы номера 1-13)"
    exit 1
fi

echo "Применяю стратегию $STRATEGY_NUM ($(basename "$STRATEGY_FILE" .txt))..."

# Патчим config: заменяем TPWS_OPT через Python
TMP_CFG=$(mktemp)
TMP_OPT=$(mktemp)
cp "$STRATEGY_FILE" "$TMP_OPT"

python3 - "$CONFIG" "$TMP_OPT" "$TMP_CFG" << 'PYEND'
import sys
config_path, opt_path, out_path = sys.argv[1:4]
with open(opt_path) as f:
    new_opt = f.read().rstrip()
with open(config_path) as f:
    lines = f.readlines()

out, i = [], 0
while i < len(lines):
    line = lines[i]
    if 'TPWS_OPT="' in line:
        out.append('TPWS_OPT="\n')
        out.append(new_opt + '\n')
        i += 1
        while i < len(lines) and '"' not in lines[i]:
            i += 1
        if i < len(lines):
            out.append('"\n')
            i += 1
        continue
    out.append(line)
    i += 1

with open(out_path, 'w') as f:
    f.writelines(out)
PYEND

sudo cp "$TMP_CFG" "$CONFIG"
rm -f "$TMP_CFG" "$TMP_OPT"

# Перезапуск zapret
echo "Перезапускаю zapret..."
sudo bash "$ZAPRET_DIR/init.d/macos/zapret" restart

# Опционально: проверка доступности после смены стратегии (config: TEST_AFTER_STRATEGY=1)
if [[ "${TEST_AFTER_STRATEGY:-0}" = "1" ]]; then
    sleep 2
    port="${SOCKS_PORT:-987}"
    if command -v curl >/dev/null 2>&1; then
        if nc -z 127.0.0.1 "$port" 2>/dev/null; then
            proxy="socks5h://127.0.0.1:$port"
            echo "Проверка через SOCKS-прокси..."
        else
            proxy=""
            echo "Проверка (прозрачный режим)..."
        fi
        ok=0
        code_yt=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 ${proxy:+-x "$proxy"} "https://www.youtube.com" 2>/dev/null || echo "000")
        code_dc=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 ${proxy:+-x "$proxy"} "https://discord.com" 2>/dev/null || echo "000")
        case "$code_yt" in 200|301|302|303|307) ok=$((ok+1)) ;; esac
        case "$code_dc" in 200|301|302|303|307) ok=$((ok+1)) ;; esac
        if [[ $ok -eq 2 ]]; then
            echo "Проверка пройдена: YouTube ($code_yt), Discord ($code_dc)."
        else
            echo "Проверка: YouTube=$code_yt, Discord=$code_dc. Если не открываются — попробуйте другую стратегию (6 или 12)."
        fi
    fi
fi

echo "Готово. Проверьте YouTube и Discord."
