#!/bin/bash
# Zapret Discord + YouTube — единая точка входа (macOS)
# Аналог service.bat из Flowseal: установка, запуск, остановка, меню.

set -e
cd "$(dirname "$0")"
REPO_DIR="$(pwd)"
CONFIG_FILE="$REPO_DIR/config.conf"
UTILS="$REPO_DIR/utils"
LISTS="$REPO_DIR/lists"
VERSION="2.0"

# ═══════════════════════════════════════════════════════════════
# Загрузка конфига
# ═══════════════════════════════════════════════════════════════
load_config() {
    [[ -f "$CONFIG_FILE" ]] || { echo "Ошибка: не найден $CONFIG_FILE"; exit 1; }
    . "$CONFIG_FILE"
    DOMAINS_FILE="${DOMAINS_FILE:-lists/domains.txt}"
    SOCKS_PORT="${SOCKS_PORT:-987}"
    MODE="${MODE:-auto}"
    STRATEGY="${STRATEGY:-11}"
    AUTO_SYSTEM_PROXY="${AUTO_SYSTEM_PROXY:-1}"
    BLOCK_QUIC="${BLOCK_QUIC:-1}"
    TEST_AFTER_STRATEGY="${TEST_AFTER_STRATEGY:-1}"
    DOMAINS_PATH="$REPO_DIR/$DOMAINS_FILE"
}

# ═══════════════════════════════════════════════════════════════
# Версия macOS (major, minor)
# ═══════════════════════════════════════════════════════════════
get_macos_version() {
    local v
    v=$(sw_vers -productVersion 2>/dev/null || echo "0.0")
    MACOS_MAJOR="${v%%.*}"
    MACOS_MINOR="${v#*.}"
    MACOS_MINOR="${MACOS_MINOR%%.*}"
    MACOS_MINOR="${MACOS_MINOR:-0}"
}

# Прозрачный режим ломается на Sonoma 14.5+ из-за ioctl(DIOCNATLOOK)
# https://github.com/bol-van/zapret/issues/1482
needs_socks() {
    get_macos_version
    case "$MODE" in
        socks) return 0 ;;
        transparent) return 1 ;;
        auto)
            if (( MACOS_MAJOR > 14 )) || (( MACOS_MAJOR == 14 && MACOS_MINOR >= 5 )); then
                return 0
            else
                return 1
            fi
            ;;
        *) return 0 ;;
    esac
}

get_zapret_dir() {
    ZAPRET_DIR=""
    for d in /opt/zapret /usr/local/etc/zapret; do
        if [[ -d "$d" && -f "$d/config" ]]; then
            ZAPRET_DIR="$d"
            return
        fi
    done
}

# ═══════════════════════════════════════════════════════════════
# Установка zapret (если ещё нет)
# ═══════════════════════════════════════════════════════════════
install_zapret() {
    get_zapret_dir
    if [[ -n "$ZAPRET_DIR" ]]; then
        echo "Zapret уже установлен: $ZAPRET_DIR"
        return 0
    fi
    echo "Установка zapret..."
    sudo mkdir -p /opt
    [[ -d /opt/zapret ]] && { echo "Удаляю неполную копию..."; sudo rm -rf /opt/zapret; }
    sudo git clone https://github.com/bol-van/zapret.git /opt/zapret
    (cd /opt/zapret && sudo make mac)
    # Ответы: IPv6 Y, ipset 2, socks N, transparent Y, LAN 1, WAN 1, auto N
    (cd /opt/zapret && printf 'Y\n2\nN\nY\n1\n1\nN\n\n' | sudo ./install_easy.sh)
    ZAPRET_DIR="/opt/zapret"
}

# ═══════════════════════════════════════════════════════════════
# Конфигурация zapret под режим (transparent / socks)
# ═══════════════════════════════════════════════════════════════
configure_zapret() {
    get_zapret_dir
    [[ -n "$ZAPRET_DIR" ]] || { echo "Ошибка: zapret не найден."; exit 1; }
    local cfg="$ZAPRET_DIR/config"

    if needs_socks; then
        echo "Режим: SOCKS (рекомендуется для macOS $(sw_vers -productVersion))"
        sudo sed -i '' \
            -e 's/^TPWS_ENABLE=.*/TPWS_ENABLE=0/' \
            -e 's/^TPWS_SOCKS_ENABLE=.*/TPWS_SOCKS_ENABLE=1/' \
            -e 's/^MODE_FILTER=.*/MODE_FILTER=hostlist/' \
            -e 's/^INIT_APPLY_FW=.*/INIT_APPLY_FW=0/' \
            -e "s/^TPPORT_SOCKS=.*/TPPORT_SOCKS=$SOCKS_PORT/" \
            "$cfg"
    else
        echo "Режим: прозрачный"
        sudo sed -i '' \
            -e 's/^TPWS_ENABLE=.*/TPWS_ENABLE=1/' \
            -e 's/^TPWS_SOCKS_ENABLE=.*/TPWS_SOCKS_ENABLE=0/' \
            -e 's/^MODE_FILTER=.*/MODE_FILTER=ipset/' \
            -e 's/^INIT_APPLY_FW=.*/INIT_APPLY_FW=1/' \
            "$cfg"
        # Применяем стратегию
        if [[ -x "$UTILS/apply-strategy.sh" ]] && [[ -n "$STRATEGY" ]]; then
            sudo "$UTILS/apply-strategy.sh" "$STRATEGY" 2>/dev/null || true
        fi
    fi
}

