# ПЕРЕД СТАРТОМ — РУЧНОЙ БЛОК ДЛЯ ЖЕНИ

> Этот блок выполняется человеком вручную **до начала работы Codex по гайду**. Для самого Codex это не рабочий этап: если агент уже запущен и читает этот файл, считать блок выполненным и не запускать его повторно.

При первом подключении VS Code Remote SSH к новому серверу под `root` дать VS Code один раз попытаться скачать bundled Codex SDK. Если загрузка зависла/упала и Codex не запускается, открыть терминал **под root** и выполнить весь блок ниже.

Скрипт берёт версию из каталога, который уже создал VS Code, скачивает соответствующие npm-архивы Codex напрямую и раскладывает их в ожидаемый SDK cache. Версия не захардкожена.

```bash
set -Eeuo pipefail

CACHE="/root/.vscode-server/data/agent-host/sdk-cache/codex"

VERSION="$(
    find "$CACHE" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null \
    | sort -V \
    | tail -n1
)"

if [ -z "$VERSION" ]; then
    echo "ERROR: Codex version directory not found in $CACHE" >&2
    exit 1
fi

if [ "$(uname -m)" != "x86_64" ]; then
    echo "ERROR: this bootstrap is for Linux x86_64; detected: $(uname -m)" >&2
    exit 1
fi

echo "Installing Codex SDK $VERSION for root..."

BASE="$CACHE/$VERSION/linux-x64"
ROOT_PKG="$BASE/node_modules/@openai/codex"
PLATFORM_PKG="$BASE/node_modules/@openai/codex-linux-x64"

rm -rf "$BASE"
mkdir -p "$ROOT_PKG" "$PLATFORM_PKG"

curl -fL \
  "https://registry.npmjs.org/@openai/codex/-/codex-${VERSION}.tgz" \
  | tar -xz -C "$ROOT_PKG" --strip-components=1

curl -fL \
  "https://registry.npmjs.org/@openai/codex/-/codex-${VERSION}-linux-x64.tgz" \
  | tar -xz -C "$PLATFORM_PKG" --strip-components=1

BIN="$PLATFORM_PKG/vendor/x86_64-unknown-linux-musl/bin/codex"

echo
echo "=== SIZE ==="
du -sh "$CACHE/$VERSION"

echo
echo "=== VERSION ==="
"$BIN" --version
```

Нормальный финал:

```text
codex-cli X.Y.Z
```

После успешной установки выполнить в VS Code:

```text
Developer: Reload Window
```

Затем войти через `Sign in with ChatGPT`. Когда Codex заработал, уже дать ему этот гайд и начать основной маршрут ниже.

---

# Типовой сервер для работы через VS Code и Codex
Этот документ описывает повторяемую настройку клиентского сервера под простой рабочий процесс:

- программист устанавливает Ubuntu, Apache, PHP и Yii2;

- рабочий проект находится в `/var/www/<домен>/`;

- публичная и редактируемая часть находится в `/var/www/<домен>/web/`;

- первоначальная системная настройка выполняется под `root`, после контрольной точки root-сессия полностью закрывается;

- дальнейшая рабочая настройка и обычная разработка выполняются под пользователем `dev` через VS Code;

- пользователь `dev` имеет полный доступ только внутри `web/`;

- локальный Git сохраняет checkpoint всего проекта;

- отдельная приватная GitHub-репа сохраняет содержимое `web/`;

- оба checkpoint выполняются автоматически раз в час.

Это прагматичная модель 80/20, а не банковская инфраструктура. Она защищает от случайного удаления и неудачных правок, но не является полноценным disaster recovery всего сервера.

Гайд предназначен как для новых, так и для давно работающих клиентских серверов. На сервере уже могут находиться рабочий сайт, Yii-код программиста, пользовательские данные, cron-задания и одна или несколько Git-историй. Всё существующее считается важным и сохраняется, пока аудит явно не докажет обратное. На новых серверах GitHub по умолчанию сохраняет весь `web/`. Если на существующем сервере уже настроен намеренно более узкий GitHub scope, он сохраняется как исключение и не расширяется автоматически.

## 0. Как пользоваться этим гайдом

Пользователю не нужно самостоятельно разбираться в разделах ниже, заранее готовить команды или решать, что запускать следующим. Технические разделы являются рабочей инструкцией для Codex.

Главный маршрут разделён на две последовательные части:

1. **ROOT** — аудит, системная настройка, создание `dev`, права, локальный checkpoint, подготовка Codex для `dev` и всё остальное, что требует root;
2. **DEV** — после полного отключения root-сессии: вход под `dev`, авторизация ChatGPT/Codex, GitHub-контур, snapshots, dev-cron и дальнейшая работа.

В нормальном сценарии после перехода в DEV-часть обратно в root не возвращаются. Root-подключение после этого используется только для отдельной системной диагностики или изменения, которое объективно требует root.

## 0.1. Единственный стартовый запрос

На нужном сервере приложить этот файл к чату или временно положить его на сервер и написать:

```text
Прочитай client-server-guide.md полностью.
Настраиваем на этом сервере рабочий контур по гайду.
Веди меня по одному шагу за раз, начиная с шага 0.
```

Этого достаточно. Все сведения, которые можно безопасно определить на сервере, Codex определяет сам.

Сам гайд является **временным установочным файлом** и не должен попадать в клиентскую GitHub-репу. Если для переключения с root на dev нужна постоянная копия на время настройки, после создания `dev` сохранить её вне `web/`, например:

```text
/home/dev/.server-setup/client-server-guide.md
```

Каталог создать как `dev:dev` с режимом `700`, файл — `600`. После полного завершения настройки гайд и временный state-файл удалить. В репозитории остаётся только краткий `docs/server-setup-report.md` внутри фактического GitHub work tree.

После переключения с root на dev новый чат Codex можно начать коротко:

```text
Прочитай client-server-guide.md полностью.
ROOT-часть уже завершена. Сейчас мы подключены как dev.
Прочитай server-setup-state.md и продолжай с DEV-части гайда.
```

## 0.2. Обязательный режим работы Codex

Получив стартовый запрос, Codex обязан:

1. полностью прочитать этот файл до начала изменений;
2. создать план настройки и вести только один активный этап;
3. сначала выполнить read-only аудит, а уже потом что-либо менять;
4. самостоятельно получать сведения, доступные на сервере, а не спрашивать их у пользователя;
5. задавать вопрос только тогда, когда ответ нельзя безопасно определить автоматически;
6. не выдавать пользователю весь гайд или десяток команд сразу;
7. давать ровно один логический шаг или один готовый блок команд;
8. явно писать, где выполняется команда: Windows PowerShell, root shell или dev shell;
9. перед продолжением проверять результат предыдущего шага;
10. при ошибке остановиться, изучить фактическое состояние и дать исправленную команду;
11. не просить пользователя самостоятельно интерпретировать вывод;
12. сохранять существующие cron-задания, `.gitignore`, Apache-конфигурацию и Git-истории;
13. не применять массовые `chmod`, `chown`, `chgrp`, удаления или force-push без точного определения цели; для доступа `dev` внутри существующего production-дерева использовать персональный ACL без смены владельцев и групп;
14. не выводить в чат приватные SSH-ключи и действующие секреты;
15. считать существующий код внутри и выше `web/` рабочим production-кодом независимо от того, кто его писал;
16. не удалять, не переносить и не объединять существующие файлы только ради «чистой структуры»;
17. перед первым изменением создать или подтвердить исходный checkpoint;
18. довести настройку до практической проверки, а не ограничиваться созданием файлов;
19. считать границу ROOT → DEV жёсткой: после неё в обычном сценарии не продолжать выполнять root-команды из старой сессии;
20. до закрытия root-сессии заранее подготовить рабочий Codex SDK для `dev`, если штатная remote-загрузка SDK ненадёжна;
21. не копировать между пользователями `auth.json` или другие ChatGPT credentials: `dev` авторизуется в ChatGPT отдельно один раз.

