# Типовой сервер для работы через VS Code и Codex
Этот документ описывает повторяемую настройку клиентского сервера под простой рабочий процесс:

- программист устанавливает Ubuntu, Apache, PHP и Yii2;

- рабочий проект находится в `/var/www/<домен>/`;

- публичная и редактируемая часть находится в `/var/www/<домен>/web/`;

- пользователь `dev` работает через VS Code и имеет полный доступ только внутри `web/`;

- локальный Git сохраняет checkpoint всего проекта;

- отдельная приватная GitHub-репа сохраняет содержимое `web/`;

- оба checkpoint выполняются автоматически раз в час.

Это прагматичная модель 80/20, а не банковская инфраструктура. Она защищает от случайного удаления и неудачных правок, но не является полноценным disaster recovery всего сервера.

Гайд предназначен как для новых, так и для давно работающих клиентских серверов. На сервере уже могут находиться рабочий сайт, Yii-код программиста, пользовательские данные, cron-задания и одна или несколько Git-историй. Всё существующее считается важным и сохраняется, пока аудит явно не докажет обратное. На новых серверах GitHub по умолчанию сохраняет весь `web/`. Если на существующем сервере уже настроен намеренно более узкий GitHub scope, он сохраняется как исключение и не расширяется автоматически.

## 0. Как пользоваться этим гайдом

Пользователю не нужно самостоятельно разбираться в разделах ниже, заранее готовить команды или решать, что запускать следующим. Технические разделы являются рабочей инструкцией для Codex.

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
18. довести настройку до практической проверки, а не ограничиваться созданием файлов.

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

После завершения state удаляется, а в фактическом GitHub work tree создаётся `docs/server-setup-report.md`.

## 0.7. Полный маршрут сопровождения

| Этап | Кто работает | Результат, без которого нельзя идти дальше |
|---|---|---|
| 0. Read-only аудит | Codex в root-сессии | Определены пути, пользователи, права, Git, cron, Apache, ресурсы и данные |
| 1. Уточнения | Пользователь + Codex | Известны client slug, GitHub repo и фактический GitHub scope |
| 2. SSH-доступ dev | root + пользователь | Пользователь реально вошёл по SSH как `dev` |
| 3. Локальный checkpoint | root | Создан/подтверждён первый checkpoint всего проекта |
| 4. Root automation | root | Root checkpoint и cron проверены вручную |
| 5. Ограничение прав | root | `dev` пишет в `web/`, не пишет выше, owners/groups не сломаны |
| 6. Переподключение | пользователь | VS Code и Codex действительно работают как `dev` |
| 7. GitHub deploy key | dev + пользователь | `ssh -T` подтверждает доступ к одной клиентской репе |
| 8. GitHub-контур | Codex как dev | Отдельная Git metadata и wrapper работают |
| 9. Данные и HTTP | Codex как dev, при необходимости root | SQLite snapshot целый, закрытые URL дают 403/404 |
| 10. Dev automation | dev | Ручной GitHub-sync и первый push успешны |
| 11. Финальная проверка | Codex + пользователь | Все тесты пройдены, создан report, временный гайд удалён |

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

## 0.9. Этапы 2–5 — контролируемая root-настройка

До ограничения прав Codex:

- создаёт/проверяет `dev` без sudo;
- устанавливает необходимые пакеты;
- создаёт исходный checkpoint;
- сохраняет существующие cron и `.gitignore`;
- не переинициализирует уже корректный Git;
- не меняет owner/group всего production-дерева ради `dev`;
- настраивает root checkpoint с lock в `/run/lock`;
- оставляет `www-data` запись только там, где она реально нужна приложению.

После root-настройки пользователь полностью закрывает root-подключение VS Code и открывает проект как `dev`. Первые проверки новой сессии:

```bash
whoami
pwd
```

## 0.10. Этапы 7–10 — GitHub под dev

Для GitHub создаётся **отдельный** deploy key без passphrase. Он привязан только к одной клиентской репе и создаётся независимо от пользовательского SSH-ключа Windows.

После добавления deploy key Codex:

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

## 0.11. Финальная приёмка

Codex практически проверяет:

- `dev` не может создать файл выше `web/`;
- `dev` может создать, изменить и удалить файл внутри `web/`;
- `www-data` пишет только в подтверждённые writable-каталоги;
- новые объекты внутри `web/` наследуют доступ `dev`;
- обычные файлы не получили ложный executable-бит;
- root checkpoint работает вручную;
- GitHub-sync работает вручную;
- повторный запуск не создаёт пустые коммиты;
- SQLite snapshot возвращает `PRAGMA integrity_check = ok`, если SQLite используется;
- закрытые URL возвращают 403/404;
- публичный сайт отвечает ожидаемым HTTP status;
- cron содержит нужные строки без дубликатов.

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

- создаёт локальные checkpoint-коммиты.

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

# 4. Создание dev и прав на web
Этот раздел выполняет `root`.

### 4.1. Проверка пути
```bash
test -d "$project_root"
test -d "$web_root"
realpath "$project_root"
realpath "$web_root"
```

Ожидается, что `web_root` равен ровно `project_root/web`. Если путь отличается, команды ниже сначала адаптирует программист.

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

До изменения production-прав пользователь практически проверяет вход под `dev`. Если вход не работает, дальнейшая настройка прав не выполняется.

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

## 6. Приватная GitHub-репа

GitHub сохраняет `github_work_tree`. На новом типовом сервере это весь `web_root`. На уже работающем сервере с подтверждённым более узким scope используется именно он.

### 6.1. Deploy key

Для каждого клиента создаётся отдельный серверный SSH deploy key. Он привязан только к одной GitHub-репе и не является пользовательским ключом для входа на сервер.

Под `root`:

```bash
install -d -m 700 -o dev -g dev /home/dev/.ssh
runuser -u dev -- ssh-keygen \
    -t ed25519 \
    -N "" \
    -C "ivanov GitHub deploy key" \
    -f /home/dev/.ssh/id_ed25519_ivanov_github
cat /home/dev/.ssh/id_ed25519_ivanov_github.pub
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
chown dev:dev /home/dev/.ssh/config
chmod 600 /home/dev/.ssh/config
```

Проверка:

```bash
runuser -u dev -- ssh -T github-ivanov
```

Сообщение GitHub об успешной аутентификации при отсутствии shell-доступа считается нормальным.

### 6.2. Отдельная Git metadata

Создать каталоги:

```bash
install -d -m 700 -o dev -g dev /home/dev/.gitdirs
install -d -m 755 -o dev -g dev /home/dev/.local/bin
```

Пример переменных:

```bash
github_work_tree="/var/www/client.example.ru/web"
github_git_dir="/home/dev/.gitdirs/ivanov-web"
```

На legacy-сервере `github_work_tree` может быть уже существующей подпапкой внутри `web/`; её не расширять без отдельного решения.

Инициализация:

```bash
runuser -u dev -- git \
    --git-dir="$github_git_dir" \
    --work-tree="$github_work_tree" \
    init -b main
chmod 700 "$github_git_dir"
chown -R dev:dev "$github_git_dir"
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
chown dev:dev /home/dev/.local/bin/ivanov-git
chmod 755 /home/dev/.local/bin/ivanov-git
runuser -u dev -- /home/dev/.local/bin/ivanov-git config user.name "Evgeny"
runuser -u dev -- /home/dev/.local/bin/ivanov-git config user.email "server@client.example.ru"
runuser -u dev -- /home/dev/.local/bin/ivanov-git remote add origin git@github-ivanov:YOUR_GITHUB_LOGIN/ivanov-web.git
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

Apache 2.4 использует `Require all denied` для полного запрета доступа. Правила можно разместить в `.htaccess` либо, что надёжнее при доступе программиста к Apache, в `<Directory>` конфигурации VirtualHost: [Apache access control](https://httpd.apache.org/docs/2.4/howto/access.html).

Пример VirtualHost:

```apache
<Directory "/var/www/client.example.ru/web/private">
    Require all denied
</Directory>
<Directory "/var/www/client.example.ru/web/.git-snapshots">
    Require all denied
</Directory>
<Directory "/var/www/client.example.ru/web/data">
    Require all denied