# ═══════════════════════════════════════════════════════════════
# Обновление списков IP и доменов
# ═══════════════════════════════════════════════════════════════
update_ip_list() {
    load_config
    get_zapret_dir
    [[ -n "$ZAPRET_DIR" ]] || { echo "Ошибка: zapret не найден. Сначала выполните установку."; exit 1; }
    [[ -f "$DOMAINS_PATH" ]] || { echo "Ошибка: не найден $DOMAINS_PATH"; exit 1; }
    chmod +x "$UTILS/update-ip-list.sh"
    sudo "$UTILS/update-ip-list.sh" "$DOMAINS_PATH"
}

# ═══════════════════════════════════════════════════════════════
# Системный SOCKS-прокси (networksetup)
# ═══════════════════════════════════════════════════════════════
set_system_proxy() {
    local on_off="$1"
    local port="${2:-$SOCKS_PORT}"
    local services
    services=$(networksetup -listallnetworkservices 2>/dev/null | grep -v "^\*" | grep -v "^An asterisk" | sed '1d')
    while IFS= read -r svc; do
        [[ -z "$svc" ]] && continue
        if [[ "$on_off" = "on" ]]; then
            sudo networksetup -setsocksfirewallproxy "$svc" 127.0.0.1 "$port" 2>/dev/null || true
            sudo networksetup -setsocksfirewallproxystate "$svc" on 2>/dev/null || true
        else
            sudo networksetup -setsocksfirewallproxystate "$svc" off 2>/dev/null || true
        fi
    done <<< "$services"
}

# ═══════════════════════════════════════════════════════════════
# Запуск / остановка
# ═══════════════════════════════════════════════════════════════
do_start() {
    get_zapret_dir
    [[ -n "$ZAPRET_DIR" ]] || { echo "Ошибка: zapret не найден. Запустите: $0 install"; exit 1; }
    configure_zapret
    echo "Запускаю zapret..."
    sudo bash "$ZAPRET_DIR/init.d/macos/zapret" start
    if ! needs_socks && [[ "$BLOCK_QUIC" = "1" ]] && [[ -x "$UTILS/block-quic.sh" ]]; then
        sudo "$UTILS/block-quic.sh" enable 2>/dev/null || true
    fi
    if needs_socks && [[ "$AUTO_SYSTEM_PROXY" = "1" ]]; then
        set_system_proxy on
        echo "Системный прокси включён (SOCKS5 127.0.0.1:$SOCKS_PORT)."
    fi
    echo ""
    echo "Готово. YouTube и Discord должны открываться."
}

do_stop() {
    get_zapret_dir
    if needs_socks && [[ "$AUTO_SYSTEM_PROXY" = "1" ]]; then
        set_system_proxy off
        echo "Системный прокси выключен."
    fi
    if [[ -n "$ZAPRET_DIR" ]]; then
        [[ "$BLOCK_QUIC" = "1" ]] && [[ -x "$UTILS/block-quic.sh" ]] && sudo "$UTILS/block-quic.sh" disable 2>/dev/null || true
        sudo bash "$ZAPRET_DIR/init.d/macos/zapret" stop 2>/dev/null || true
        echo "Zapret остановлен."
    else
        echo "Zapret не установлен."
    fi
}

do_switch_strategy() {
    get_zapret_dir
    [[ -n "$ZAPRET_DIR" ]] || { echo "Zapret не установлен."; return; }
    local json="$UTILS/strategies/strategies.json"
    if [[ -f "$json" ]]; then
        echo "Стратегии:"
        for i in $(seq 1 13); do
            desc=$(python3 -c "import json,sys; d=json.load(open('$json')); print(d.get('$i',{}).get('description','?'))" 2>/dev/null || echo "?")
            rec=""
            [[ "$i" = "11" ]] && rec=" (рекомендуется)"
            echo "  $i — $desc$rec"
        done
    else
        echo "Стратегии: 1–13 (11 — ALT11, рекомендуется)"
    fi
    echo ""
    read -p "Номер (1–13): " num
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= 13 )); then
        [[ -x "$UTILS/apply-strategy.sh" ]] && TEST_AFTER_STRATEGY="$TEST_AFTER_STRATEGY" SOCKS_PORT="$SOCKS_PORT" sudo -E "$UTILS/apply-strategy.sh" "$num" && echo "Стратегия $num применена."
    else
        echo "Неверный номер."
    fi
}