## 0.3. PowerShell и Linux shell

Команды `chmod`, `chown`, `find`, `crontab`, Bash heredoc и Linux-пути выполняются только после SSH-подключения на сервер.

Первоначальный вход на сервер обычно выполняется существующим способом под `root`, например из Windows PowerShell:

```powershell
ssh root@client.example.ru
```

Если для длинной root-настройки нужен скрипт, Codex создаёт проверенный одноразовый `.sh` на сервере и даёт отдельную короткую команду запуска из Linux shell. Bash heredoc нельзя выдавать как команду для Windows PowerShell.

## 0.4. SSH-ключ пользователя dev

Для входа под `dev` используется **пользовательский SSH-ключ компьютера**. Это не GitHub deploy key.

Сначала Codex проверяет, есть ли на Windows уже подходящий публичный ключ. Нормальны как современные Ed25519-ключи, так и существующие корректные RSA-ключи. Не нужно генерировать новый ключ только потому, что старый не Ed25519.

Если подходящего ключа действительно нет, создать новый:

```powershell
ssh-keygen -t ed25519
```

Публичную часть существующего или нового ключа добавить в `/home/dev/.ssh/authorized_keys`. Приватный пользовательский ключ на сервер не копируется.

GitHub deploy key создаётся позже **отдельно на сервере**, используется только для одной клиентской GitHub-репы и не имеет отношения к SSH-входу пользователя на сам сервер.

До изменения production-прав пользователь обязан реально проверить вход под `dev`.

## 0.5. Минимальные вопросы пользователю

После read-only аудита Codex спрашивает только то, что нельзя определить автоматически. Обычно это:

1. название клиента или желаемый `client_slug`;
2. GitHub login и имя приватной репы;
3. является ли GitHub-репа новой пустой репой или уже содержит историю;
4. публичный SSH-ключ пользователя для `dev`, если подходящего ключа ещё нет на сервере;
5. какие найденные SQLite-базы и uploads нужно сохранять.

Не следует спрашивать пользователя о путях проекта, Unix-правах, Apache user, cron или Git remotes, пока Codex не попытался определить их сам.

Если GitHub-репа создаётся сейчас:

```text
GitHub → New repository → имя <client_slug>-web → Private.
Не добавлять README, .gitignore и License.
После создания прислать OWNER/REPOSITORY.
```

## 0.6. Сохранение прогресса между root и dev

После создания `dev` Codex может временно хранить несекретный state в:

```text
/home/dev/.server-setup/server-setup-state.md
```

Там разрешены только: текущий этап, пути, имя клиента, Apache user, GitHub repo, фактический GitHub work tree, имена wrapper/automation и результаты уже выполненных проверок. Пароли, приватные ключи, API tokens и webhook URL туда не записываются.

Перед закрытием root-сессии state должен явно содержать строку о том, что ROOT-часть завершена, а также фактические `project_root`, `web_root`, `github_work_tree` и результат проверки Codex SDK для `dev`.

После завершения state удаляется, а в фактическом GitHub work tree создаётся `docs/server-setup-report.md`.

## 0.7. Полный маршрут сопровождения

### Часть I — ROOT

| Этап | Кто работает | Результат, без которого нельзя идти дальше |
|---|---|---|
| 0. Read-only аудит | Codex в root-сессии | Определены пути, пользователи, права, Git, cron, Apache, ресурсы и данные |
| 1. Уточнения | Пользователь + Codex | Известны client slug, GitHub repo и фактический GitHub scope |
| 2. SSH-доступ dev | root + пользователь | Пользователь реально проверил, что вход под `dev` возможен |
| 3. Права | root | `dev` пишет в `web/`, не пишет выше, owners/groups не сломаны |
| 4. Локальный checkpoint | root | Создан/подтверждён checkpoint всего проекта |
| 5. Root automation | root | Root checkpoint и cron проверены вручную |
| 6. Codex для dev | root | Рабочий bundled Codex SDK из root-cache заранее скопирован в cache `dev` и запускается от `dev` |
| 7. Общая Codex-среда | root | Superpowers и глобальный AGENTS подключены к root/dev по общей серверной схеме |
| 8. Handoff | root + пользователь | State сохранён; root Remote SSH полностью закрыт |

### Часть II — DEV

| Этап | Кто работает | Результат, без которого нельзя идти дальше |
|---|---|---|
| 9. Переподключение | пользователь | VS Code действительно работает как `dev`; ChatGPT login выполнен для `dev` |
| 10. GitHub deploy key | dev + пользователь | `ssh -T` подтверждает доступ к одной клиентской репе |
| 11. GitHub-контур | Codex как dev | Отдельная Git metadata и wrapper работают |
| 12. Данные и HTTP | Codex как dev | SQLite snapshot целый, закрытые URL дают 403/404 |
| 13. Dev automation | dev | Ручной GitHub-sync и первый push успешны |
| 14. Финальная проверка | Codex + пользователь | Все тесты пройдены, создан report, временный гайд удалён |

## 0.8. Этап 0 — обязательный read-only аудит

До любых изменений Codex проверяет как минимум:

```text
whoami и группы;
реальный project_root и web_root;
owner/group/mode и существующие ACL;
наличие dev и sudo у него;
пользователя Apache/PHP;
фактические writable-каталоги www-data;
локальный Git root, branch, status и remotes;
вложенные .git и отдельные git-dir/work-tree схемы;
root-cron, dev-cron и cron других прикладных пользователей;
SQLite, uploads, cache, logs и runtime;
существующий GitHub scope;
symlink внутри web;
AllowOverride и HTTP-защиту закрытых путей;
RAM, swap и свободное место на корневой файловой системе.
```

Для ресурсов обязательно выполнить эквивалент:

```bash
free -h
swapon --show
df -h /
```

Если сервер маленький и на нём планируется VS Code/Codex, отсутствие swap считается отдельным риском, который нужно показать пользователю до запуска тяжёлых процессов. Размер swap не выбирается вслепую: сначала учитываются RAM, диск и текущее состояние сервера.

Результат аудита Codex кратко пересказывает: что уже настроено, что требует изменения и что останется нетронутым.

### GitHub scope

Для **нового типового сервера** GitHub work tree по умолчанию равен всему `web_root`.

