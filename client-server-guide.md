**# Типовой сервер для работы через VS Code и Codex**

Этот документ описывает повторяемую настройку клиентского сервера под простой рабочий процесс:

\- программист устанавливает Ubuntu, Apache, PHP и Yii2;

\- рабочий проект находится в \`/var/www/<домен>/\`;

\- публичная и редактируемая часть находится в \`/var/www/<домен>/web/\`;

\- пользователь \`dev\` работает через VS Code и имеет полный доступ только внутри \`web/\`;

\- локальный Git сохраняет checkpoint всего проекта;

\- отдельная приватная GitHub-репа сохраняет содержимое \`web/\`;

\- оба checkpoint выполняются автоматически раз в час.

Это прагматичная модель 80/20, а не банковская инфраструктура. Она защищает от случайного удаления и неудачных правок, но не является полноценным disaster recovery всего сервера.

Гайд предназначен как для новых, так и для давно работающих клиентских серверов. На сервере уже могут находиться рабочий сайт, Yii-код программиста, пользовательские данные, cron-задания и одна или несколько Git-историй. Всё существующее считается важным и сохраняется, пока аудит явно не докажет обратное. Гайд не меняет задним числом политику текущего Steam Tracker, где реальные секреты и runtime-данные пока исключены из GitHub.

**## 0. Как пользоваться этим гайдом**

Пользователю не нужно самостоятельно разбираться в разделах ниже, заранее готовить команды или решать, что запускать следующим. Технические разделы являются рабочей инструкцией для Codex.

**### 0.1. Единственный стартовый запрос**

На нужном сервере приложить этот файл к чату или положить его в доступный каталог и написать:

\`\`\`text

Прочитай client-server-guide.md полностью.

Настраиваем на этом сервере рабочий контур по гайду.

Веди меня по одному шагу за раз, начиная с шага 0.

\`\`\`

Этого достаточно. Все дополнительные сведения Codex должен либо определить сам, либо запросить в нужный момент.

Если гайд передан только как read-only attachment, Codex после определения \`web\_root\` должен сохранить его рабочую копию в:

\`\`\`text

\<web\_root>/docs/client-server-guide.md

\`\`\`

Рабочая копия попадёт в приватную GitHub-репу клиента и останется доступна после переноса сервера.

**### 0.2. Обязательный режим работы Codex**

Получив стартовый запрос, Codex обязан:

1\. полностью прочитать этот файл до начала изменений;

2\. создать план настройки и вести только один активный этап;

3\. сначала выполнить read-only аудит, а уже потом что-либо менять;

4\. самостоятельно получать сведения, доступные на сервере, а не спрашивать их у пользователя;

5\. задавать вопрос только тогда, когда ответ нельзя безопасно определить автоматически;

6\. не выдавать пользователю весь гайд или десяток команд сразу;

7\. давать ровно один логический шаг или один готовый блок команд;

8\. явно писать, где выполняется команда: Windows PowerShell, root shell или dev shell;

9\. перед продолжением проверять результат предыдущего шага;

10\. при ошибке остановиться, изучить фактическое состояние и дать исправленную команду;

11\. не просить пользователя самостоятельно интерпретировать вывод;

12\. сохранять существующие cron-задания, \`.gitignore\`, Apache-конфигурацию и Git-истории;

13\. не применять массовые \`chmod\`, \`chown\`, \`chgrp\`, удаления или force-push без точного определения цели; для доступа \`dev\` внутри существующего production-дерева предпочитать персональный ACL без смены владельцев и групп;

14\. не выводить в чат приватные SSH-ключи и действующие секреты;

15\. считать существующий код внутри и выше \`web/\` рабочим production-кодом независимо от того, писал его пользователь или Yii-программист;

16\. не удалять, не переносить и не объединять существующие файлы только ради «чистой структуры»;

17\. перед первым изменением создать или подтвердить исходный checkpoint;

18\. довести настройку до практической проверки, а не ограничиваться созданием файлов.

Плохой формат сопровождения:

\`\`\`text

Вот двадцать команд. Замени переменные, запусти всё и разберись с ошибками.

\`\`\`

Правильный формат:

\`\`\`text

Шаг 3 из 10 — проверяем вход под dev.

Эту команду выполни в Windows PowerShell:

ssh dev\@client.example.ru

Пришли мне точный вывод. До подтверждения входа права выше web не закрываю.

\`\`\`

**### 0.3. Codex не должен путать PowerShell и Linux shell**

Команды вида \`chmod\`, \`chown\`, \`find\`, \`crontab\`, Bash heredoc и Linux-пути выполняются только после SSH-подключения на сервер.

Если пользователю нужно сначала войти на сервер, Codex даёт две отдельные команды:

Windows PowerShell:

\`\`\`powershell

ssh root\@client.example.ru

\`\`\`

После появления приглашения \`root\@server:\~#\` — Linux shell:

\`\`\`bash

bash /точный/путь/к/подготовленному-скрипту.sh

\`\`\`

Codex не должен предлагать Bash-конструкцию \`<<'EOF'\` непосредственно в Windows PowerShell. Для длинной root-настройки он создаёт проверенный одноразовый \`.sh\` внутри \`web/\`, а пользователь запускает его одной короткой командой из root shell.

**### 0.4. Минимальные вопросы пользователю**

После read-only аудита Codex собирает только недостающие ответы. Обычно нужны:

1\. название клиента или желаемый \`client\_slug\`;

2\. GitHub login и имя приватной репы;

3\. является ли GitHub-репа новой пустой репой или в ней уже есть история;

4\. публичный SSH-ключ пользователя для входа под \`dev\`, если его ещё нет на сервере;

5\. какие найденные секреты разрешено хранить в приватной репе;

6\. какие из найденных SQLite-баз и uploads нужно сохранять.

Не следует спрашивать пользователя о пути проекта, Unix-правах, владельце Apache, существующих cron или Git remote, пока Codex не попытался определить это командами \`pwd\`, \`realpath\`, \`id\`, \`stat\`, \`find\`, \`crontab\` и \`git\`.

Если приватная GitHub-репа ещё не создана, Codex даёт один GUI-шаг:

\`\`\`text

GitHub → New repository → имя \<client\_slug>-web → Private.

Не добавлять README, .gitignore и License.

После создания прислать OWNER/REPOSITORY.

\`\`\`

Если репа уже существует, пользователь просто сообщает \`OWNER/REPOSITORY\`. Codex не требует создавать новую и позже сравнивает её историю с production-файлами.

**### 0.5. Сохранение прогресса между root и dev**

Настройка обязательно потребует переподключения VS Code с \`root\` на \`dev\`. Чтобы новый чат или новая сессия продолжила с правильного места, Codex создаёт:

\`\`\`text

\<web\_root>/docs/server-setup-state.md

\`\`\`

В этом файле хранятся только несекретные сведения:

\- текущий этап;

\- \`client\_slug\`;

\- \`project\_root\` и \`web\_root\`;

\- пользователь Apache;

\- GitHub \`OWNER/REPOSITORY\`;

\- имя SSH alias, wrapper и путей automation;

\- какие проверки уже пройдены;

\- какой следующий шаг требуется.

Нельзя сохранять туда приватные SSH-ключи, пароли, API tokens и webhook URL.

После полного завершения файл превращается в краткий \`docs/server-setup-report.md\`, а временные root-скрипты удаляются.

После переподключения пользователь говорит только:

\`\`\`text

Прочитай client-server-guide.md и server-setup-state.md.

Продолжай настройку с указанного шага и веди меня дальше.

\`\`\`

**### 0.6. Полный маршрут сопровождения**

Codex ведёт пользователя по следующим этапам строго по порядку.

\| Этап | Кто работает | Результат, без которого нельзя идти дальше |

\|---|---|---|

\| 0. Read-only аудит | Codex в root-сессии | Определены пути, пользователи, права, Git, cron, Apache и данные |

\| 1. Уточнения | Пользователь + Codex | Известны client slug, GitHub repo и политика данных |

\| 2. SSH-доступ dev | root + пользователь | Пользователь реально вошёл по SSH как \`dev\` |

\| 3. Локальный checkpoint | root | Создан первый коммит всего проекта, remote отсутствует |

\| 4. Root automation | root | Скрипт и root-cron успешно запущены вручную |

\| 5. Ограничение прав | root | \`dev\` пишет в \`web/\` и не пишет выше него |

\| 6. Переподключение | Пользователь | VS Code и Codex действительно работают как \`dev\` |

\| 7. GitHub deploy key | dev + пользователь | \`ssh -T\` подтверждает доступ к одной клиентской репе |

\| 8. GitHub-контур | Codex как dev | Отдельная Git metadata и wrapper работают |

\| 9. Данные и HTTP | Codex как dev, при необходимости root | SQLite snapshot целый, закрытые пути дают 403/404 |

\| 10. Dev automation | dev | Ручной запуск GitHub-sync и первый push успешны |

\| 11. Финальная проверка | Codex + пользователь | Пройдены все проверки раздела 11 и создан setup report |

Codex не отмечает этап выполненным только потому, что команда завершилась без ошибки. Он проверяет ожидаемое состояние отдельной read-only командой.

**### 0.7. Подробный сценарий диалога**

**#### Этап 0 — аудит без изменений**

Codex сообщает, что пока ничего не меняет, и проверяет:

\`\`\`text

whoami и группы;

реальный project\_root и web\_root;

владельцев и режимы каталогов;

наличие dev, его групп и существующих ACL;

пользователя Apache/PHP;

существующие writable-каталоги;

локальный Git root, branch, status и remotes;

вложенные .git;

root-cron и dev-cron;

SQLite, uploads, cache, logs и секретные конфиги;

существующий код внутри web и Yii-код выше web;

AllowOverride и действующие правила закрытия файлов.

\`\`\`

Результат аудита Codex кратко пересказывает пользователю: что уже настроено, что будет изменено и что останется нетронутым. Если над \`web/\` найден важный Yii-код, Codex отдельно предупреждает: текущая схема отправляет на GitHub только \`web/\`, а верхний код получает лишь локальные checkpoint-коммиты на этом же сервере. Самостоятельно расширять GitHub scope нельзя.

**#### Этап 1 — только необходимые решения**

Codex задаёт не более трёх коротких вопросов одновременно. Если ответ уже содержится в этом гайде или найден на сервере, повторно его не спрашивает.

**#### Этап 2 — создание dev**

Если \`dev\` отсутствует, Codex сначала получает публичный пользовательский SSH-ключ.

Если у пользователя нет ключа, Codex даёт одну команду Windows PowerShell:

\`\`\`powershell

ssh-keygen -t ed25519

\`\`\`

После её завершения — отдельную команду:

\`\`\`powershell

Get-Content $env\:USERPROFILE\\.ssh\id\_ed25519.pub

\`\`\`

Пользователь присылает только строку, начинающуюся с \`ssh-ed25519\`. Codex добавляет её в \`/home/dev/.ssh/authorized\_keys\`, не копируя туда неизвестные ключи из root.

До изменения прав пользователь открывает второе окно PowerShell и практически проверяет:

\`\`\`powershell

ssh dev\@client.example.ru

\`\`\`

Если вход не работает, переход к ограничению прав запрещён.

**#### Этапы 3–5 — контролируемая root-настройка**

Codex собирает root-действия в одноразовый скрипт, например:

\`\`\`text

\<web\_root>/private/root-server-setup.sh

\`\`\`

Перед запуском он:

1\. показывает пользователю краткий список действий скрипта;

2\. проверяет \`bash -n\`;

3\. убеждается, что все пути абсолютные и относятся к текущему клиенту;

4\. не помещает секреты в вывод;

5\. даёт две отдельные команды: SSH login и запуск скрипта.

Скрипт должен:

\- сохранить существующие root-cron строки;

\- не перезаписать существующий \`.gitignore\` целиком;

\- создать исходный локальный checkpoint текущего рабочего состояния до изменения прав;

\- использовать существующий верхний Git, если он уже корректно настроен, вместо повторной инициализации;

\- установить root-only владельца верхнего \`.git\`;

\- настроить root checkpoint через отдельный lock-файл в \`/run/lock\`;

\- оставить \`www-data\` запись в runtime;

\- оставить \`dev\` полный доступ внутри \`web\`;

\- не выдавать \`dev\` sudo или доступ к root-cron.

После запуска Codex изучает точный вывод. При частичном выполнении он сначала проверяет фактические права и cron, а не запускает весь набор повторно вслепую.

**#### Этап 6 — обязательный выход из root-сессии**

После root-настройки пользователь полностью закрывает root-подключение VS Code и создаёт новое подключение как \`dev\`.

Первое действие Codex в новой сессии:

\`\`\`bash

whoami

pwd

\`\`\`

Ожидается \`dev\`, а workspace должен быть равен \`web\_root\` или находиться внутри него. Если Codex всё ещё работает как root, обычная работа не начинается.

**#### Этапы 7–10 — GitHub под dev**

Codex генерирует отдельный deploy key без passphrase, показывает пользователю только \`.pub\` и даёт один GUI-шаг для GitHub:

\`\`\`text

Repository → Settings → Deploy keys → Add deploy key → Allow write access.

\`\`\`

После ответа «ключ добавлен» Codex сам:

\- проверяет \`ssh -T\`;

\- создаёт отдельный Git dir вне \`web\`;

\- создаёт wrapper \`\<client\_slug>-git\`;

\- аккуратно объединяет \`.gitignore\`;

\- создаёт закрытые каталоги и Apache rules;

\- настраивает согласованный SQLite snapshot;

\- создаёт GitHub-sync script и проверяет его через \`bash -n\`;

\- сохраняет существующий dev-cron и добавляет почасовую строку;

\- проверяет staged files на лишние данные;

\- выполняет первый commit и push;

\- подтверждает, что local branch и \`origin/main\` не расходятся.

Если удалённая репа не пустая, это не считается ошибкой: там может находиться более ранняя версия рабочего сайта. Codex делает fetch, сравнивает обе стороны и не делает force-push. Он сохраняет существующую историю, объясняет найденные различия и предлагает безопасное объединение. Устаревшие файлы удаляются из актуальной версии только после подтверждения, что production их действительно больше не использует; в старых коммитах они остаются.

**#### Этап 11 — приёмка**

Codex выполняет не только \`test -w\`, но и практический тест создания файла:

\- создание выше \`web\` от \`dev\` должно завершиться \`Permission denied\`;

\- создание и удаление внутри \`web\` должно пройти;

\- root local checkpoint должен вручную отработать;

\- dev GitHub-sync должен вручную отработать;

\- второй запуск не должен создать пустые коммиты;

\- SQLite snapshot должен вернуть \`PRAGMA integrity\_check = ok\`;

\- секреты, живая база и snapshot не должны открываться по HTTP;

\- публичная страница должна вернуть ожидаемый HTTP status;

\- оба crontab должны содержать нужные строки без дубликатов.

Если root-only проверку нельзя выполнить из dev-сессии, Codex даёт пользователю одну короткую root-команду и просит прислать вывод.

**### 0.8. Финальный ответ Codex**

В конце Codex не пишет просто «готово». Он выдаёт компактный отчёт:

\`\`\`text

Права:

\- dev пишет только в .../web: проверено созданием файла;

\- выше web запись запрещена: проверено;

Локальный Git:

\- root репозиторий: \<path>;

\- последний checkpoint: \<hash>;

\- remote отсутствует;

\- root-cron: \<schedule>.

GitHub:

\- private repository: OWNER/REPO;

\- deploy key отдельный;

\- wrapper: \<path>;

\- origin/main синхронизирован, commit \<hash>;

\- dev-cron: \<schedule>.

Данные и HTTP:

\- SQLite snapshot: \<path>, integrity ok;

\- закрытые URL: 403/404;

\- публичная страница: 200.

Удалено после настройки:

\- временные root setup scripts.

\`\`\`

Также создаётся \`docs/server-setup-report.md\` без секретов. Благодаря этому следующему Codex не придётся заново выяснять уже принятую конфигурацию.

**## 1. Итоговая схема**

\| Контур | Что сохраняет | Где хранится | Кто запускает |

\|---|---|---|---|

\| Локальный checkpoint | Весь проект уровнем выше \`web/\`, кроме явно исключённого runtime | \`.git\` в корне проекта, без remote | \`root\` |

\| GitHub checkpoint | Только \`web/\` | Отдельная приватная репа клиента | \`dev\` |

\| SQLite snapshot | Безопасная копия небольшой живой базы | \`.git-snapshots/sqlite/\` внутри GitHub checkpoint | \`dev\` |

Пример:

\`\`\`text

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

\`\`\`

Внутри \`web/\` нет вложенной папки \`.git\`. Для GitHub используется отдельный \`--git-dir\` и реальная production-папка как \`--work-tree\`. Git поддерживает эти параметры штатно: [официальная документация Git]\(https\://git-scm.com/docs/git).

**## 2. Разделение прав**

**### root**

\`root\`:

\- владеет проектом выше \`web/\` и локальным \`.git\`;

\- устанавливает пакеты и меняет Apache/PHP;

\- управляет системными и root-cron заданиями;

\- может посмотреть и изменить cron любого пользователя;

\- создаёт локальные checkpoint-коммиты.

**### dev**

\`dev\`:

\- подключается через VS Code Remote SSH;

\- свободно создаёт, меняет и удаляет всё внутри \`web/\` через персональный ACL, не требующий смены владельцев и групп production-файлов;

\- запускает PHP, Composer, npm и проектные команды, если они не требуют root;

\- управляет только своим crontab;

\- пушит только клиентскую GitHub-репу;

\- не имеет \`sudo\` и записи выше \`web/\`.

У каждого Linux-пользователя свой crontab:

\`\`\`bash

# Текущий пользователь

crontab -l

# root смотрит задания dev

crontab -u dev -l

# root редактирует задания dev

crontab -u dev -e

\`\`\`

Возможность менять root-cron пользователю \`dev\` не выдаётся: это фактически root-доступ.

**### www-data**

\`www-data\` запускает Apache/PHP и пишет только туда, куда приложению действительно нужно: \`runtime/\`, логи, generated assets, uploads и рабочие базы.

**## 3. Что подготовить до настройки**

Для каждого клиента заранее определить:

\- \`client\_slug\` — короткое имя без пробелов, например \`ivanov\`;

\- \`project\_root\` — например \`/var/www/client.example.ru\`;

\- \`web\_root\` — всегда \`\<project\_root>/web\`;

\- имя приватной GitHub-репы;

\- путь к каждой живой SQLite-базе;

\- каталоги логов, cache, runtime и uploads;

\- какие секреты являются обычными клиентскими, а какие критическими.

Если GitHub-репа создаётся сейчас, рекомендуется оставить её пустой: без автоматически добавленных README, License и \`.gitignore\`. Тогда первый push с сервера не потребует объединять две истории. Для уже существующего клиента используется его действующая репа и сохраняется её история.

Все следующие Linux-команды выполняются **\*\*после SSH-подключения к серверу\*\***, а не напрямую в Windows PowerShell.

В примерах используются значения:

\`\`\`bash

client\_slug="ivanov"

project\_root="/var/www/client.example.ru"

web\_root="$project\_root/web"

github\_owner="YOUR\_GITHUB\_LOGIN"

github\_repo="ivanov-web"

\`\`\`

Перед выполнением обязательно заменить их на реальные.

Переменные действуют только в текущем SSH-сеансе. После нового подключения этот короткий блок нужно выполнить снова.

**## 4. Создание dev и прав на web**

Этот раздел выполняет \`root\`.

**### 4.1. Проверка пути**

\`\`\`bash

test -d "$project\_root"

test -d "$web\_root"

realpath "$project\_root"

realpath "$web\_root"

\`\`\`

Ожидается, что \`web\_root\` равен ровно \`project\_root/web\`. Если путь отличается, команды ниже сначала адаптирует программист.

**### 4.2. Пакеты**

\`\`\`bash

apt-get update

apt-get install -y git acl sqlite3

\`\`\`

**### 4.3. Пользователь dev**

\`dev\` создаётся как обычный пользователь без \`sudo\`. Отдельная общая группа ради одного \`dev\` не создаётся.

\`\`\`bash

id dev >/dev/null 2>&1 || adduser --disabled-password --gecos "" dev

gpasswd -d dev sudo 2>/dev/null || true

\`\`\`

Публичный SSH-ключ владельца добавляется в:

\`\`\`text

/home/dev/.ssh/authorized\_keys

\`\`\`

Права:

\`\`\`bash

install -d -m 700 -o dev -g dev /home/dev/.ssh

touch /home/dev/.ssh/authorized\_keys

chown dev\:dev /home/dev/.ssh/authorized\_keys

chmod 600 /home/dev/.ssh/authorized\_keys

\`\`\`

До изменения production-прав пользователь практически проверяет вход под \`dev\`. Если вход не работает, дальнейшая настройка прав не выполняется.

**### 4.4. Полный доступ dev внутри web без смены ownership**

На существующем production-сервере нельзя ради \`dev\` рекурсивно менять владельцев, группы или обычные permissions всего \`web/\`. Сначала сохраняется состояние и проверяется фактическая структура.

Создать backup текущих ACL и manifest metadata:

\`\`\`bash

backup\_stamp="$(date '+%Y%m%d-%H%M%S')"

getfacl -R -p "$web\_root" > "/tmp/${client\_slug}-web-acl-before-dev-${backup\_stamp}.txt"

find "$web\_root" -xdev -printf '%m\\t%u\\t%g\\t%p\\n' > "/tmp/${client\_slug}-web-metadata-before-dev-${backup\_stamp}.tsv"

\`\`\`

Перед применением ACL Codex отдельно проверяет symlink внутри \`web/\` и не следует по ссылкам за пределы \`web\_root\` без явного решения.

Существующим каталогам дать \`dev\` доступ \`rwx\`, существующим обычным файлам — \`rw-\`. Затем на каждый существующий каталог поставить default ACL для будущих объектов:

\`\`\`bash

find "$web\_root" -xdev -type d -exec setfacl -m u\:dev\:rwx {} +

find "$web\_root" -xdev -type f -exec setfacl -m u\:dev\:rw- {} +

find "$web\_root" -xdev -type d -exec setfacl -d -m u\:dev\:rwx {} +

\`\`\`

Эта схема не меняет owner/group production-файлов и не требует отдельной общей группы. Default ACL нужен, чтобы новые файлы и каталоги, созданные внутри \`web/\` другим процессом, автоматически оставались доступны \`dev\`.

POSIX ACL использует mask как group-class bits, поэтому после добавления named ACL вывод \`ls -l\` или \`stat\` у некоторых файлов может визуально показать более широкие group-биты и знак \`+\`. Это не означает, что owning-group реально получила запись: фактические права проверяются через \`getfacl\`, где \`group::\` должен сохранять прежние права, а дополнительная запись принадлежит только \`user:dev\`.

**### 4.5. www-data и запрет записи dev выше web**

Сначала Codex read-only определяет реальные writable-каталоги приложения: runtime, logs, uploads, cache, generated assets, рабочие SQLite-каталоги и другие пути, куда действительно пишет Apache/PHP. Существующие рабочие owner/group/mode не меняются, если приложение уже имеет нужный доступ.

Проверка конкретного каталога:

\`\`\`bash

runuser -u www-data -- test -w "/точный/writable/каталог"

\`\`\`

Если \`www-data\` действительно должен писать в конкретный каталог, но фактически не может, доступ исправляется только на этом подтверждённом каталоге. Предпочтительно добавить точечный ACL вместо смены ownership всего дерева:

\`\`\`bash

writable\_dir="/точный/writable/каталог"

find "$writable\_dir" -xdev -type d -exec setfacl -m u\:www-data\:rwx {} +

find "$writable\_dir" -xdev -type f -exec setfacl -m u\:www-data\:rw- {} +

find "$writable\_dir" -xdev -type d -exec setfacl -d -m u\:www-data\:rwx {} +

\`\`\`

Нельзя выдавать \`www-data\` запись во весь \`web/\` только ради удобства.

Для запрета записи \`dev\` выше \`web/\` также нельзя массово выполнять \`chmod\` по всему проекту. Сначала проверяется фактический доступ \`dev\` вне \`web\`:

\`\`\`bash

runuser -u dev -- find "$project\_root" -xdev \\
    -path "$web\_root" -prune -o \\
    -writable -print

\`\`\`

Нормальный результат не должен содержать production-пути выше \`web/\`. Если writable-пути найдены, Codex по каждому из них определяет причину — owner, group, ACL или mode — и убирает только конкретный лишний доступ \`dev\`. Массовый \`chmod go-w\`, рекурсивный \`chown\` или \`chgrp\` всего проекта запрещены.

Практически должно выполняться одновременно:

\- \`dev\` создаёт, изменяет и удаляет объекты внутри \`web/\`;

\- \`dev\` не может создать объект в \`project\_root\` или других production-каталогах выше \`web/\`;

\- \`www-data\` пишет только в подтверждённые writable-каталоги приложения;

\- owner/group существующих production-файлов остаются прежними, если отдельная функциональная причина не требует точечного изменения.

**## 5. Локальный Git всего проекта**

Этот контур принадлежит \`root\`, не имеет remote и служит быстрым checkpoint на том же сервере.

**### 5.1. Инициализация**

\`\`\`bash

git -C "$project\_root" init -b main

git -C "$project\_root" config user.name "Server Checkpoint"

git -C "$project\_root" config user.email "server\@client.example.ru"

\`\`\`

Если репозиторий уже существует, повторно инициализировать его не нужно.

В корневой \`.gitignore\` обычно исключаются только генерируемые и тяжёлые данные:

\`\`\`gitignore

/vendor/

/runtime/\*

!/runtime/.gitignore

/logs/\*

/web/assets/\*

\*.log

\*.tmp

\*.swp

.DS\_Store

Thumbs.db

\`\`\`

\`.gitignore\` внутри \`web/\` также применяется к родительскому репозиторию.

Первый checkpoint:

\`\`\`bash

git -C "$project\_root" add -A

git -C "$project\_root" commit -m "Initial server checkpoint"

\`\`\`

После этого Git metadata закрывается от \`dev\`:

\`\`\`bash

chown -R root\:root "$project\_root/.git"

chmod -R go-rwx "$project\_root/.git"

chmod 700 "$project\_root/.git"

\`\`\`

**### 5.2. Почасовой root-скрипт**

Создать \`/usr/local/sbin/\<client\_slug>-local-checkpoint.sh\`:

\`\`\`bash

#!/usr/bin/env bash

set -Eeuo pipefail

project\_root="/var/www/client.example.ru"

lock\_file="/run/lock/ivanov-local-checkpoint.lock"

timestamp="$(date -u '+%Y-%m-%d %H:%M UTC')"

exec 9>"$lock\_file"

if ! flock -n 9; then

    echo "[$timestamp] Previous local checkpoint is still running; skipping."

    exit 0

fi

git -C "$project\_root" add -A

if ! git -C "$project\_root" diff --cached --quiet; then

    git -C "$project\_root" commit -m "Automated server checkpoint: $timestamp"

fi

\`\`\`

Затем:

\`\`\`bash

chown root\:root /usr/local/sbin/ivanov-local-checkpoint.sh

chmod 750 /usr/local/sbin/ivanov-local-checkpoint.sh

/usr/local/sbin/ivanov-local-checkpoint.sh

\`\`\`

Добавить через \`crontab -e\` пользователя root:

\`\`\`cron

12 \* \* \* \* /usr/local/sbin/ivanov-local-checkpoint.sh >>/var/log/ivanov-local-checkpoint.log 2>&1

\`\`\`

**## 6. Приватная GitHub-репа для web**

**### 6.1. Deploy key**

Для каждого клиента создаётся отдельный SSH-ключ. GitHub deploy key привязан к одной репе; для автоматического push при добавлении ключа нужно включить \`Allow write access\`. GitHub также указывает, что один deploy key нельзя переиспользовать между несколькими репозиториями: [Managing deploy keys]\(https\://docs.github.com/en/authentication/connecting-to-github-with-ssh/managing-deploy-keys).

Под \`root\`:

\`\`\`bash

install -d -m 700 -o dev -g dev /home/dev/.ssh

runuser -u dev -- ssh-keygen \\

    -t ed25519 \\

    -N "" \\

    -C "ivanov GitHub deploy key" \\

    -f /home/dev/.ssh/id\_ed25519\_ivanov\_github

cat /home/dev/.ssh/id\_ed25519\_ivanov\_github.pub

\`\`\`

Публичную часть добавить на GitHub:

\`\`\`text

Repository → Settings → Deploy keys → Add deploy key

\`\`\`

Обязательно отметить \`Allow write access\`.

В \`/home/dev/.ssh/config\` добавить:

\`\`\`sshconfig

Host github-ivanov

    HostName github.com

    User git

    IdentityFile /home/dev/.ssh/id\_ed25519\_ivanov\_github

    IdentitiesOnly yes

\`\`\`

Права:

\`\`\`bash

chown dev\:dev /home/dev/.ssh/config

chmod 600 /home/dev/.ssh/config

\`\`\`

Проверка:

\`\`\`bash

runuser -u dev -- ssh -T github-ivanov

\`\`\`

GitHub обычно отвечает сообщением об успешной аутентификации и одновременно возвращает ненулевой exit code, потому что shell-доступ не предоставляется. Это нормально.

**### 6.2. Отдельная Git metadata**

Создать каталоги:

\`\`\`bash

install -d -m 700 -o dev -g dev /home/dev/.gitdirs

install -d -m 755 -o dev -g dev /home/dev/.local/bin

\`\`\`

Инициализировать GitHub-контур:

\`\`\`bash

runuser -u dev -- git \\

    --git-dir="/home/dev/.gitdirs/ivanov-web" \\

    --work-tree="$web\_root" \\

    init -b main

\`\`\`

Создать wrapper \`/home/dev/.local/bin/ivanov-git\`:

\`\`\`bash

#!/usr/bin/env bash

exec git \\

    --git-dir="/home/dev/.gitdirs/ivanov-web" \\

    --work-tree="/var/www/client.example.ru/web" \\

    "$@"

\`\`\`

Права и настройки:

\`\`\`bash

chown dev\:dev /home/dev/.local/bin/ivanov-git

chmod 755 /home/dev/.local/bin/ivanov-git

runuser -u dev -- /home/dev/.local/bin/ivanov-git \\

    config user.name "Evgeny"

runuser -u dev -- /home/dev/.local/bin/ivanov-git \\

    config user.email "server\@client.example.ru"

runuser -u dev -- /home/dev/.local/bin/ivanov-git \\

    remote add origin git\@github-ivanov\:YOUR\_GITHUB\_LOGIN/ivanov-web.git

\`\`\`

Для этой репы всегда используется \`ivanov-git\`, а не обычная команда \`git\`:

\`\`\`bash

/home/dev/.local/bin/ivanov-git status

/home/dev/.local/bin/ivanov-git diff

/home/dev/.local/bin/ivanov-git log --oneline

\`\`\`

**## 7. Что отправляется на GitHub**

Базовое правило для этой модели:

**### Отправляем**

\- код внутри \`web/\`;

\- CSS, JavaScript, картинки интерфейса;

\- небольшие пользовательские uploads;

\- конфиги проекта;

\- обычные API-ключи и webhook URL, если владелец осознанно разрешил их хранить в приватной репе;

\- безопасный snapshot небольшой SQLite-базы.

**### Не отправляем**

\- логи;

\- cache и tmp;

\- живой SQLite-файл, в который прямо сейчас пишет приложение;

\- SQLite \`-wal\` и \`-shm\`;

\- root SSH keys;

\- GitHub SSH/deploy keys;

\- платёжные ключи;

\- cloud/admin-токены;

\- один общий ключ, открывающий доступ сразу ко всем клиентам.

Пример \`web/.gitignore\`:

\`\`\`gitignore

\*.log

\*.tmp

\*.swp

\*\~

.DS\_Store

Thumbs.db

/cache/

/tmp/

/runtime/

# Указываются реальные пути живых баз проекта.

/data/app.sqlite

/data/app.sqlite-wal

/data/app.sqlite-shm

\`\`\`

Не нужно глобально игнорировать \`\*.sqlite\`, иначе Git проигнорирует и подготовленный snapshot.

**## 8. Защита закрытых файлов от HTTP**

Для единообразия закрытые конфиги располагаются в:

\`\`\`text

web/private/

\`\`\`

SQLite snapshots:

\`\`\`text

web/.git-snapshots/

\`\`\`

Если живая база физически находится внутри document root, её каталог также закрывается. Например:

\`\`\`text

web/data/

\`\`\`

Во всех перечисленных закрытых каталогах должен находиться \`.htaccess\`:

\`\`\`apache

Options -Indexes

Require all denied

\`\`\`

Apache 2.4 использует \`Require all denied\` для полного запрета доступа. Правила можно разместить в \`.htaccess\` либо, что надёжнее при доступе программиста к Apache, в \`\<Directory>\` конфигурации VirtualHost: [Apache access control]\(https\://httpd.apache.org/docs/2.4/howto/access.html).

Пример VirtualHost:

\`\`\`apache

\<Directory "/var/www/client.example.ru/web/private">

    Require all denied

\</Directory>

\<Directory "/var/www/client.example.ru/web/.git-snapshots">

    Require all denied

\</Directory>

\<Directory "/var/www/client.example.ru/web/data">

    Require all denied

\</Directory>

\`\`\`

После изменения VirtualHost:

\`\`\`bash

apachectl configtest

systemctl reload apache2

\`\`\`

Проверка извне:

\`\`\`bash

curl -I https\://client.example.ru/private/secrets.php

curl -I https\://client.example.ru/.git-snapshots/sqlite/app.sqlite

curl -I https\://client.example.ru/data/app.sqlite

\`\`\`

Ожидается \`403 Forbidden\` или \`404 Not Found\`, но не \`200 OK\`.

**## 9. Безопасный snapshot SQLite**

Живой файл SQLite нельзя считать надёжным backup простым чтением во время записи. Перед Git-коммитом создаётся отдельная согласованная копия командой \`.backup\`. Она является штатной командой официального SQLite CLI: [SQLite CLI]\(https\://sqlite.org/cli.html).

Создать:

\`\`\`text

web/.git-snapshots/sqlite/

web/ops/github-sync.sh

\`\`\`

Пример \`web/ops/github-sync.sh\`:

\`\`\`bash

#!/usr/bin/env bash

set -Eeuo pipefail

web\_root="/var/www/client.example.ru/web"

web\_git="/home/dev/.local/bin/ivanov-git"

snapshot\_dir="$web\_root/.git-snapshots/sqlite"

lock\_file="/home/dev/.cache/ivanov-github-sync.lock"

timestamp="$(date -u '+%Y-%m-%d %H:%M UTC')"

# Формат: абсолютный путь живой базы|имя snapshot-файла.

# Если SQLite нет, оставить пустой массив: sqlite\_databases=()

sqlite\_databases=(

    "$web\_root/data/app.sqlite|app.sqlite"

)

mkdir -p /home/dev/.cache "$snapshot\_dir"

exec 9>"$lock\_file"

if ! flock -n 9; then

    echo "[$timestamp] Previous GitHub sync is still running; skipping."

    exit 0

fi

for database\_entry in "${sqlite\_databases[@]}"; do

    IFS='|' read -r source\_database snapshot\_name <<<"$database\_entry"

    if [ ! -f "$source\_database" ]; then

        echo "[$timestamp] SQLite database not found: $source\_database" >&2

        exit 1

    fi

    snapshot\_path="$snapshot\_dir/$snapshot\_name"

    temporary\_snapshot="$snapshot\_path.tmp"

    rm -f "$temporary\_snapshot"

    sqlite3 "$source\_database" ".timeout 5000" ".backup '$temporary\_snapshot'"

    integrity\_result="$(sqlite3 "$temporary\_snapshot" 'PRAGMA integrity\_check;')"

    if [ "$integrity\_result" != "ok" ]; then

        rm -f "$temporary\_snapshot"

        echo "[$timestamp] SQLite integrity check failed: $source\_database" >&2

        exit 1

    fi

    mv -f "$temporary\_snapshot" "$snapshot\_path"

done

"$web\_git" add -A

if ! "$web\_git" diff --cached --quiet; then

    "$web\_git" commit -m "Automated web checkpoint: $timestamp"

else

    echo "[$timestamp] No web changes."

fi

"$web\_git" push origin main

\`\`\`

Права:

\`\`\`bash

chown dev\:dev "$web\_root/ops/github-sync.sh"

chmod 750 "$web\_root/ops/github-sync.sh"

\`\`\`

Путь каждой живой базы обязательно добавить в \`.gitignore\`. В Git должна попадать только копия из \`.git-snapshots/sqlite/\`.

**## 10. Первый GitHub push и dev-cron**

Первый запуск выполняется вручную от \`dev\`:

\`\`\`bash

runuser -u dev -- /var/www/client.example.ru/web/ops/github-sync.sh

\`\`\`

Проверить:

\`\`\`bash

runuser -u dev -- /home/dev/.local/bin/ivanov-git status

runuser -u dev -- /home/dev/.local/bin/ivanov-git log -3 --oneline

\`\`\`

В GitHub должна появиться только структура \`web/\`, без верхнего Yii-проекта и без \`.git\`.

Cron редактируется от \`dev\`:

\`\`\`bash

runuser -u dev -- crontab -e

\`\`\`

Строка:

\`\`\`cron

17 \* \* \* \* /var/www/client.example.ru/web/ops/github-sync.sh >>/var/www/client.example.ru/web/private/github-sync.log 2>&1

\`\`\`

Лог имеет расширение \`.log\` и исключён из Git.

**## 11. Финальная проверка**

**### 11.1. Права**

Под root:

\`\`\`bash

if runuser -u dev -- test -w "$project\_root"; then

    echo "ERROR: dev can write project root"

else

    echo "OK: dev cannot write project root"

fi

if runuser -u dev -- test -w "$web\_root"; then

    echo "OK: dev can write web"

else

    echo "ERROR: dev cannot write web"

fi

\`\`\`

Практический тест:

\`\`\`bash

if runuser -u dev -- touch "$project\_root/.dev-write-test"; then

    rm -f "$project\_root/.dev-write-test"

    echo "ERROR: dev created a file above web"

else

    echo "OK: write above web was rejected"

fi

runuser -u dev -- touch "$web\_root/.dev-write-test"

rm -f "$web\_root/.dev-write-test"

echo "OK: write inside web works"

\`\`\`

Дополнительно Codex проверяет ACL и наследование на практике: создаёт тестовые файл и каталог от имени \`www-data\` внутри одного подтверждённого writable-каталога, убеждается, что \`dev\` может их изменить и удалить, затем полностью удаляет тестовые объекты. Обычные файлы после настройки не должны неожиданно получить executable-бит.

Также проверяется, что \`www-data\` может писать только в список подтверждённых writable-каталогов, а в остальных каталогах \`web/\` запись запрещена.

**### 11.2. Git**

\`\`\`bash

# root

git -C "$project\_root" status --short

/usr/local/sbin/ivanov-local-checkpoint.sh

# GitHub-контур от dev

runuser -u dev -- /home/dev/.local/bin/ivanov-git status

runuser -u dev -- /var/www/client.example.ru/web/ops/github-sync.sh

\`\`\`

Обе команды после повторного запуска должны сообщить, что изменений нет, и не создавать пустые коммиты.

**### 11.3. Cron**

\`\`\`bash

systemctl is-active cron

crontab -l

crontab -u dev -l

\`\`\`

Root должен видеть собственный local-checkpoint. Через \`crontab -u dev -l\` он видит GitHub checkpoint и остальные проектные задания \`dev\`.

**### 11.4. SQLite и HTTP**

\`\`\`bash

sqlite3 "$web\_root/.git-snapshots/sqlite/app.sqlite" 'PRAGMA integrity\_check;'

\`\`\`

Ожидается \`ok\`.

Закрытые HTTP-пути должны возвращать \`403\` или \`404\`. Публичная главная страница должна возвращать \`200\`.

**## 12. Повседневная работа**

1\. Подключиться к серверу через VS Code как \`dev\`.

2\. Открыть только \`/var/www/<домен>/web\`.

3\. Работать и проверять сайт непосредственно на сервере.

4\. Ничего вручную коммитить для checkpoint не обязательно.

5\. Root-cron раз в час сохраняет весь проект локально.

6\. Dev-cron раз в час создаёт SQLite snapshot и пушит \`web/\` в приватный GitHub.

Нужно помнить: автоматический checkpoint может сохранить незавершённую или временно сломанную работу. Для этой модели это нормально — Git используется как журнал состояния, а не как процесс code review.

Раз в месяц достаточно смотреть размер Git metadata:

\`\`\`bash

du -sh /home/dev/.gitdirs/ivanov-web

du -sh /var/www/client.example.ru/.git

\`\`\`

Если небольшая SQLite-база или uploads начинают заметно раздувать историю, их стратегию пересматривают отдельно. Для маленького клиентского сайта преждевременно усложнять схему не нужно.

**## 13. Если что-то не работает**

**### GitHub push**

\`\`\`bash

runuser -u dev -- ssh -T github-ivanov

runuser -u dev -- /home/dev/.local/bin/ivanov-git status

tail -n 100 /var/www/client.example.ru/web/private/github-sync.log

\`\`\`

Проверить:

\- deploy key добавлен именно в нужную репу;

\- включён \`Allow write access\`;

\- remote использует SSH alias \`github-ivanov\`;

\- приватный ключ принадлежит \`dev\` и имеет права \`600\`;

\- GitHub-репа не содержит отдельной несовместимой истории.

**### Локальный checkpoint**

\`\`\`bash

/usr/local/sbin/ivanov-local-checkpoint.sh

git -C /var/www/client.example.ru status --short

tail -n 100 /var/log/ivanov-local-checkpoint.log

\`\`\`

Этот скрипт должен запускаться root. \`dev\` не должен иметь доступ к родительскому \`.git\`.

**### Права сайта**

\`\`\`bash

namei -l /var/www/client.example.ru/web

getfacl /var/www/client.example.ru/web

find /var/www/client.example.ru/web -xdev -type f -perm /111 -print

runuser -u www-data -- test -r /var/www/client.example.ru/web/index.php

\`\`\`

После изменения Apache:

\`\`\`bash

apachectl configtest

systemctl reload apache2

\`\`\`

**## 14. Восстановление после ошибки**

**### Случайно испорчен файл внутри web**

Найти нужную версию через GitHub-историю и восстановить конкретный файл. Не выполнять массовый reset всего production-каталога без проверки списка изменений.

**### Сломан весь web**

1\. Сохранить текущую сломанную папку отдельно.

2\. Получить последнюю версию приватной GitHub-репы.

3\. Восстановить production \`web/\`.

4\. Если нужна база, восстановить её из \`.git-snapshots/sqlite/\` при остановленной записи приложения.

5\. Восстановить исходные owner/group/mode production-файлов и повторно применить персональный ACL для \`dev\`; права \`www-data\` вернуть только подтверждённым writable-каталогам.

6\. Проверить Apache, PHP и cron.

**### Удалён весь сервер**

GitHub вернёт \`web/\`, включая разрешённые конфиги, секреты, uploads и последний SQLite snapshot. Верхний Yii-код, который пользователь или программист уже писал вне \`web/\` и который существовал только в локальном Git сервера, при полном удалении сервера не восстановится. Если этот код тоже требуется защищать от потери всего сервера, для него следует отдельно настроить удалённую репу — это выходит за рамки данного гайда.

**## 15. Контрольный чек-лист готовности клиентского сервера**

\- [ ] Создан \`dev\` без sudo.

\- [ ] Для \`dev\` не создана лишняя общая группа; доступ внутри \`web/\` выдан персональным ACL.

\- [ ] \`dev\` пишет внутри \`web/\` и не пишет выше.

\- [ ] Существующие owner/group production-файлов не были массово переопределены ради \`dev\`.

\- [ ] Новые файлы и каталоги внутри \`web/\` наследуют доступ \`dev\` через default ACL.

\- [ ] Обычные файлы внутри \`web/\` не получили лишний executable-бит.

\- [ ] \`www-data\` пишет только в подтверждённые writable-каталоги приложения.

\- [ ] Локальный \`.git\` всего проекта принадлежит root и не имеет remote.

\- [ ] Root checkpoint-скрипт работает вручную.

\- [ ] Root-cron содержит почасовой checkpoint.

\- [ ] Создана отдельная приватная GitHub-репа клиента.

\- [ ] Создан уникальный deploy key с write access только к этой репе.

\- [ ] GitHub metadata находится вне \`web/\`.

\- [ ] Wrapper \`\<client\_slug>-git\` работает.

\- [ ] Логи, cache, tmp и живые SQLite-файлы исключены из Git.

\- [ ] SQLite snapshot проходит \`PRAGMA integrity\_check\`.

\- [ ] Закрытые конфиги и snapshots недоступны по HTTP.

\- [ ] Dev-cron содержит почасовой GitHub checkpoint.

\- [ ] Повторный запуск обоих скриптов не создаёт пустых коммитов.

**## 16. Принятый уровень безопасности**

Эта схема сознательно допускает хранение обычных клиентских API-ключей и webhook URL в приватной клиентской репе ради простого восстановления. Риск принимается при условиях:

\- репа всегда приватная;

\- доступ есть только у владельца;

\- на каждом сервере отдельный deploy key;

\- ключ имеет доступ только к одной репе;

\- GitHub Apps и лишние collaborators не подключаются;

\- старый секрет при замене отзывается.

Удаление секрета новым коммитом не удаляет его из старой Git-истории. При реальной утечке секрет сначала отзывается или перевыпускается; очистка истории является отдельной процедурой: [рекомендации GitHub]\(https\://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).

Критические root/GitHub/payment/cloud credentials в репозиторий не помещаются даже при этой упрощённой модели.