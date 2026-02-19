#!/bin/bash
# Проверка доступности YouTube и Discord (curl).
# Вызывается из меню или после смены стратегии.
# Переменные: SOCKS_PORT (порт прокси), при необходимости — из config.

port="${SOCKS_PORT:-987}"

if ! command -v curl >/dev/null 2>&1; then
    echo "Для проверки нужен curl (установите Xcode Command Line Tools)."
    exit 0
fi

if nc -z 127.0.0.1 "$port" 2>/dev/null; then
    proxy="socks5h://127.0.0.1:$port"
    echo "Проверка через SOCKS-прокси (127.0.0.1:$port)..."
else
    proxy=""
    echo "Проверка напрямую (zapret не в режиме SOCKS или остановлен)..."
fi

code_yt=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 ${proxy:+-x "$proxy"} "https://www.youtube.com" 2>/dev/null || echo "000")
code_dc=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 ${proxy:+-x "$proxy"} "https://discord.com" 2>/dev/null || echo "000")

ok=0
case "$code_yt" in 200|301|302|303|307) ok=$((ok+1)) ;; esac
case "$code_dc" in 200|301|302|303|307) ok=$((ok+1)) ;; esac

echo ""
echo "  YouTube:  HTTP $code_yt"
echo "  Discord:  HTTP $code_dc"
echo ""

if [[ $ok -eq 2 ]]; then
    echo "Оба сайта отвечают. Всё ок."
elif [[ $ok -eq 1 ]]; then
    echo "Один из сайтов недоступен. Попробуйте обновить список доменов (5) или сменить стратегию (6)."
else
    echo "Оба не отвечают. Если zapret запущен — попробуйте стратегию 6 или 12; если выключен — возможно, блокировка по DNS (см. README)."
fi