Если на уже работающем сервере аудит обнаружил намеренно более узкий GitHub scope, его нельзя автоматически расширять до всего `web/`. Такой сервер считается осознанным исключением: существующий scope сохраняется и записывается в `server-setup-report.md`. Именно так обрабатываются серверы, где в GitHub должна уходить только одна конкретная подпапка `web/`.

## 0.9. ROOT-часть — контролируемая системная настройка

До закрытия root-сессии Codex:

- создаёт/проверяет `dev` без sudo;
- устанавливает необходимые пакеты;
- создаёт исходный checkpoint;
- сохраняет существующие cron и `.gitignore`;
- не переинициализирует уже корректный Git;
- не меняет owner/group всего production-дерева ради `dev`;
- настраивает root checkpoint с lock в `/run/lock`;
- оставляет `www-data` запись только там, где она реально нужна приложению;
- практически проверяет ограничения `dev` и доступ `www-data`;
- заранее копирует рабочий Codex SDK из root-cache в cache пользователя `dev`;
- подготавливает общую серверную Codex-среду для root/dev;
- сохраняет handoff-state для новой dev-сессии.

Root-блок считается завершённым только после практической проверки всех его результатов. После этого пользователь полностью закрывает root Remote SSH.

## 0.10. Граница ROOT → DEV

После завершения ROOT-части:

1. сохранить актуальный `server-setup-state.md` и временную копию гайда в `/home/dev/.server-setup/`;
2. убедиться, что Codex SDK запускается от `dev`;
3. полностью закрыть root Remote SSH connection;
4. подключиться к тому же серверу через alias/SSH-пользователя `dev`;
5. открыть рабочий `web_root`;
6. в новом терминале проверить:

```bash
whoami
echo "$HOME"
pwd
```

Ожидается `dev`, `/home/dev` и фактический рабочий каталог внутри `web/`.

Если ChatGPT/Codex просит авторизацию, выполнить `Sign in with ChatGPT` один раз именно для `dev`. Авторизация root не копируется и не считается общей.

В новой Codex-сессии использовать handoff-запрос из раздела 0.1. После этой точки нормальный основной маршрут выполняется под `dev`.

## 0.11. DEV-часть — GitHub и рабочая автоматизация

Под `dev` Codex:

- проверяет текущего пользователя и handoff-state;
- проверяет, что bundled Codex запускается и рабочая Codex-среда видна пользователю `dev`;
- создаёт отдельный GitHub deploy key без passphrase;
- проверяет `ssh -T`;
- создаёт Git metadata вне `web/`;
- создаёт project wrapper;
- аккуратно объединяет `.gitignore`;
- настраивает SQLite snapshot, если он нужен;
- создаёт GitHub-sync script с lock в `/home/dev/.cache`;
- сохраняет существующий dev-cron;
- проверяет staged files;
- делает первый commit/push без force-push;
- подтверждает отсутствие расхождения с `origin/main`.

Если удалённая репа не пустая, Codex делает fetch и сравнение. Force-push без отдельного осознанного решения запрещён.

## 0.12. Финальная приёмка

Codex практически проверяет:

- `dev` не может создать файл выше `web/`;
- `dev` может создать, изменить и удалить файл внутри `web/`;
- новые объекты внутри `web/` наследуют доступ `dev`;
- обычные файлы не получили ложный executable-бит;
- root checkpoint ранее был проверен вручную в ROOT-части;
- GitHub-sync работает вручную;
- повторный запуск не создаёт пустые коммиты;
- SQLite snapshot возвращает `PRAGMA integrity_check = ok`, если SQLite используется;
- закрытые URL возвращают 403/404;
- публичный сайт отвечает ожидаемым HTTP status;
- dev-cron содержит нужные строки без дубликатов.

В конце создаётся `docs/server-setup-report.md` внутри фактического GitHub work tree, затем временные `client-server-guide.md`, `server-setup-state.md` и root setup scripts удаляются. После удаления выполняется финальный GitHub-sync, чтобы сам гайд гарантированно не остался в репозитории.

# 1. Итоговая схема
| Контур | Что сохраняет | Где хранится | Кто запускает |
|---|---|---|---|
| Локальный checkpoint | Весь проект уровнем выше `web/`, кроме явно исключённого runtime | `.git` в корне проекта, без remote | `root` |
| GitHub checkpoint | `github_work_tree`: на новом сервере весь `web/`, на legacy-сервере допустим подтверждённый более узкий scope | Отдельная приватная репа клиента | `dev` |
| SQLite snapshot | Безопасная копия небольшой живой базы | `.git-snapshots/sqlite/` внутри GitHub checkpoint | `dev` |

Пример:

```text
/var/www/client.example.ru/          root-owned
├── .git/                            root-only, только локально
├── config/                          код Yii выше web
├── controllers/
├── runtime/                         пишет www-data
└── web/                             dev работает через персональный ACL
    ├── private/                     конфиги и обычные клиентские секреты
    ├── .git-snapshots/              безопасные снимки SQLite
    ├── ops/                         GitHub automation
    └── ...                          сайт
/home/dev/.gitdirs/client-web/       Git metadata для GitHub
/home/dev/.local/bin/client-git      отдельная Git-команда проекта
```

