#!/bin/bash
# Переключение стратегии zapret (аналог ALT/FAKE на Windows)

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"
UTILS="$REPO_DIR/utils"
CONFIG_FILE="$REPO_DIR/config.conf"

echo "=============================================="
echo "  Переключение стратегии zapret"
echo "=============================================="
echo ""

# Загрузка конфига для TEST_AFTER_STRATEGY и SOCKS_PORT
[[ -f "$CONFIG_FILE" ]] && . "$CONFIG_FILE"
TEST_AFTER_STRATEGY="${TEST_AFTER_STRATEGY:-1}"
SOCKS_PORT="${SOCKS_PORT:-987}"

JSON="$UTILS/strategies/strategies.json"
if [[ -f "$JSON" ]]; then
    echo "Стратегии (из strategies.json):"
    for i in $(seq 1 14); do
        desc=$(python3 -c "import json,sys; d=json.load(open('$JSON')); print(d.get('$i',{}).get('description','?'))" 2>/dev/null || echo "?")
        rec=""
        [[ "$i" = "11" ]] && rec=" — рекомендуется"
        [[ "$i" = "14" ]] && rec=" — для chess.com/Cloudflare"
        echo "  $i  — $desc$rec"
    done
else
    echo "Стратегии: 1–14 (11 — рекомендуется, 14 — для chess.com)."
fi
echo ""

read -p "Введи номер стратегии (1-14): " num

if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > 14 )); then
    echo "Неверный номер."
    read -p "Нажмите Enter, чтобы закрыть."
    exit 1
fi

chmod +x "$UTILS/apply-strategy.sh"
TEST_AFTER_STRATEGY="$TEST_AFTER_STRATEGY" SOCKS_PORT="$SOCKS_PORT" sudo -E "$UTILS/apply-strategy.sh" "$num"

echo ""
read -p "Нажмите Enter, чтобы закрыть."