</Directory>
```

После изменения VirtualHost:

```bash
apachectl configtest
systemctl reload apache2
```

Проверка извне:

```bash
curl -I https://client.example.ru/private/secrets.php
curl -I https://client.example.ru/.git-snapshots/sqlite/app.sqlite
curl -I https://client.example.ru/data/app.sqlite
```

Ожидается `403 Forbidden` или `404 Not Found`, но не `200 OK`.

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

Sync-скрипт принадлежит `dev` и имеет режим `750`:

```bash
chown dev:dev "/фактический/github_work_tree/ops/github-sync.sh"
chmod 750 "/фактический/github_work_tree/ops/github-sync.sh"
```

## 10. Первый GitHub push и dev-cron

Первый sync запускается вручную от `dev` по **фактическому абсолютному пути** скрипта.

Стандартный пример:

```bash
runuser -u dev -- /var/www/client.example.ru/web/ops/github-sync.sh
```

После запуска:

```bash
runuser -u dev -- /home/dev/.local/bin/ivanov-git status
runuser -u dev -- /home/dev/.local/bin/ivanov-git log -3 --oneline
```

На новом типовом сервере в GitHub должна появиться вся структура `web/` согласно `.gitignore`. На legacy-сервере с подтверждённым узким scope — только этот scope.

Dev-cron содержит абсолютный путь фактического sync-скрипта. Стандартный пример:

```cron
17 * * * * /var/www/client.example.ru/web/ops/github-sync.sh >>/var/www/client.example.ru/web/private/github-sync.log 2>&1
```

Для узкого legacy-scope путь меняется соответственно. Перед добавлением строки сохраняется существующий crontab и проверяется отсутствие дубликата.

## 11. Финальная проверка
### 11.1. Права
Под root:

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
```

Практический тест:

```bash
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

Дополнительно Codex проверяет ACL и наследование на практике: создаёт тестовые файл и каталог от имени `www-data` внутри одного подтверждённого writable-каталога, убеждается, что `dev` может их изменить и удалить, затем полностью удаляет тестовые объекты. Обычные файлы после настройки не должны неожиданно получить executable-бит.

Также проверяется, что `www-data` может писать только в список подтверждённых writable-каталогов, а в остальных каталогах `web/` запись запрещена.

### 11.2. Git
```bash
# root
git -C "$project_root" status --short
/usr/local/sbin/ivanov-local-checkpoint.sh
# GitHub-контур от dev
runuser -u dev -- /home/dev/.local/bin/ivanov-git status
runuser -u dev -- /var/www/client.example.ru/web/ops/github-sync.sh
```

Обе команды после повторного запуска должны сообщить, что изменений нет, и не создавать пустые коммиты.

### 11.3. Cron
```bash
systemctl is-active cron
crontab -l
crontab -u dev -l
```

Root должен видеть собственный local-checkpoint. Через `crontab -u dev -l` он видит GitHub checkpoint и остальные проектные задания `dev`.

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
### GitHub push
```bash
runuser -u dev -- ssh -T github-ivanov
runuser -u dev -- /home/dev/.local/bin/ivanov-git status
tail -n 100 /var/www/client.example.ru/web/private/github-sync.log
```

Проверить:

- deploy key добавлен именно в нужную репу;

- включён `Allow write access`;

- remote использует SSH alias `github-ivanov`;

- приватный ключ принадлежит `dev` и имеет права `600`;

- GitHub-репа не содержит отдельной несовместимой истории.

### Локальный checkpoint
```bash
/usr/local/sbin/ivanov-local-checkpoint.sh
git -C /var/www/client.example.ru status --short
tail -n 100 /var/log/ivanov-local-checkpoint.log
```

Этот скрипт должен запускаться root. `dev` не должен иметь доступ к родительскому `.git`.

### Права сайта
```bash
namei -l /var/www/client.example.ru/web
getfacl /var/www/client.example.ru/web
find /var/www/client.example.ru/web -xdev -type f -perm /111 -print
runuser -u www-data -- test -r /var/www/client.example.ru/web/index.php
```

После изменения Apache:

```bash
apachectl configtest
systemctl reload apache2
```

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