Внутри `web/` нет вложенной папки `.git`. Для GitHub используется отдельный `--git-dir` и реальная production-папка как `--work-tree`. Git поддерживает эти параметры штатно: [официальная документация Git](https://git-scm.com/docs/git).

## 2. Разделение прав
### root
`root`:

- владеет проектом выше `web/` и локальным `.git`;

- устанавливает пакеты и меняет Apache/PHP;

- управляет системными и root-cron заданиями;

- может посмотреть и изменить cron любого пользователя;

- создаёт локальные checkpoint-коммиты;

- выполняет первоначальную системную настройку и после handoff не используется для обычной разработки.

### dev
`dev`:

- подключается через VS Code Remote SSH;

- свободно создаёт, меняет и удаляет всё внутри `web/` через персональный ACL, не требующий смены владельцев и групп production-файлов;

- запускает PHP, Composer, npm и проектные команды, если они не требуют root;

- управляет только своим crontab;

- пушит только клиентскую GitHub-репу;

- не имеет `sudo` и записи выше `web/`.

У каждого Linux-пользователя свой crontab:

```bash
# Текущий пользователь
crontab -l
# root смотрит задания dev
crontab -u dev -l
# root редактирует задания dev
crontab -u dev -e
```

Возможность менять root-cron пользователю `dev` не выдаётся: это фактически root-доступ.

### www-data
`www-data` запускает Apache/PHP и пишет только туда, куда приложению действительно нужно: `runtime/`, логи, generated assets, uploads и рабочие базы.

## 3. Что подготовить до настройки

Для каждого клиента определить:

- `client_slug` — короткое имя без пробелов;
- `project_root` — например `/var/www/client.example.ru`;
- `web_root` — обычно `<project_root>/web`;
- GitHub `OWNER/REPOSITORY`;
- фактический GitHub scope;
- живые SQLite-базы, если они есть;
- runtime/logs/cache/uploads и другие каталоги, куда реально пишет приложение.

На новом сервере GitHub scope по умолчанию:

```bash
github_work_tree="$web_root"
```

На существующем сервере, где уже настроен намеренно более узкий scope, используется именно он, например:

```bash
github_work_tree="$web_root/some-existing-subproject"
```

Codex не расширяет такой scope автоматически. Исключение фиксируется в итоговом report.

Все Linux-команды ниже выполняются после SSH-подключения к серверу.

Пример переменных:

```bash
client_slug="ivanov"
project_root="/var/www/client.example.ru"
web_root="$project_root/web"
github_work_tree="$web_root"
github_owner="YOUR_GITHUB_LOGIN"
github_repo="ivanov-web"
```

Переменные действуют только в текущем shell-сеансе.

# ЧАСТЬ I — ROOT

С этого места и до явной границы `ROOT → DEV` все команды основного маршрута выполняются под `root`. Команды, которые проверяют будущего пользователя, запускаются через `runuser -u dev -- ...`.

# 4. Создание dev и прав на web
Этот раздел выполняет `root`.

### 4.1. Проверка пути
```bash
test -d "$project_root"
test -d "$web_root"
realpath "$project_root"
realpath "$web_root"
```

Ожидается, что `web_root` равен ровно `project_root/web`. Если путь отличается, команды ниже сначала адаптирует Codex по фактическому состоянию.

### 4.2. Пакеты
```bash
apt-get update
apt-get install -y git acl sqlite3
```

### 4.3. Пользователь dev
`dev` создаётся как обычный пользователь без `sudo`. Отдельная общая группа ради одного `dev` не создаётся.

```bash
id dev >/dev/null 2>&1 || adduser --disabled-password --gecos "" dev
gpasswd -d dev sudo 2>/dev/null || true
```

Публичный SSH-ключ владельца добавляется в:

```text
/home/dev/.ssh/authorized_keys
```

Права:

```bash
install -d -m 700 -o dev -g dev /home/dev/.ssh
touch /home/dev/.ssh/authorized_keys
chown dev:dev /home/dev/.ssh/authorized_keys
chmod 600 /home/dev/.ssh/authorized_keys
```

До изменения production-прав пользователь практически проверяет вход под `dev`. Если вход не работает, дальнейшая настройка прав не выполняется. После тестового входа dev-сессию закрыть и продолжить ROOT-часть под `root`.

### 4.4. Полный доступ dev внутри web без смены ownership

На production-сервере нельзя ради `dev` рекурсивно менять owner, group или обычные mode всего `web/`.

Перед изменениями создать постоянный root-only backup метаданных и ACL:

```bash
backup_root="/var/backups/server-setup/$client_slug"
backup_stamp="$(date '+%Y%m%d-%H%M%S')"
install -d -m 700 -o root -g root "$backup_root"
getfacl -R -p "$web_root" > "$backup_root/web-acl-before-dev-$backup_stamp.txt"
find "$web_root" -xdev -printf '%m\t%u\t%g\t%p\n' > "$backup_root/web-metadata-before-dev-$backup_stamp.tsv"
chmod 600 "$backup_root"/*
```

Перед ACL Codex проверяет symlink и не следует за ссылками за пределы `web_root`.

Доступ `dev` добавляется **без изменения owner/group/mode**. Каталогам нужен `rwx`. Для существующих файлов сохраняется их фактическая исполняемость: файл, который уже был executable, получает `rwx`; обычный файл — только `rw-`.

```bash
find "$web_root" -xdev -type d -exec setfacl -m u:dev:rwx {} +
find "$web_root" -xdev -type f -perm /111 -exec setfacl -m u:dev:rwx {} +
find "$web_root" -xdev -type f ! -perm /111 -exec setfacl -m u:dev:rw- {} +
find "$web_root" -xdev -type d -exec setfacl -d -m u:dev:rwx {} +
```

Default ACL на каталогах нужен для будущих объектов. Он не должен превращать обычные новые файлы в executable: итоговые права нового объекта всё равно ограничиваются mode, с которым его создаёт процесс.

После применения ACL проверить реальные entries через `getfacl`, а не делать вывод только по цифрам `ls -l`: POSIX ACL mask отображается в group-class bits и может менять визуальное числовое представление mode без выдачи записи owning-group.

### Если сервер уже был испорчен старой схемой прав

Если аудит обнаружил массовый `chgrp`, setgid, группу вроде `aiweb`, лишние ACL или массово изменённые mode:

1. сначала найти прежний ACL/metadata backup;
2. если backup достоверный и набор путей сопоставим, использовать его как источник прежних owner/group/mode;
3. не выполнять глобальный `setfacl --restore`, `chown -R`, `chgrp -R` или одинаковый `chmod -R` вслепую;
4. восстанавливать известные метаданные адресно и затем оставлять только персональный ACL `dev`;
5. если прежний owner/group/mode конкретного объекта нельзя доказать, не угадывать — сохранить текущее состояние и показать пользователю неопределённость;
6. старую вспомогательную группу удалять только после проверки, что ни файлы, ни ACL, ни скрипты, ни cron от неё больше не зависят.

## 4.5. www-data

`www-data` не должен владеть всем `web/` и не должен иметь запись во всё дерево.

Codex сначала read-only определяет реальные writable-каталоги приложения: runtime, logs, uploads, cache, generated assets, каталоги живых SQLite-баз и т.п.

Если `www-data` уже имеет нужный доступ — ничего не менять. Если доступа не хватает, исправлять только конкретный подтверждённый каталог. Допустим точечный ACL:

```bash
writable_dir="/точный/writable/каталог"
find "$writable_dir" -xdev -type d -exec setfacl -m u:www-data:rwx {} +
find "$writable_dir" -xdev -type f -exec setfacl -m u:www-data:rw- {} +
find "$writable_dir" -xdev -type d -exec setfacl -d -m u:www-data:rwx {} +
```

Не выдавать `www-data` запись во весь `web/` ради удобства.

## 4.6. Запрет записи dev выше web

Нельзя массово выполнять `chmod` по всему проекту только ради запрета `dev`. Сначала найти реальные writable-пути вне `web`:

```bash
runuser -u dev -- find "$project_root" -xdev \
    -path "$web_root" -prune -o \
    -writable -print
```

Если такие production-пути найдены, по каждому определить причину — owner, group, ACL или mode — и убрать только конкретный лишний доступ `dev`.

В итоге одновременно должно выполняться:

- `dev` создаёт, изменяет и удаляет всё необходимое внутри `web/`;
- `dev` не пишет выше `web/`;
- `www-data` пишет только в подтверждённые writable-каталоги;
- существующие owner/group/mode не были массово переписаны.

## 4.7. Практическая проверка прав до выхода из root

До перехода в DEV-часть root обязан проверить ограничения на практике:

```bash
if runuser -u dev -- test -w "$project_root"; then
    echo "ERROR: dev can write project root"
else
    echo "OK: dev cannot write project root"
fi

if runuser -u dev -- test -w "$web_root"; then
    echo "OK: dev can write web"
else
    echo "ERROR: dev cannot write web"
fi

if runuser -u dev -- touch "$project_root/.dev-write-test"; then
    rm -f "$project_root/.dev-write-test"
    echo "ERROR: dev created a file above web"
else
    echo "OK: write above web was rejected"
fi

runuser -u dev -- touch "$web_root/.dev-write-test"
rm -f "$web_root/.dev-write-test"
echo "OK: write inside web works"
```

Здесь же Codex проверяет ACL/default ACL и реальный доступ `www-data` к подтверждённым writable-каталогам. Если для защиты `private/`, `.git-snapshots/` или живой базы требуется изменение Apache VirtualHost/`AllowOverride`, это системное изменение выполняется **сейчас, в ROOT-части**, затем:

```bash
apachectl configtest
systemctl reload apache2
```

После перехода под `dev` нормальный маршрут не должен требовать возврата в root ради Apache.

## 4.8. Предустановка bundled Codex SDK для dev

VS Code Remote SSH хранит bundled Codex SDK отдельно в home каждого удалённого Linux-пользователя. Если remote-загрузка SDK на сервере ненадёжна, не нужно ждать повторной неудачной загрузки под `dev`: рабочую версию, которой уже пользуется root-сессия, заранее копируем в cache `dev`.

Это **только SDK/binary cache**. ChatGPT-авторизация, `auth.json` и другие credentials между root и dev не копируются.

Под `root`:

```bash
set -Eeuo pipefail

root_codex_cache="/root/.vscode-server/data/agent-host/sdk-cache/codex"
dev_codex_cache="/home/dev/.vscode-server/data/agent-host/sdk-cache/codex"

if [ ! -d "$root_codex_cache" ]; then
    echo "ERROR: root Codex SDK cache not found: $root_codex_cache" >&2
    exit 1
fi

install -d -m 755 -o dev -g dev "$dev_codex_cache"

copied=0
for src in "$root_codex_cache"/*; do
    [ -d "$src" ] || continue

    bin="$src/linux-x64/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex"
    [ -x "$bin" ] || continue

    version="$(basename "$src")"
    dst="$dev_codex_cache/$version"

    rm -rf "$dst"
    cp -a "$src" "$dst"
    chown -R dev:dev "$dst"

    dev_bin="$dst/linux-x64/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex"
    echo "=== Codex $version for dev ==="
    runuser -u dev -- "$dev_bin" --version
    copied=1
done

if [ "$copied" -ne 1 ]; then
    echo "ERROR: no complete executable Codex SDK found in root cache" >&2
    exit 1
fi
```

Нормальный результат — хотя бы одна строка вида:

```text
codex-cli X.Y.Z
```

Команда намеренно не хардкодит текущую версию Codex: она копирует все полноценные версии из root SDK cache и игнорирует пустые/недокачанные каталоги.

Если root-cache сам не содержит рабочей версии, сначала исправляется Codex под root. Пустой каталог версии размером несколько килобайт не считается установленным SDK.

## 4.9. Общая среда Codex: Superpowers + глобальный AGENTS.md

Этот шаг выполняется под `root` после создания пользователя `dev` и до окончательного переключения на DEV-часть. Источник bootstrap и глобального `AGENTS.md` хранится в публичном репозитории `jon4eg04/usefull`, каталог `codex-bootstrap/`.

Архитектура одна на весь сервер:

```text
/opt/superpowers/                         root-owned общая установка Superpowers
/etc/codex/AGENTS.md                     root-owned общий глобальный AGENTS.md
/root/.agents/skills/superpowers         -> /opt/superpowers/skills
/home/dev/.agents/skills/superpowers     -> /opt/superpowers/skills
/root/.codex/AGENTS.md                   -> /etc/codex/AGENTS.md
/home/dev/.codex/AGENTS.md               -> /etc/codex/AGENTS.md
```

ChatGPT credentials, `auth.json`, Codex sessions и прочее пользовательское состояние не объединяются. Общими являются только Superpowers skills и глобальный `AGENTS.md`.

Superpowers не берётся с плавающего `main`: bootstrap использует заранее проверенный release, зафиксированный в `SUPERPOWERS_REF` внутри `codex-bootstrap/install.sh`. Обновление на новый release делается осознанно отдельным изменением этого значения после проверки upstream release notes.

Запуск — одной командой под `root`:

```bash
curl -fsSL https://raw.githubusercontent.com/jon4eg04/usefull/main/codex-bootstrap/install.sh | bash
```

Installer обязан самостоятельно:

- убедиться, что он запущен от root и пользователь `dev` уже существует;
- установить Git, если его ещё нет;
- установить или привести `/opt/superpowers` к зафиксированному release, не удаляя неизвестный каталог и не затирая локальные изменения;
- скачать текущий `codex-bootstrap/AGENTS.md` во временный файл, проверить его и только потом атомарно заменить `/etc/codex/AGENTS.md`;
- создать native skill symlink и AGENTS symlink для `root` и `dev`;
- не копировать и не шарить credentials;
- проверить чтение `using-superpowers/SKILL.md` и `AGENTS.md` от имени обоих пользователей;
- вывести фактический Superpowers ref/commit и SHA256 установленного `AGENTS.md`.

Скрипт рассчитан на повторный запуск. Правильные ссылки и текущая установка остаются рабочими. Если на управляемом пути найден настоящий файл/каталог, который bootstrap не имеет права молча удалить, либо `/opt/superpowers` содержит неожиданный origin или локальные изменения, installer останавливается с ошибкой вместо разрушительного исправления.

Нормальный финал выглядит так:

```text
=== CODEX ENVIRONMENT READY ===
Superpowers ref:    vX.Y.Z
Superpowers commit: ...
AGENTS.md SHA256:   ...

root: OK
dev:  OK
```

После такого финала отдельные команды `git clone`, `ln -s` и ручное копирование `AGENTS.md` не нужны. После handoff достаточно перезагрузить VS Code / открыть новый Codex chat под `dev` и один раз выполнить ChatGPT login для `dev`, если он ещё не выполнен.

# 5. Локальный Git всего проекта
Этот контур принадлежит `root`, не имеет remote и служит быстрым checkpoint на том же сервере.

### 5.1. Инициализация
```bash
git -C "$project_root" init -b main
git -C "$project_root" config user.name "Server Checkpoint"
git -C "$project_root" config user.email "server@client.example.ru"
```

Если репозиторий уже существует, повторно инициализировать его не нужно.

В корневой `.gitignore` обычно исключаются только генерируемые и тяжёлые данные:

```gitignore
/vendor/
/runtime/*
!/runtime/.gitignore
/logs/*
/web/assets/*
*.log
*.tmp
*.swp
.DS_Store
Thumbs.db
```

`.gitignore` внутри `web/` также применяется к родительскому репозиторию.

Первый checkpoint:

```bash
git -C "$project_root" add -A
git -C "$project_root" commit -m "Initial server checkpoint"
```

После этого Git metadata закрывается от `dev`:

```bash
chown -R root:root "$project_root/.git"
chmod -R go-rwx "$project_root/.git"
chmod 700 "$project_root/.git"
```

### 5.2. Почасовой root-скрипт
Создать `/usr/local/sbin/<client_slug>-local-checkpoint.sh`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
project_root="/var/www/client.example.ru"
lock_file="/run/lock/ivanov-local-checkpoint.lock"
timestamp="$(date -u '+%Y-%m-%d %H:%M UTC')"
exec 9>"$lock_file"
if ! flock -n 9; then
    echo "[$timestamp] Previous local checkpoint is still running; skipping."
    exit 0
fi
git -C "$project_root" add -A
if ! git -C "$project_root" diff --cached --quiet; then
    git -C "$project_root" commit -m "Automated server checkpoint: $timestamp"
fi
```

Затем:

```bash
chown root:root /usr/local/sbin/ivanov-local-checkpoint.sh
chmod 750 /usr/local/sbin/ivanov-local-checkpoint.sh
/usr/local/sbin/ivanov-local-checkpoint.sh
```

Добавить через `crontab -e` пользователя root:

```cron
12 * * * * /usr/local/sbin/ivanov-local-checkpoint.sh >>/var/log/ivanov-local-checkpoint.log 2>&1
```

Перед выходом из root повторно запустить checkpoint-скрипт и проверить `crontab -l`.

## 5.3. Handoff-файлы перед закрытием root-сессии

Создать безопасный временный каталог для продолжения под `dev`:

```bash
install -d -m 700 -o dev -g dev /home/dev/.server-setup
```

Туда помещаются текущая копия этого гайда и `server-setup-state.md` с несекретными результатами ROOT-части. Оба файла должны принадлежать `dev:dev` и иметь режим `600`.

State должен как минимум содержать:

```text
phase=DEV
root_phase=completed
project_root=...
web_root=...
github_work_tree=...
client_slug=...
github_repo=...
codex_sdk_for_dev=verified
```

Не записывать туда токены, пароли, private keys и webhook secrets.

# ГРАНИЦА ROOT → DEV

На этом основной ROOT-блок заканчивается.

Не держать root Remote SSH открытым «на всякий случай». Пользователь полностью закрывает root connection и открывает новое VS Code Remote SSH connection под `dev`. В новой сессии продолжение начинается только с DEV-части ниже.

# ЧАСТЬ II — DEV

С этого места все команды нормального маршрута выполняются непосредственно под `dev`, без `runuser -u dev --`. Если какой-то шаг внезапно требует root, Codex останавливается и объясняет причину, а не молча смешивает две сессии.

Первые команды новой сессии:

```bash
whoami
echo "$HOME"
pwd
```

Ожидается:

```text
dev
/home/dev
```

Если Codex просит вход в ChatGPT, выполнить его один раз для пользователя `dev`. После входа проверить, что Codex отвечает и видит рабочую среду пользователя `dev`.

# 6. Приватная GitHub-репа

GitHub сохраняет `github_work_tree`. На новом типовом сервере это весь `web_root`. На уже работающем сервере с подтверждённым более узким scope используется именно он.

### 6.1. Deploy key

Для каждого клиента создаётся отдельный серверный SSH deploy key. Он привязан только к одной GitHub-репе и не является пользовательским ключом для входа на сервер.

Под `dev`:

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
ssh-keygen \
    -t ed25519 \
    -N "" \
    -C "ivanov GitHub deploy key" \
    -f ~/.ssh/id_ed25519_ivanov_github
cat ~/.ssh/id_ed25519_ivanov_github.pub
```

Публичную часть добавить:

```text
GitHub Repository → Settings → Deploy keys → Add deploy key → Allow write access
```

В `/home/dev/.ssh/config`:

```sshconfig
Host github-ivanov
    HostName github.com
    User git
    IdentityFile /home/dev/.ssh/id_ed25519_ivanov_github
    IdentitiesOnly yes
```

Права:

```bash
chmod 600 ~/.ssh/config
```

Проверка:

```bash
ssh -T github-ivanov
```

Сообщение GitHub об успешной аутентификации при отсутствии shell-доступа считается нормальным.

### 6.2. Отдельная Git metadata

Создать каталоги:

```bash
mkdir -p /home/dev/.gitdirs /home/dev/.local/bin
chmod 700 /home/dev/.gitdirs
chmod 755 /home/dev/.local/bin
```

Пример переменных:

```bash
github_work_tree="/var/www/client.example.ru/web"
github_git_dir="/home/dev/.gitdirs/ivanov-web"
```

На legacy-сервере `github_work_tree` может быть уже существующей подпапкой внутри `web/`; её не расширять без отдельного решения.

Инициализация:

```bash
git \
    --git-dir="$github_git_dir" \
    --work-tree="$github_work_tree" \
    init -b main
chmod 700 "$github_git_dir"
```

Создать wrapper `/home/dev/.local/bin/ivanov-git` с **фактическим** work tree:

```bash
#!/usr/bin/env bash
exec git \
    --git-dir="/home/dev/.gitdirs/ivanov-web" \
    --work-tree="/var/www/client.example.ru/web" \
    "$@"
```

Если фактический scope уже уже, в `--work-tree` указывается именно он.

Права и настройки:

```bash
chmod 755 /home/dev/.local/bin/ivanov-git
/home/dev/.local/bin/ivanov-git config user.name "Evgeny"
/home/dev/.local/bin/ivanov-git config user.email "server@client.example.ru"
/home/dev/.local/bin/ivanov-git remote add origin git@github-ivanov:YOUR_GITHUB_LOGIN/ivanov-web.git
```

Для этой репы используется wrapper, а не обычный `git`:

```bash
/home/dev/.local/bin/ivanov-git status
/home/dev/.local/bin/ivanov-git diff
/home/dev/.local/bin/ivanov-git log --oneline
```

## 7. Что отправляется на GitHub

На новом сервере `github_work_tree="$web_root"`, то есть в приватную репу уходит весь `web/` с учётом `.gitignore`.

На уже работающем сервере намеренно более узкий `github_work_tree` сохраняется как уникальное исключение. Codex обязан записать его в `server-setup-report.md` и не расширять автоматически.

### Отправляем

- код и необходимые статические файлы внутри фактического `github_work_tree`;
- небольшие uploads, если их решено хранить в Git;
- конфиги проекта, которые по принятой политике разрешено хранить в приватной репе;
- согласованный snapshot небольшой SQLite-базы, если он нужен.

### Не отправляем

- логи;
- cache и tmp;
- живой SQLite-файл и его `-wal`/`-shm`;
- root SSH keys;
- пользовательские SSH private keys;
- GitHub deploy private keys;
- платёжные ключи;
- cloud/admin-токены;
- один общий ключ, открывающий доступ сразу ко всем клиентам;
- временный `client-server-guide.md` и `server-setup-state.md`.

Пример `.gitignore` в корне фактического `github_work_tree`:

```gitignore
*.log
*.tmp
*.swp
*~
.DS_Store
Thumbs.db
/cache/
/tmp/
/runtime/
# Реальные пути живых баз проекта:
/data/app.sqlite
/data/app.sqlite-wal
/data/app.sqlite-shm
```

Не нужно глобально игнорировать `*.sqlite`, иначе можно исключить подготовленный snapshot.

## 8. Защита закрытых файлов от HTTP
Для единообразия закрытые конфиги располагаются в:

```text
web/private/
```

SQLite snapshots:

```text
web/.git-snapshots/
```

Если живая база физически находится внутри document root, её каталог также закрывается. Например:

```text
web/data/
```

Во всех перечисленных закрытых каталогах должен находиться `.htaccess`:

```apache
Options -Indexes
Require all denied
```

Apache 2.4 использует `Require all denied` для полного запрета доступа. Правила можно разместить в `.htaccess` либо в `<Directory>` конфигурации VirtualHost: [Apache access control](https://httpd.apache.org/docs/2.4/howto/access.html).

Если для этого сервера требовалась правка VirtualHost или `AllowOverride`, она должна была быть сделана и проверена в ROOT-части до handoff. В DEV-части Codex не возвращается в root только ради этого шага.

Проверка извне под `dev`:

```bash
curl -I https://client.example.ru/private/secrets.php
curl -I https://client.example.ru/.git-snapshots/sqlite/app.sqlite
curl -I https://client.example.ru/data/app.sqlite
```

Ожидается `403 Forbidden` или `404 Not Found`, но не `200 OK`.

Если неожиданно получен `200`, остановиться и показать пользователю проблему. Не продолжать GitHub-sync с незащищённым секретным/DB-путём.

## 9. Безопасный snapshot SQLite

Живой SQLite-файл нельзя считать надёжным backup простым копированием во время записи. Если базу нужно сохранять в GitHub, перед commit создаётся согласованная копия через штатную SQLite `.backup`, затем выполняется `PRAGMA integrity_check`.

Automation хранится внутри фактического `github_work_tree`, например:

```text
<github_work_tree>/.git-snapshots/sqlite/
<github_work_tree>/ops/github-sync.sh
```

Пример для стандартного случая, где `github_work_tree=/var/www/client.example.ru/web`:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail
github_work_tree="/var/www/client.example.ru/web"
web_git="/home/dev/.local/bin/ivanov-git"
snapshot_dir="$github_work_tree/.git-snapshots/sqlite"
lock_file="/home/dev/.cache/ivanov-github-sync.lock"
timestamp="$(date -u '+%Y-%m-%d %H:%M UTC')"
# Формат: абсолютный путь живой базы|имя snapshot-файла.
# Если SQLite нет: sqlite_databases=()
sqlite_databases=(
    "/var/www/client.example.ru/web/data/app.sqlite|app.sqlite"
)
mkdir -p /home/dev/.cache "$snapshot_dir"
exec 9>"$lock_file"
if ! flock -n 9; then
    echo "[$timestamp] Previous GitHub sync is still running; skipping."
    exit 0
fi
for database_entry in "${sqlite_databases[@]}"; do
    IFS='|' read -r source_database snapshot_name <<<"$database_entry"
    if [ ! -f "$source_database" ]; then
        echo "[$timestamp] SQLite database not found: $source_database" >&2
        exit 1
    fi
    snapshot_path="$snapshot_dir/$snapshot_name"
    temporary_snapshot="$snapshot_path.tmp"
    rm -f "$temporary_snapshot"
    sqlite3 "$source_database" ".timeout 5000" ".backup '$temporary_snapshot'"
    integrity_result="$(sqlite3 "$temporary_snapshot" 'PRAGMA integrity_check;')"
    if [ "$integrity_result" != "ok" ]; then
        rm -f "$temporary_snapshot"
        echo "[$timestamp] SQLite integrity check failed: $source_database" >&2
        exit 1
    fi
    mv -f "$temporary_snapshot" "$snapshot_path"
done
"$web_git" add -A
if ! "$web_git" diff --cached --quiet; then
    "$web_git" commit -m "Automated web checkpoint: $timestamp"
else
    echo "[$timestamp] No web changes."
fi
"$web_git" push origin main
```

Путь каждой живой базы обязательно исключить в `.gitignore`; в Git попадает только snapshot.

Sync-скрипт создаётся под `dev` и имеет режим `750`:

```bash
chmod 750 "/фактический/github_work_tree/ops/github-sync.sh"
```

## 10. Первый GitHub push и dev-cron

Первый sync запускается вручную под `dev` по **фактическому абсолютному пути** скрипта.

Стандартный пример:

```bash
/var/www/client.example.ru/web/ops/github-sync.sh
```

После запуска:

```bash
/home/dev/.local/bin/ivanov-git status
/home/dev/.local/bin/ivanov-git log -3 --oneline
```

На новом типовом сервере в GitHub должна появиться вся структура `web/` согласно `.gitignore`. На legacy-сервере с подтверждённым узким scope — только этот scope.

Dev-cron содержит абсолютный путь фактического sync-скрипта. Стандартный пример:

```cron
17 * * * * /var/www/client.example.ru/web/ops/github-sync.sh >>/var/www/client.example.ru/web/private/github-sync.log 2>&1
```

Для узкого legacy-scope путь меняется соответственно. Перед добавлением строки сохраняется существующий crontab и проверяется отсутствие дубликата.

## 11. Финальная проверка под dev

ROOT-проверки (`www-data`, Apache configtest, root checkpoint, root-cron) уже выполнены до handoff и в нормальном маршруте здесь не повторяются.

### 11.1. Права текущего пользователя

Под `dev`:

```bash
if test -w "$project_root"; then
    echo "ERROR: dev can write project root"
else
    echo "OK: dev cannot write project root"
fi

if test -w "$web_root"; then
    echo "OK: dev can write web"
else
    echo "ERROR: dev cannot write web"
fi

if touch "$project_root/.dev-write-test" 2>/dev/null; then
    rm -f "$project_root/.dev-write-test"
    echo "ERROR: dev created a file above web"
else
    echo "OK: write above web was rejected"
fi

touch "$web_root/.dev-write-test"
rm -f "$web_root/.dev-write-test"
echo "OK: write inside web works"
```

Обычные файлы после настройки не должны неожиданно получить executable-бит.

### 11.2. GitHub-контур

```bash
/home/dev/.local/bin/ivanov-git status
/var/www/client.example.ru/web/ops/github-sync.sh
/home/dev/.local/bin/ivanov-git status
```

Повторный запуск должен сообщить, что изменений нет, и не создавать пустой commit.

### 11.3. Cron

```bash
systemctl is-active cron
crontab -l
```

В текущей dev-сессии `crontab -l` должен содержать GitHub checkpoint и остальные проектные задания `dev`. Root-cron уже был проверен до handoff.

### 11.4. SQLite и HTTP

```bash
sqlite3 "$web_root/.git-snapshots/sqlite/app.sqlite" 'PRAGMA integrity_check;'
```

Ожидается `ok`.

Закрытые HTTP-пути должны возвращать `403` или `404`. Публичная главная страница должна возвращать `200`.

## 12. Повседневная работа
1. Подключиться к серверу через VS Code как `dev`.

2. Открыть только `/var/www/<домен>/web`.

3. Работать и проверять сайт непосредственно на сервере.

4. Ничего вручную коммитить для checkpoint не обязательно.

5. Root-cron раз в час сохраняет весь проект локально.

6. Dev-cron раз в час создаёт SQLite snapshot при необходимости и пушит фактический `github_work_tree` в приватный GitHub.

Нужно помнить: автоматический checkpoint может сохранить незавершённую или временно сломанную работу. Для этой модели это нормально — Git используется как журнал состояния, а не как процесс code review.

Раз в месяц достаточно смотреть размер Git metadata:

```bash
du -sh /home/dev/.gitdirs/ivanov-web
du -sh /var/www/client.example.ru/.git
```

Если небольшая SQLite-база или uploads начинают заметно раздувать историю, их стратегию пересматривают отдельно. Для маленького клиентского сайта преждевременно усложнять схему не нужно.

## 13. Если что-то не работает
### GitHub push — под dev
```bash
ssh -T github-ivanov
/home/dev/.local/bin/ivanov-git status
tail -n 100 /var/www/client.example.ru/web/private/github-sync.log
```

Проверить:

- deploy key добавлен именно в нужную репу;

- включён `Allow write access`;

- remote использует SSH alias `github-ivanov`;

- приватный ключ принадлежит `dev` и имеет права `600`;

- GitHub-репа не содержит отдельной несовместимой истории.

### Локальный checkpoint — требует root

Эта диагностика не является частью обычной DEV-сессии. Если реально сломан root checkpoint, закрыть dev Remote SSH и открыть отдельное root-подключение.

Под root:

```bash
/usr/local/sbin/ivanov-local-checkpoint.sh
git -C /var/www/client.example.ru status --short
tail -n 100 /var/log/ivanov-local-checkpoint.log
```

Этот скрипт должен запускаться root. `dev` не должен иметь доступ к родительскому `.git`.

### Права сайта

Базовую диагностику под `dev` можно начать с:

```bash
namei -l /var/www/client.example.ru/web
getfacl /var/www/client.example.ru/web
find /var/www/client.example.ru/web -xdev -type f -perm /111 -print
```

Проверка от имени `www-data` и изменение Apache требуют root. Если они действительно нужны, это отдельная root-диагностика, а не продолжение обычного DEV-маршрута.

Под root после изменения Apache:

```bash
runuser -u www-data -- test -r /var/www/client.example.ru/web/index.php
apachectl configtest
systemctl reload apache2
```

### Codex под dev не запускается после переключения

Сначала проверить, что cache действительно содержит полноценный binary:

```bash
find ~/.vscode-server/data/agent-host/sdk-cache/codex \
    -type f \
    -path '*/linux-x64/node_modules/@openai/codex-linux-x64/vendor/x86_64-unknown-linux-musl/bin/codex' \
    -ls
```

Если каталоги версий есть, но `bin/codex` отсутствует, это недокачанный cache. В нормальной новой установке он должен был быть заменён рабочей root-копией в разделе 4.8. Не считать пустой каталог успешной установкой.

## 14. Восстановление после ошибки
### Случайно испорчен файл внутри web
Найти нужную версию через GitHub-историю и восстановить конкретный файл. Не выполнять массовый reset всего production-каталога без проверки списка изменений.

### Сломан весь web
1. Сохранить текущую сломанную папку отдельно.

2. Получить последнюю версию приватной GitHub-репы.

3. Восстановить production `web/`.

4. Если нужна база, восстановить её из `.git-snapshots/sqlite/` при остановленной записи приложения.

5. Восстановить исходные owner/group/mode production-файлов и повторно применить персональный ACL для `dev`; права `www-data` вернуть только подтверждённым writable-каталогам.

6. Проверить Apache, PHP и cron.

### Удалён весь сервер
GitHub вернёт содержимое фактического `github_work_tree`. На новом типовом сервере это весь `web/`; на legacy-сервере с узким scope — только сохранённая подпапка. Верхний Yii-код, который пользователь или программист уже писал вне `web/` и который существовал только в локальном Git сервера, при полном удалении сервера не восстановится. Если этот код тоже требуется защищать от потери всего сервера, для него следует отдельно настроить удалённую репу — это выходит за рамки данного гайда.

## 15. Контрольный чек-лист готовности клиентского сервера
- [ ] Проверены RAM, swap и свободное место на `/`.
- [ ] Создан `dev` без sudo.

- [ ] Для `dev` не создана лишняя общая группа; доступ внутри `web/` выдан персональным ACL.
- [ ] ACL/metadata backup хранится в постоянном root-only каталоге, а не в `/tmp`.

- [ ] `dev` пишет внутри `web/` и не пишет выше.

- [ ] Существующие owner/group production-файлов не были массово переопределены ради `dev`.

- [ ] Новые файлы и каталоги внутри `web/` наследуют доступ `dev` через default ACL.

- [ ] Обычные файлы внутри `web/` не получили лишний executable-бит.

- [ ] `www-data` пишет только в подтверждённые writable-каталоги приложения.

- [ ] Локальный `.git` всего проекта принадлежит root и не имеет remote.

- [ ] Root checkpoint-скрипт работает вручную.

- [ ] Root-cron содержит почасовой checkpoint.

- [ ] Рабочий bundled Codex SDK заранее скопирован из root-cache в `/home/dev/.vscode-server/.../sdk-cache/codex/` и проверен запуском от `dev`.

- [ ] ChatGPT credentials root не копировались; `dev` авторизован отдельно.

- [ ] Общая серверная Codex-среда (Superpowers + глобальный AGENTS.md) подключена к root и dev по единой схеме.

- [ ] ROOT-часть закончена до начала основной DEV-части; root Remote SSH не остаётся рабочей сессией для обычной разработки.

- [ ] Создана отдельная приватная GitHub-репа клиента.

- [ ] Создан уникальный deploy key с write access только к этой репе.

- [ ] GitHub metadata находится вне `web/`.

- [ ] Wrapper `<client_slug>-git` работает.

- [ ] Логи, cache, tmp и живые SQLite-файлы исключены из Git.

- [ ] SQLite snapshot проходит `PRAGMA integrity_check`.

- [ ] Закрытые конфиги и snapshots недоступны по HTTP.

- [ ] Dev-cron содержит почасовой GitHub checkpoint.

- [ ] Повторный запуск обоих скриптов не создаёт пустых коммитов.
- [ ] Фактический GitHub scope подтверждён; на новом сервере это весь `web/`, legacy-исключения не расширены.
- [ ] Временный гайд и state-файл удалены, в GitHub остался только setup report.

## 16. Принятый уровень безопасности
Эта схема сознательно допускает хранение обычных клиентских API-ключей и webhook URL в приватной клиентской репе ради простого восстановления. Риск принимается при условиях:

- репа всегда приватная;

- доступ есть только у владельца;

- на каждом сервере отдельный deploy key;

- ключ имеет доступ только к одной репе;

- GitHub Apps и лишние collaborators не подключаются;

- старый секрет при замене отзывается.

Удаление секрета новым коммитом не удаляет его из старой Git-истории. При реальной утечке секрет сначала отзывается или перевыпускается; очистка истории является отдельной процедурой: [рекомендации GitHub](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

Критические root/GitHub/payment/cloud credentials в репозиторий не помещаются даже при этой упрощённой модели.