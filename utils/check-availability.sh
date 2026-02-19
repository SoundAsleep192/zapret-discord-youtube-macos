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

# Ограничиваем время, чтобы проверка не зависала (особенно chess.com через прокси)
code_yt=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 ${proxy:+-x "$proxy"} "https://www.youtube.com" 2>/dev/null || echo "000")
code_dc=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 ${proxy:+-x "$proxy"} "https://discord.com" 2>/dev/null || echo "000")
code_chess=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 6 --max-time 12 ${proxy:+-x "$proxy"} "https://www.chess.com" 2>/dev/null || echo "000")

# Оставляем только первые 3 символа (иногда значения склеиваются в выводе)
code_yt="${code_yt:0:3}"
code_dc="${code_dc:0:3}"
code_chess="${code_chess:0:3}"

ok=0
case "$code_yt" in 200|301|302|303|307) ok=$((ok+1)) ;; esac
case "$code_dc" in 200|301|302|303|307) ok=$((ok+1)) ;; esac
case "$code_chess" in 200|301|302|303|307) ok=$((ok+1)) ;; esac

echo ""
echo "  YouTube:   HTTP $code_yt"
echo "  Discord:   HTTP $code_dc"
echo "  Chess.com: HTTP $code_chess"
echo ""

if [[ $ok -eq 3 ]]; then
    echo "Все три сайта отвечают. Всё ок."
elif [[ $ok -ge 1 ]]; then
    echo "Часть сайтов недоступна. Обновите список доменов (5) или смените стратегию (6)."
else
    echo "Сайты не отвечают. Если zapret запущен — попробуйте стратегию 6 или 12; если выключен — возможно, блокировка по DNS (см. README)."
fi
