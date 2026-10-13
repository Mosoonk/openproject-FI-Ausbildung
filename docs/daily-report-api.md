# Daily Report API

## Назначение

Daily Report API позволяет внешнему приложению получить список Daily Report,
связанных с конкретным Work Package.

Текущая версия интеграции предназначена только для чтения:

```http
GET /work_packages/{work_package_id}/daily_report_entries.json
```

API использует пользователей, проекты, роли, разрешения и API-токены основного
OpenProject. Отдельной учётной записи, базы данных или OAuth-интеграции для
Daily Report нет.

> [!IMPORTANT]
> Это нативный endpoint данного OpenProject fork, но не ресурс стандартного
> OpenProject API v3. Путь не начинается с `/api/v3`, а формат ответа пока не
> имеет отдельной версии. Изменения контракта нужно выпускать контролируемо и
> синхронизировать с внешними потребителями.

## Базовый URL

Для текущего сервера:

```text
http://172.17.43.45:8080
```

Полный пример URL для Work Package `75`:

```text
http://172.17.43.45:8080/work_packages/75/daily_report_entries.json
```

> [!WARNING]
> При использовании HTTP API-токен и данные передаются по сети без шифрования.
> Ограничение доступа внутренней сетью снижает риск, но не заменяет HTTPS.
> Не используйте API через недоверенную сеть до настройки TLS.

## Аутентификация

Передавайте персональный API-токен OpenProject в заголовке:

```http
X-OpenProject-API-Key: <api-token>
```

Также рекомендуется явно запрашивать JSON:

```http
Accept: application/json
```

Не передавайте токен:

- в URL или query string;
- в исходном коде;
- в Git;
- в логах;
- в сообщениях об ошибках;
- в клиентском JavaScript, доступном пользователям браузера.

### Создание API-токена

1. Войдите под пользователем, от имени которого будет выполняться чтение.
2. Откройте **Account settings**.
3. Выберите **Access tokens**.
4. Нажмите **+ API token**.
5. Введите назначение, например `Dashboard Daily Report Read API`.
6. Нажмите **Create**.
7. Сразу сохраните токен в менеджере секретов. Повторно значение не
   показывается.

Если раздел отсутствует, администратор должен включить API-токены в
**Administration → API and webhooks**.

### Read-only и права токена

OpenProject API-токен не имеет отдельного read-only scope. Он наследует права
пользователя, которому принадлежит.

Сам Daily Report endpoint принимает API-key только для операции `GET index`.
Создание, исправление, удаление и восстановление Daily Report через API-key не
предоставляются.

> [!CAUTION]
> Тот же токен может использоваться с другими API OpenProject в рамках прав
> пользователя. Если пользователь имеет права записи в OpenProject, токен не
> становится глобально read-only только из-за использования с Daily Report.

Рекомендуется создавать отдельный токен для каждого внешнего приложения,
регулярно менять его и отзывать сразу после прекращения использования.

## Авторизация и область видимости

Сервер проверяет права при каждом запросе. Переданные клиентом идентификаторы
пользователя, автора, проекта или роли не используются для расширения доступа.

### Обычный участник

Пользователь без глобального разрешения `manage_daily_report_entries`:

- должен видеть запрошенный Work Package;
- получает только собственные Daily Report этого Work Package;
- не получает записи других участников;
- не получает удалённые записи.

### Ausbilder или Admin

Активный пользователь с глобальным разрешением
`manage_daily_report_entries`, а также администратор:

- должен видеть запрошенный Work Package;
- получает активные Daily Report всех авторов этого Work Package;
- не получает удалённые записи через данный endpoint.

### Пользователь Dashboard

Если Dashboard является обычным пользователем, API вернёт только его
собственные записи. Для получения всех записей требуется глобальное разрешение
`manage_daily_report_entries`, которое также даёт возможность исправления в
интерфейсе OpenProject.

Отдельного разрешения «читать все, но не исправлять» сейчас нет.

## Endpoint списка

### Запрос

```http
GET /work_packages/{work_package_id}/daily_report_entries.json HTTP/1.1
Host: 172.17.43.45:8080
Accept: application/json
X-OpenProject-API-Key: <api-token>
```

### Path-параметры

| Параметр | Тип | Обязательный | Описание |
| --- | --- | --- | --- |
| `work_package_id` | integer | да | ID существующего и видимого Work Package |

### Query-параметры

Endpoint пока не поддерживает фильтрацию, выбор диапазона дат, сортировку,
offset или pagination.

Ответ содержит все доступные активные записи одного Work Package и сортируется
сервером по `entry_date` от новых к старым.

