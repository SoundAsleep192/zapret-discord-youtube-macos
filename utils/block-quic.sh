#!/bin/bash
# Блокировка QUIC (UDP/443) для IP из списка zapret — трафик к YouTube/Discord
# пойдёт по TCP/443 и будет обрабатываться tpws. Только для прозрачного режима.

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

ZAPRET_DIR=""
for d in /opt/zapret /usr/local/etc/zapret; do
    if [[ -d "$d" && -d "$d/ipset" ]]; then
        ZAPRET_DIR="$d"
        break
    fi
done

if [[ -z "$ZAPRET_DIR" ]]; then
    echo "Zapret не найден. Пропуск блокировки QUIC."
    exit 0
fi

IPSET="$ZAPRET_DIR/ipset"
IP4="$IPSET/zapret-ip.txt"
IP6="$IPSET/zapret-ip6.txt"
ANCHOR="zapret_quic"
RULES_FILE="$IPSET/zapret-quic-block.conf"

# Добавить anchor в /etc/pf.conf, если ещё нет
ensure_anchor() {
    if grep -q "anchor \"$ANCHOR\"" /etc/pf.conf 2>/dev/null; then
        return 0
    fi
    [[ -f /etc/pf.conf.bak.zapret-quic ]] || sudo cp /etc/pf.conf /etc/pf.conf.bak.zapret-quic
    printf '%s\n' "anchor \"$ANCHOR\"" | sudo tee -a /etc/pf.conf > /dev/null
    echo "Добавлен anchor $ANCHOR в /etc/pf.conf"
}

# Создать файл правил PF
write_rules() {
    sudo tee "$RULES_FILE" > /dev/null << EOF
# Блокировка QUIC (UDP/443) для IP из списка zapret — генерируется zapret-discord-youtube-macos
table <zapret_quic4> persist file "$IP4"
block drop quick inet proto udp from any to <zapret_quic4> port 443
EOF
    if [[ -f "$IP6" ]] && [[ -s "$IP6" ]]; then
        sudo tee -a "$RULES_FILE" > /dev/null << EOF

table <zapret_quic6> persist file "$IP6"
block drop quick inet6 proto udp from any to <zapret_quic6> port 443
EOF
    fi
}

case "${1:-enable}" in
    enable)
        ensure_anchor
        write_rules
        # Сначала перезагрузка pf (подхватит новый anchor), затем загрузка правил в anchor
        sudo pfctl -f /etc/pf.conf 2>/dev/null || true
        sudo pfctl -a "$ANCHOR" -f "$RULES_FILE" 2>/dev/null || true
        echo "QUIC (UDP/443) для списка zapret заблокирован."
        ;;
    disable)
        sudo pfctl -a "$ANCHOR" -F all 2>/dev/null || true
        echo "Блокировка QUIC снята."
        ;;
    *)
        echo "Использование: $0 {enable|disable}"
        exit 1
        ;;
esac
