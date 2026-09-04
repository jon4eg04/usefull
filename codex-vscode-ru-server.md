# Codex в VS Code на сервере с российским IP через локальный VPN

Рабочая схема для VS Code Remote-SSH + Codex Agent Host, когда сам сервер имеет российский IP, а на Windows уже есть VPN-клиент с локальным HTTP-прокси.

Цель: **не проксировать весь сервер**, а отправлять через домашний VPN только сетевой трафик VS Code Agent Host / Codex. Никаких патчей бинарника Codex, обёрток и отдельного постоянно открытого PowerShell после настройки не нужно.

## Что используется

В нашей текущей схеме:

- локальный Windows-PC с VPN/Happ;
- локальный HTTP proxy VPN: `127.0.0.1:10809`;
- удалённый порт-прокси на сервере: `127.0.0.1:17891`;
- OAuth callback Codex: порты `1455` и `1457`;
- на каждый сервер всегда делаем два SSH alias: `<name>-root` и `<name>-dev`.

Если локальный HTTP-порт VPN когда-нибудь изменится, меняется только `10809` в SSH config.

---

## 1. Сначала проверить локальный HTTP proxy

На Windows, при запущенном VPN:

```powershell
curl.exe -x http://127.0.0.1:10809 https://chatgpt.com/cdn-cgi/trace
```

Нужны строки:

```text
ip=...
loc=PL
```

`loc` может быть не `PL`, главное — поддерживаемая страна и не `RU`.

**Проверять лучше именно `chatgpt.com/cdn-cgi/trace`.** Обычные сервисы определения IP могут идти по другим routing rules VPN и показывать прямой IP, хотя ChatGPT уже идёт через VPN.

Если здесь `loc=RU`, дальше идти бессмысленно: сначала исправить routing в VPN-клиенте.

---

## 2. SSH config: сразу root + dev

На Windows открыть:

```text
C:\Users\<USER>\.ssh\config
```

Для нового сервера сразу создать два alias. Пример для проекта `gt`:

```ssh
Host gt-root
    HostName SERVER_IP
    User root
    RemoteForward 17891 127.0.0.1:10809
    LocalForward 1455 127.0.0.1:1455
    LocalForward 1457 127.0.0.1:1457
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host gt-dev
    HostName SERVER_IP
    User dev
    RemoteForward 17891 127.0.0.1:10809
    LocalForward 1455 127.0.0.1:1455
    LocalForward 1457 127.0.0.1:1457
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Что здесь происходит:

```text
SERVER 127.0.0.1:17891
        ↓ RemoteForward через SSH
WINDOWS 127.0.0.1:10809
        ↓
VPN / Happ
        ↓
зарубежный exit
        ↓
