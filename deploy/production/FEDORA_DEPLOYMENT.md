# Развёртывание OpenProject FI Ausbildung на Fedora

Эта инструкция устанавливает кастомный OpenProject с нативной функцией Daily
Report на сервер Fedora `172.17.43.45` и восстанавливает базу из backup.

Используемый образ:

```text
ghcr.io/mosoonk/openproject-fi-ausbildung:sha-3b87cc8
```

Backup `backup_file_name.zip` содержит только
`openproject.sql`. Вложения и другие файлы OpenProject в этом архиве
отсутствуют и должны восстанавливаться из отдельной резервной копии.

> [!WARNING]
> В текущей конфигурации используется HTTP. Пароли, cookies, API-токены и
> содержимое Daily Report не защищены шифрованием. Доступ необходимо ограничить
> внутренней сетью и затем настроить TLS.

## 1. Перенос файлов с Windows

Откройте PowerShell:

```powershell
ssh ausbildung-pc@172.17.43.45 "mkdir -p ~/openproject-FI"

scp C:\Users\maksym.shkurenko\Documents\openproject-daily-report\deploy\production\compose.yml `
    ausbildung-pc@172.17.43.45:~/openproject-FI/

scp C:\path\to\backup_file_name.zip `
    ausbildung-pc@172.17.43.45:~/openproject-FI/
```

SSH запросит пароль пользователя сервера, если авторизация по ключу ещё не
настроена.

## 2. Подключение к серверу

```powershell
ssh ausbildung-pc@172.17.43.45
```

Все следующие команды, кроме явно отмеченных, выполняются на сервере Fedora.

## 3. Установка Docker Engine

```bash
sudo dnf install -y curl unzip openssl

sudo curl -fsSL \
  https://download.docker.com/linux/fedora/docker-ce.repo \
  -o /etc/yum.repos.d/docker-ce.repo

sudo dnf install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin
```

## 4. Проверка конфликта сетей

Сервер использует адрес `172.17.43.45`, а стандартная сеть Docker часто
занимает `172.17.0.0/16`. Сначала проверьте существующие маршруты:

```bash
ip -4 route
```

Если диапазоны `10.250.0.0/24` и `10.251.0.0/16` не используются в вашей
сети, задайте их для Docker:

```bash
sudo install -d -m 0755 /etc/docker

sudo tee /etc/docker/daemon.json >/dev/null <<'EOF'
{
  "bip": "10.250.0.1/24",
  "default-address-pools": [
    {
      "base": "10.251.0.0/16",
      "size": 24
    }
  ]
}
EOF
```

Запустите Docker:

```bash
sudo systemctl enable --now docker
sudo docker info
sudo docker compose version
```

## 5. Подготовка каталога приложения

```bash
sudo install -d -m 0750 \
  -o ausbildung-pc \
  -g ausbildung-pc \
  /opt/openproject-FI

cp ~/openproject-FI/compose.yml /opt/openproject-FI/
cp ~/openproject-FI/backup_file_name.zip /opt/openproject-FI/

cd /opt/openproject-FI
```

Проверьте backup:

```bash
unzip -l backup_file_name.zip
```

В архиве должен присутствовать `openproject.sql`.

## 6. Создание конфигурации и секретов

Команды создают `.env`, не выводя секреты на экран:

```bash
umask 077

POSTGRES_PASSWORD="$(openssl rand -hex 32)"
SECRET_KEY_BASE="$(openssl rand -hex 64)"

cat > .env <<EOF
OPENPROJECT_IMAGE=ghcr.io/mosoonk/openproject-fi-ausbildung:sha-3b87cc8
OPENPROJECT_HOST__NAME=172.17.43.45:8080
BIND_IP=172.17.43.45
HTTP_PORT=8080
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
DATABASE_URL=postgresql://openproject:${POSTGRES_PASSWORD}@db:5432/openproject?pool=20
SECRET_KEY_BASE=${SECRET_KEY_BASE}
EOF

chmod 600 .env
```

