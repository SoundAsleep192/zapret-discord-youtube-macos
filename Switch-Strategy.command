#!/bin/bash
# Переключение стратегии zapret (аналог ALT/FAKE на Windows)

cd "$(dirname "$0")"
REPO_DIR="$(pwd)"
UTILS="$REPO_DIR/utils"

echo "=============================================="
echo "  Переключение стратегии zapret"
echo "=============================================="
echo ""
echo "Стратегии (адаптированы из Flowseal zapret-discord-youtube):"
echo "  1  — Default (split-pos=1,midsld, disorder)"
echo "  2  — ALT (split-pos=1, disorder)"
echo "  3  — ALT2 (split-pos=2, disorder)"
echo "  4  — ALT3 (split-pos=2,midsld, disorder)"
echo "  5  — Simple (split-pos=1)"
echo "  6  — midsld (split-pos=midsld, disorder)"
echo "  7  — hostcase (hostcase + split-pos=1)"
echo "  8  — hostdot (hostdot + split-pos=1)"
echo "  9  — sld2 (split-pos=sld2, disorder)"
echo " 10  — methodspace"
echo " 11  — ALT11 (hostcase+hostdot, рекомендуется)"
echo " 12  — oob (out-of-band)"
echo " 13  — no disorder"
echo ""
echo "На Windows у тебя работала стратегия 11 (ALT11)."
echo ""

read -p "Введи номер стратегии (1-13): " num

if [[ ! "$num" =~ ^[0-9]+$ ]] || (( num < 1 || num > 13 )); then
    echo "Неверный номер."
    read -p "Нажмите Enter, чтобы закрыть."
    exit 1
fi

chmod +x "$UTILS/apply-strategy.sh"
sudo "$UTILS/apply-strategy.sh" "$num"

echo ""
read -p "Нажмите Enter, чтобы закрыть."