OpenAI
```

`LocalForward 1455/1457` нужен для входа через ChatGPT: браузер открывается на Windows, а OAuth callback ждёт Codex на удалённом сервере. Сразу пробрасываем оба порта, потому что Codex может выбрать любой из них.

Не подключаться одновременно к `<name>-root` и `<name>-dev`: оба alias используют один remote port `17891`. Если когда-нибудь понадобится работать обоими одновременно, дать им разные remote ports.

---

## 3. Настройки VS Code

Открыть локальный **User Settings (JSON)** и оставить/добавить настройки Agent Host плюс proxy для обоих alias.

Минимальный блок для проекта `gt`:

```json
{
    "chat.agentHost.codexAgent.enabled": true,
    "chat.editor.codex.preferAgentHost": true,
    "chat.agentHost.allowSignedOutWhenUsable": true,

    "remote.SSH.remotePlatform": {
        "gt-root": "linux",
        "gt-dev": "linux"
    },

    "remote.SSH.httpProxy": {
        "gt-root": "http://127.0.0.1:17891",
        "gt-dev": "http://127.0.0.1:17891"
    },

    "remote.SSH.httpsProxy": {
        "gt-root": "http://127.0.0.1:17891",
        "gt-dev": "http://127.0.0.1:17891"
    }
}
```

Если `settings.json` уже содержит другие настройки, не заменять весь файл этим примером — просто добавить/объединить эти ключи.

### Что здесь НЕ нужно

Для этой remote-схемы не нужны:

```json
"http.proxy": "..."
"http.noProxy": [...]
```

Это настройки локального окна VS Code и они не решают задачу с удалённым Agent Host.

Также не нужен `~/.codex/.env`: внешний запрос в этой архитектуре делает VS Code Agent Host / VS Code Proxy, поэтому прокси надо передавать именно ему через `remote.SSH.httpProxy` / `remote.SSH.httpsProxy`.

---

## 4. На сервере добавить NO_PROXY для localhost

Codex app-server общается с внутренним VS Code Proxy через случайный порт на `127.0.0.1`. Поэтому localhost нельзя отправлять во внешний HTTP proxy.

Эту настройку надо сделать **отдельно для каждого пользователя**, под которым будет запускаться VS Code: сначала `root`, потом `dev`.

Под нужным пользователем выполнить:

```bash
grep -q '^# CODEX_REMOTE_NO_PROXY$' ~/.bashrc || sed -i '1i # CODEX_REMOTE_NO_PROXY\nexport NO_PROXY="127.0.0.1,localhost,::1"\nexport no_proxy="127.0.0.1,localhost,::1"\n' ~/.bashrc
```

Строки специально вставляются **в начало** `.bashrc`, потому что стандартный Ubuntu `.bashrc` может рано выйти для неинтерактивного shell.

Проверить:

```bash
head -n 5 ~/.bashrc
```

Должно быть:

```text
# CODEX_REMOTE_NO_PROXY
export NO_PROXY="127.0.0.1,localhost,::1"
export no_proxy="127.0.0.1,localhost,::1"
```

---

## 5. Полностью перезапустить VS Code Server

После изменения SSH config / VS Code proxy / `.bashrc` старый Agent Host нельзя оставлять жить со старым environment.

В VS Code:

```text
Ctrl+Shift+P
→ Remote-SSH: Kill VS Code Server on Host...
→ выбрать <name>-root или <name>-dev
```

После этого подключиться заново:

```text
Remote-SSH: Connect to Host...
→ gt-root
```

С этого момента отдельный PowerShell с `ssh -N -R ...` **не нужен**. `RemoteForward` поднимает само SSH-соединение VS Code.

---

## 6. Проверить, что туннель реально работает

В терминале удалённого сервера:

```bash
curl -x http://127.0.0.1:17891 https://chatgpt.com/cdn-cgi/trace
```

Ожидаем зарубежный IP и, например:

```text
loc=PL
```

Можно проверить прямо через Codex, попросив его выполнить:

```text
Выполни на сервере:
curl -x http://127.0.0.1:17891 https://chatgpt.com/cdn-cgi/trace
Ничего не меняй. Скажи только ip и loc.
```

Если Codex отвечает и показывает зарубежный `loc`, основная схема готова.

---

## 7. Вход через ChatGPT

Нормальный вариант: ничего вручную запускать не нужно, потому что в SSH config уже есть:

```ssh
LocalForward 1455 127.0.0.1:1455
LocalForward 1457 127.0.0.1:1457
```

Нажать в VS Code:

```text
Sign in with ChatGPT
```

Браузер открывается на Windows, callback на `localhost:1455` или `localhost:1457` автоматически уходит через SSH на удалённый Codex.

### Оба OAuth-порта одной командой — ручной fallback

Если LocalForward ещё не прописан в config или нужно отдельно проверить OAuth, оба порта можно пробросить одной командой:

```powershell
ssh -N -L 1455:127.0.0.1:1455 -L 1457:127.0.0.1:1457 <name>-root
```

Например:

```powershell
ssh -N -L 1455:127.0.0.1:1455 -L 1457:127.0.0.1:1457 gt-root
```

После успешного входа ручной процесс можно закрыть. Если `LocalForward` уже есть в SSH config и VS Code подключён, этот ручной процесс не нужен и может конфликтовать за те же локальные порты.

---

# Быстрая проверка, если не работает

## A. Codex получает 403 / подозрение, что идёт напрямую

Проверить environment реального VS Code Agent Host:

```bash
pid=$(pgrep -f 'bootstrap-fork --type=agentHost' | head -n1)
echo "PID=$pid"
tr '\0' '\n' < /proc/$pid/environ | grep -Ei '^(http_proxy|https_proxy|HTTP_PROXY|HTTPS_PROXY|no_proxy|NO_PROXY)='
```

Нормальный результат:

```text
http_proxy=http://127.0.0.1:17891/
https_proxy=http://127.0.0.1:17891/
no_proxy=127.0.0.1,localhost,::1
NO_PROXY=127.0.0.1,localhost,::1
```

Если `http_proxy` / `https_proxy` пустые:

1. проверить `remote.SSH.httpProxy` и `remote.SSH.httpsProxy` именно для alias, через который подключён VS Code;
2. сделать `Remote-SSH: Kill VS Code Server on Host...`;
3. переподключиться.

Если `curl -x http://127.0.0.1:17891 ...` показывает `loc=RU`, проблема ниже по цепочке: VPN/Happ routing или неправильный локальный HTTP-порт.