Для нескольких Work Packages необходимо выполнить отдельный запрос для каждого
ID.

## Успешный ответ

### HTTP status

```text
200 OK
```

### Content-Type

```text
application/json
```

### Пример

```json
[
  {
    "id": 42,
    "entry_date": "2026-10-06",
    "entry_kind": "report",
    "status_type": "betrieb",
    "yesterday_text": "API-Integration vorbereitet",
    "today_text": "Fehlerbehandlung ergänzen",
    "issue_text": "Keine",
    "risks_text": "Zeitplan ist knapp",
    "lock_version": 1,
    "updated_at": "2026-10-06T14:31:12.000Z",
    "author": {
      "id": 49,
      "name": "Son Nguyen"
    },
    "work_package": {
      "id": 75,
      "subject": "Mini-ToDo-App"
    },
    "project": {
      "id": 12,
      "name": "Son Nguyen"
    },
    "correction_history": [
      {
        "revision_number": 2,
        "comment": "Tippfehler behoben",
        "actor": {
          "id": 6,
          "name": "Ausbilder"
        },
        "created_at": "2026-10-06T15:04:30.000Z",
        "changes": [
          {
            "field": "today_text",
            "before": "Fehlerbehandlung ergenzen",
            "after": "Fehlerbehandlung ergänzen"
          }
        ]
      }
    ],
    "can_correct": true,
    "can_delete": false
  }
]
```

Если доступных записей нет, сервер возвращает пустой массив:

```json
[]
```

## Поля ответа

| Поле | Тип | Может быть `null` | Описание |
| --- | --- | --- | --- |
| `id` | integer | нет | ID Daily Report |
| `entry_date` | string (`YYYY-MM-DD`) | нет | Дата отчёта |
| `entry_kind` | string | нет | `report` или `status` |
| `status_type` | string | да | Вид занятости/отсутствия |
| `yesterday_text` | string | да | Выполненная ранее работа |
| `today_text` | string | да | Запланированная работа |
| `issue_text` | string | да | Probleme |
| `risks_text` | string | да | Risiken |
| `lock_version` | integer | нет | Версия optimistic locking |
| `updated_at` | string (ISO 8601) | нет | Время последнего изменения |
| `author` | object | нет | Автор Daily Report |
| `work_package` | object | нет | Связанный Work Package |
| `project` | object | нет | Проект Work Package |
| `correction_history` | array | нет | История исправлений с комментарием |
| `can_correct` | boolean | нет | Может ли пользователь исправлять запись в UI |
| `can_delete` | boolean | нет | Может ли пользователь удалить запись в UI |

`can_correct` и `can_delete` являются информацией для интерфейса. Они не
предоставляют API-key операции записи.

### `entry_kind`

| Значение | Описание |
| --- | --- |
| `report` | Обычный текстовый Daily Report |
| `status` | Отдельная отметка занятости или отсутствия без текстовых полей |

### `status_type`

| Значение API | Отображение |
| --- | --- |
| `betrieb` | Betrieb |
| `berufsschule` | Berufsschule |
| `praktikum` | Praktikum |
| `krank` | Krank |

Для `entry_kind = "status"` текстовые поля должны быть пустыми и в ответе
обычно имеют значение `null`.

Для `entry_kind = "report"` поля `yesterday_text`, `today_text`, `issue_text`
и `risks_text` обязательны при создании через интерфейс. `status_type` может
быть `betrieb` или `null` для исторических записей.

## История исправлений

`correction_history` содержит только исправления, для которых сохранён
непустой комментарий.

Поля элемента истории:

| Поле | Тип | Описание |
| --- | --- | --- |
| `revision_number` | integer | Последовательный номер ревизии |
| `comment` | string | Причина исправления |
| `actor` | object | Пользователь, выполнивший исправление |
| `created_at` | string (ISO 8601) | Время исправления |
| `changes` | array | Список реально изменённых текстовых полей |

Элемент `changes` содержит:

| Поле | Тип | Описание |
| --- | --- | --- |
| `field` | string | Имя изменённого поля |
| `before` | string или `null` | Значение до исправления |
| `after` | string или `null` | Значение после исправления |

В истории сравниваются поля:

- `yesterday_text`;
- `today_text`;
- `issue_text`;
- `risks_text`.

## Примеры использования

### curl в Linux