Сохраните защищённую копию `.env`. Значение `SECRET_KEY_BASE` должно
сохраняться при обновлениях и восстановлениях.

Проверьте Compose:

```bash
sudo docker compose --env-file .env config --quiet
```

## 7. Загрузка Docker-образов

```bash
sudo docker compose --env-file .env pull
```

Проверьте digest загруженного кастомного образа и сохраните его в документации
сервера:

```bash
sudo docker image inspect \
  ghcr.io/mosoonk/openproject-fi-ausbildung:sha-3b87cc8 \
  --format '{{index .RepoDigests 0}}'
```

## 8. Запуск PostgreSQL и Memcached

```bash
sudo docker compose --env-file .env up -d db cache
sudo docker compose --env-file .env ps
```

Дождитесь готовности PostgreSQL:

```bash
until sudo docker compose --env-file .env exec -T db \
  pg_isready -U openproject -d openproject
do
  sleep 2
done
```

## 9. Восстановление базы

Убедитесь, что `web`, `worker` и `cron` ещё не запущены:

```bash
sudo docker compose --env-file .env ps
```

Восстановите SQL:

```bash
unzip -p backup_file_name.zip openproject.sql |
  sudo docker compose --env-file .env exec -T db \
    psql -v ON_ERROR_STOP=1 -U openproject -d openproject
```

Команда должна завершиться без сообщений `ERROR`.

Проверьте наличие таблиц:

```bash
sudo docker compose --env-file .env exec -T db \
  psql -U openproject -d openproject -c '\dt'
```

## 10. Миграции Daily Report

```bash
sudo docker compose --env-file .env up seeder
```

Seeder должен завершиться с кодом `0`. Проверьте таблицы Daily Report:

```bash
sudo docker compose --env-file .env exec -T db \
  psql -U openproject -d openproject \
  -c '\dt daily_report_*'
```

Ожидаются таблицы:

```text
daily_report_audit_events
daily_report_notification_deliveries
daily_report_work_package_entries
daily_report_work_package_entry_revisions
```

## 11. Запуск OpenProject

```bash
sudo docker compose --env-file .env up -d web worker cron
sudo docker compose --env-file .env ps
```

Проверьте логи:

```bash
sudo docker compose --env-file .env logs --tail=150 seeder web worker
```

Проверьте health endpoint непосредственно на сервере:

```bash
curl --fail http://172.17.43.45:8080/health_checks/default
```

## 12. Настройка firewall

Если разрешённая внутренняя сеть — `172.17.0.0/16`:

```bash
sudo firewall-cmd --permanent \
  --add-rich-rule='rule family="ipv4" source address="172.17.0.0/16" port port="8080" protocol="tcp" accept'

sudo firewall-cmd --reload
sudo firewall-cmd --list-all
```

OpenProject должен быть доступен по адресу:

```text
http://172.17.43.45:8080
```

## 13. Проверка после восстановления

Проверьте:

1. Вход существующим пользователем из backup.
2. Проекты, участников и Work Packages.
3. Вкладку Daily Report.
4. Создание нового Daily Report.
5. Bearbeiten и историю исправлений.
6. Уведомления Daily Report.
7. Чтение Daily Report через API-токен.
8. Работу фоновых заданий `worker`.
9. Отсутствие циклических перезапусков контейнеров.

Для наблюдения за контейнерами:

```bash
sudo docker compose --env-file .env ps
sudo docker compose --env-file .env logs --tail=200 web worker
```

## 14. Остановка

Остановить приложение без удаления базы и файлов:

```bash
sudo docker compose --env-file .env stop web worker cron
```

Повторный запуск:

```bash
sudo docker compose --env-file .env start web worker cron
```

> [!DANGER]
> Не выполняйте `docker compose down --volumes`: эта команда удалит persistent
> volumes с базой и файлами.