---

## B. Sign in ничего не делает / моделей нет / Codex app-server падает

Смотреть не Remote-SSH log, а свежий `agenthost.log` на сервере:

```bash
LOG=$(find ~/.vscode-server/data/logs -type f -name agenthost.log -printf '%T@ %p\n' | sort -nr | head -1 | cut -d' ' -f2-)
echo "$LOG"
tail -n 150 "$LOG"
```

Особенно искать:

```text
codex app-server exited
No such file or directory
codex.real
Failed to refresh OpenAI models
```

### Если найден `codex.real: No such file or directory`

Это не проблема VPN и не проблема авторизации. Значит bundled Codex раньше заменяли shell-обёрткой, которая пытается запустить отсутствующий `codex.real`.

**Нормальный Codex нельзя оборачивать/подменять.** В каталоге SDK должен лежать настоящий бинарник `codex`, а не маленький shell-script.

Найти текущие файлы:

```bash
find ~/.vscode-server/data/agent-host/sdk-cache/codex -type f -path '*/bin/codex' -ls
```

Если сервер уже испорчен предыдущими экспериментами, самый безопасный путь — восстановить **чистую такую же версию SDK** с рабочего Linux x64 сервера.

Пример:

```bash
mv ~/.vscode-server/data/agent-host/sdk-cache/codex/VERSION \
   ~/.vscode-server/data/agent-host/sdk-cache/codex/VERSION.broken-backup

scp -r dev@CLEAN_SERVER:/home/dev/.vscode-server/data/agent-host/sdk-cache/codex/VERSION \
   ~/.vscode-server/data/agent-host/sdk-cache/codex/
```

После восстановления снова сделать `Remote-SSH: Kill VS Code Server on Host...` и переподключиться.

На чистом новом сервере этот раздел вообще не нужен.

---

# Что НЕ делать

В нормальной установке не нужно:

- ставить VPN/TUN на сам сервер;
- проксировать весь nginx/PHP/cron/Bitrix-трафик сервера;
- держать отдельное окно PowerShell с reverse SSH tunnel;
- создавать `~/.codex/.env` ради этой схемы;
- копировать `auth.json` с ПК как обязательный этап;
- менять или оборачивать bundled бинарник `codex`;
- создавать `codex.real`, shell-wrapper и подобные костыли;
- использовать SOCKS, если локальный VPN уже даёт нормальный HTTP proxy;
- ориентироваться на `api.ipify.org`, если VPN имеет domain-based routing — проверять именно `chatgpt.com/cdn-cgi/trace`.

---

# Короткий чек-лист нового сервера

1. Проверить на Windows `chatgpt.com/cdn-cgi/trace` через локальный HTTP proxy.
2. Создать SSH aliases `<name>-root` и `<name>-dev`.
3. В оба alias добавить `RemoteForward 17891 → Windows:10809` и `LocalForward 1455/1457`.
4. Добавить оба alias в `remote.SSH.remotePlatform`, `remote.SSH.httpProxy`, `remote.SSH.httpsProxy`.
5. Под каждым remote user добавить `NO_PROXY/no_proxy` в начало `~/.bashrc`.
6. `Remote-SSH: Kill VS Code Server on Host...`.
7. Переподключиться через alias.
8. Проверить `curl -x http://127.0.0.1:17891 https://chatgpt.com/cdn-cgi/trace`.
9. `Sign in with ChatGPT` — callback уже проброшен через 1455/1457.
10. Написать Codex и работать.