```bash
export OPENPROJECT_BASE_URL='http://172.17.43.45:8080'
export OPENPROJECT_API_TOKEN='replace-with-token'
export WORK_PACKAGE_ID='75'

curl --fail-with-body --silent --show-error \
  --header 'Accept: application/json' \
  --header "X-OpenProject-API-Key: ${OPENPROJECT_API_TOKEN}" \
  "${OPENPROJECT_BASE_URL}/work_packages/${WORK_PACKAGE_ID}/daily_report_entries.json"
```

С `jq`:

```bash
curl --fail-with-body --silent --show-error \
  --header 'Accept: application/json' \
  --header "X-OpenProject-API-Key: ${OPENPROJECT_API_TOKEN}" \
  "${OPENPROJECT_BASE_URL}/work_packages/${WORK_PACKAGE_ID}/daily_report_entries.json" |
  jq .
```

### PowerShell

```powershell
$baseUrl = 'http://172.17.43.45:8080'
$workPackageId = 75
$token = $env:OPENPROJECT_API_TOKEN

$headers = @{
    Accept = 'application/json'
    'X-OpenProject-API-Key' = $token
}

$reports = Invoke-RestMethod `
    -Method Get `
    -Uri "$baseUrl/work_packages/$workPackageId/daily_report_entries.json" `
    -Headers $headers

$reports | ConvertTo-Json -Depth 10
```

### JavaScript/TypeScript на сервере

```typescript
const baseUrl = "http://172.17.43.45:8080";
const workPackageId = 75;
const token = process.env.OPENPROJECT_API_TOKEN;

if (!token) {
  throw new Error("OPENPROJECT_API_TOKEN is not configured");
}

const response = await fetch(
  `${baseUrl}/work_packages/${workPackageId}/daily_report_entries.json`,
  {
    headers: {
      Accept: "application/json",
      "X-OpenProject-API-Key": token,
    },
  },
);

if (!response.ok) {
  throw new Error(`Daily Report API failed: ${response.status} ${await response.text()}`);
}

const reports = await response.json();
console.log(reports);
```

Не размещайте этот код с токеном в браузерном frontend. Выполняйте запрос через
защищённый backend внешнего приложения.

### Python

```python
import os
import requests

base_url = "http://172.17.43.45:8080"
work_package_id = 75
token = os.environ["OPENPROJECT_API_TOKEN"]

response = requests.get(
    f"{base_url}/work_packages/{work_package_id}/daily_report_entries.json",
    headers={
        "Accept": "application/json",
        "X-OpenProject-API-Key": token,
    },
    timeout=30,
)
response.raise_for_status()

reports = response.json()
print(reports)
```

## Коды ответа и диагностика

| Код | Значение | Типичная причина |
| --- | --- | --- |
| `200` | OK | Запрос выполнен; результат может быть пустым массивом |
| `401` | Unauthorized | Токен отсутствует, недействителен или отозван |
| `404` | Not Found | Work Package не существует либо невидим пользователю |
| `500` | Internal Server Error | Ошибка сервера; требуется проверить Rails logs |

Для невидимого Work Package возвращается `404`, а не `403`. Это предотвращает
раскрытие факта существования недоступного объекта.

### Проверка токена

```bash
curl --include \
  --header 'Accept: application/json' \
  --header "X-OpenProject-API-Key: ${OPENPROJECT_API_TOKEN}" \
  "${OPENPROJECT_BASE_URL}/work_packages/75/daily_report_entries.json"
```

### Логи production-сервера

На Fedora:

```bash
cd /opt/openproject-FI

sudo docker compose --env-file .env logs \
  --since=10m \
  --tail=200 \
  web
```

Не публикуйте API-токен вместе с логами.

## Отзыв и замена токена

1. Войдите пользователем-владельцем токена.
2. Откройте **Account settings → Access tokens**.
3. Удалите или отзовите скомпрометированный токен.
4. Создайте новый токен.
5. Обновите секрет во внешнем приложении.
6. Проверьте новый токен и только затем перезапустите интеграцию.

Отзыв токена действует на последующие запросы. Хранить старое значение после
отзыва не нужно.

## Текущие ограничения

- Только чтение списка по одному Work Package.
- Нет endpoint для одной записи по ID.
- Нет общего списка Daily Report по проекту или пользователю.
- Нет фильтра по диапазону дат.
- Нет pagination.
- Нет API-экспорта PDF/CSV.
- Нет API-key операций create/update/delete/restore.
- Удалённые записи не возвращаются.
- Нет отдельного permission «читать все Daily Report без права исправления».
- Контракт пока не опубликован в OpenAPI и не имеет номера версии.

Расширение API необходимо начинать с фиксации требований в `spec.md`, затем
добавлять серверную авторизацию и IDOR-тесты до реализации внешнего интерфейса.
