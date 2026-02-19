# Zapret Discord + YouTube для macOS

Единая обёртка над [zapret](https://github.com/bol-van/zapret) для macOS: обход блокировок **только** для Discord и YouTube. Аналог [zapret-discord-youtube](https://github.com/Flowseal/zapret-discord-youtube) (Windows), но для Mac.

---

## Быстрый старт

1. **Один скрипт с нуля:** дважды нажмите **`service.command`** → выберите `1. Установить и запустить`.
2. Введите пароль администратора, дождитесь установки.
3. Всё настроится автоматически:
   - на macOS Sonoma 14.5+ будет использован режим **SOCKS** и включён системный прокси;
   - на более старых версиях — прозрачный режим без прокси.

Либо в терминале:
```bash
cd ~/zapret-discord-youtube-macos
./service.command install
```

---

## Файлы

| Файл | Назначение |
|------|------------|
| **service.command** | Главный скрипт — меню, установка, запуск, остановка. Запускать его или пункты ниже. |
| **config.conf** | Единый конфиг: режим (auto/transparent/socks), стратегия, порт, автопрокси. |
| **Install.command** | То же, что `service.command install`. |
| **Start.command** | То же, что `service.command start`. |
| **Stop.command** | То же, что `service.command stop`. |
| **Update-IP-List.command** | Обновить список IP из `lists/domains.txt`. |
| **Switch-Strategy.command** | Смена стратегии 1–13 (для прозрачного режима). |
| **lists/domains.txt** | Список доменов для обхода. По умолчанию — Discord и YouTube. |

---

## config.conf

```ini
# Режим: auto | transparent | socks
MODE=auto

# auto — SOCKS на macOS 14.5+, иначе прозрачный
# transparent — всегда прозрачный
# socks      — всегда SOCKS + системный прокси

# Стратегия (1–13), для прозрачного режима
STRATEGY=11

# Автоматически включать/выключать системный прокси при start/stop
AUTO_SYSTEM_PROXY=1

# Файл доменов, порт SOCKS
DOMAINS_FILE=lists/domains.txt
SOCKS_PORT=987
```

---

## Режимы

- **Прозрачный** — трафик перенаправляется через PF, прокси вручную не нужен. На Sonoma 14.5+ **не работает** (ограничения ядра).
- **SOCKS** — локальный прокси 127.0.0.1:987. При `AUTO_SYSTEM_PROXY=1` скрипт сам включает/выключает системный прокси при `start`/`stop`.

---

## Добавить домен

Откройте `lists/domains.txt`, добавьте домен (один на строку), сохраните. Затем: `service.command update` или пункт 5 в меню.

---

## Удаление

1. `./service.command stop`
2. Удалить папку `zapret-discord-youtube-macos`
3. Полное удаление zapret:
   ```bash
   sudo /opt/zapret/init.d/macos/zapret stop
   sudo /opt/zapret/uninstall_easy.sh
   ```

---

## Требования

- macOS, Xcode Command Line Tools
- Права администратора (для установки и start/stop)