do_update_discord_hosts() {
    load_config
    [[ -x "$UTILS/update-discord-hosts.sh" ]] || { echo "Скрипт не найден."; return; }
    sudo "$UTILS/update-discord-hosts.sh" "$DOMAINS_PATH"
    echo "Готово. При проблемах с голосом Discord перезапустите приложение."
}

do_check_availability() {
    load_config
    [[ -x "$UTILS/check-availability.sh" ]] || { echo "Скрипт не найден."; return; }
    SOCKS_PORT="$SOCKS_PORT" "$UTILS/check-availability.sh"
}

do_status() {
    get_zapret_dir
    get_macos_version
    echo "macOS: $(sw_vers -productVersion)"
    echo "Режим: $MODE (рекомендуется: $(needs_socks && echo 'SOCKS' || echo 'прозрачный'))"
    echo ""
    if [[ -z "$ZAPRET_DIR" ]]; then
        echo "Zapret: не установлен"
        return
    fi
    echo "Zapret: $ZAPRET_DIR"
    if pgrep -f "tpws.*--daemon" >/dev/null 2>&1; then
        echo "Статус: работает"
    else
        echo "Статус: не запущен"
    fi
}

# ═══════════════════════════════════════════════════════════════
# Установка «с нуля»: всё в одном
# ═══════════════════════════════════════════════════════════════
do_install() {
    load_config
    install_zapret
    update_ip_list
    configure_zapret
    do_start
}

# ═══════════════════════════════════════════════════════════════
# Меню
# ═══════════════════════════════════════════════════════════════
show_menu() {
    load_config
    get_zapret_dir
    local installed="нет"
    [[ -n "$ZAPRET_DIR" ]] && installed="да"
    local mode_hint
    needs_socks && mode_hint="SOCKS" || mode_hint="прозрачный"

    clear
    echo "=============================================="
    echo "  Zapret Discord + YouTube  v$VERSION"
    echo "=============================================="
    echo ""
    echo "  1. Установить и запустить (с нуля)"
    echo "  2. Запустить"
    echo "  3. Остановить"
    echo "  4. Статус"
    echo "  5. Обновить список доменов"
    echo "  6. Сменить стратегию (1–13, для прозрачного режима)"
    echo "  7. Обновить hosts для Discord (голос и т.п.)"
    echo "  8. Проверить доступность (YouTube, Discord)"
    echo ""
    echo "  0. Выход"
    echo ""
    echo "  Установлен: $installed  |  Режим: $MODE ($mode_hint)"
    echo "  Конфиг: config.conf (BLOCK_QUIC, TEST_AFTER_STRATEGY)"
    echo ""
    read -p "Выбор (0–8): " choice

    case "$choice" in
        1) do_install ;;
        2) do_start ;;
        3) do_stop ;;
        4) do_status ;;
        5) update_ip_list ;;
        6) do_switch_strategy ;;
        7) do_update_discord_hosts ;;
        8) do_check_availability ;;
        0) exit 0 ;;
        *) echo "Неверный выбор." ;;
    esac
    echo ""
    read -p "Нажмите Enter..."
}

# ═══════════════════════════════════════════════════════════════
# Точка входа
# ═══════════════════════════════════════════════════════════════
case "${1:-menu}" in
    install)   load_config; do_install ;;
    start)     load_config; do_start ;;
    stop)      load_config; do_stop ;;
    status)    load_config; do_status ;;
    update)    load_config; update_ip_list ;;
    strategy)  load_config; do_switch_strategy ;;
    discord-hosts) load_config; do_update_discord_hosts ;;
    check)      load_config; do_check_availability ;;
    menu)       while true; do show_menu; done ;;
    *)
        echo "Использование: $0 {install|start|stop|status|update|strategy|discord-hosts|check|menu}"
        echo "  install       — установка с нуля и запуск"
        echo "  start         — запуск"
        echo "  stop          — остановка"
        echo "  status        — статус"
        echo "  update        — обновить список доменов"
        echo "  strategy      — смена стратегии (1–13)"
        echo "  discord-hosts — обновить /etc/hosts для Discord"
        echo "  check         — проверить доступность YouTube и Discord"
        echo "  menu          — интерактивное меню (по умолчанию)"
        exit 1
        ;;
esac
