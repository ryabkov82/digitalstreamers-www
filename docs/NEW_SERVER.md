# Добавление нового сервера

Полная шпаргалка по подключению узла к проекту **Digital Streamers**: SSH-ключи, инвентарь Ansible, проверка и деплой.

---

## 0) Предусловия

- На локальной машине (WSL Ubuntu) есть пара ключей деплоя (рекомендуется ed25519):
```bash
ls ~/.ssh/ds_ansible ~/.ssh/ds_ansible.pub 2>/dev/null || \
ssh-keygen -t ed25519 -f ~/.ssh/ds_ansible -C "ds-ansible" -N ''
```
- В `~/.ssh/config` есть **алиас** для нового узла (так удобнее, чем помнить IP/порт):
```sshconfig
Host nl-ams-3
  HostName 203.0.113.10        # IP или DNS узла
  User root                     # или другой пользователь с sudo
  Port 22
  IdentityFile ~/.ssh/ds_ansible
  IdentitiesOnly yes
  # Если нужен бастион/ProxyJump — раскомментируйте:
  # ProxyJump bastion.example.com
```
> Далее везде используем алиас `nl-ams-3` (SSH/Ansible/Makefile).

---

## 1) Установить публичный ключ на сервер

### Вариант A — через пароль (проще)
```bash
ssh-copy-id -i ~/.ssh/ds_ansible.pub root@203.0.113.10
```

### Вариант B — ручная установка в authorized_keys
(подходит, если входите через консоль провайдера или `ssh-copy-id` недоступен)
```bash
cat ~/.ssh/ds_ansible.pub | ssh root@203.0.113.10 \
  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys; chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys'
```

Принять host key и проверить вход:
```bash
ssh -o StrictHostKeyChecking=accept-new nl-ams-3 'hostname && id'
```

---

## 2) Добавить хост в Ansible inventory

Откройте `deploy/ansible/inventory.ini` и добавьте строку в секцию `[mask_nodes]`:
```ini
[mask_nodes]
nl-ams-3 ds_node_id=nl-ams-3 ds_city="Амстердам" ds_region="EU-West" ds_tz="Europe/Amsterdam"
# ...остальные узлы...
```

В секции `[mask_nodes:vars]` общие параметры уже заданы (site_root, пути, TLS и т.д.).
Если используете DNS-имя/нестандартный порт и **нет** записи в `~/.ssh/config`, то можно явно указать:
```ini
nl-ams-3 ansible_host=203.0.113.10 ansible_port=22 ds_node_id=nl-ams-3 ds_city="Амстердам" ds_region="EU-West" ds_tz="Europe/Amsterdam"
```

---

## 3) Обновить known_hosts (чтобы Ansible не задавал вопросов)

```bash
make ssh-known-hosts LIMIT=nl-ams-3
```
Цель использует `ssh -o StrictHostKeyChecking=accept-new` и алиасы из `~/.ssh/config`,
поэтому корректно работает с ProxyJump/Port/IdentityFile.

> Если ключ хоста поменялся, сначала удалите старую запись:
> ```bash
> ssh-keygen -R nl-ams-3
> # при необходимости также: ssh-keygen -R 203.0.113.10
> ```

---

## 4) (Опционально) Бутстрап «голого» сервера

Если на сервере нет Python/rsync, выполните (единоразово):
```bash
ansible nl-ams-3 -i deploy/ansible/inventory.ini -b -m raw -a 'apt-get update && apt-get install -y python3 rsync'
```

---

## 5) Деплой и проверка

Dry-run (ничего не меняет, показывает дифф):
```bash
make deploy-check LIMIT=nl-ams-3
```

Реальный деплой:
```bash
make deploy LIMIT=nl-ams-3
```

Проверка конфигурации nginx на удалённом хосте:
```bash
make test-nginx LIMIT=nl-ams-3
```

Проверка локального backend (SNI на 127.0.0.1:8443) и статуса узла:
```bash
make status LIMIT=nl-ams-3
```

Ожидаемый JSON:
```json
{
  "name": "nl-ams-3",
  "city": "Амстердам",
  "region": "EU-West",
  "hostname": "host123",
  "time": "2025-09-10T12:58:00+00:00",
  "tz": "Europe/Amsterdam",
  "addr": "127.0.0.1"
}
```

---

## 6) Удобные вспомогательные цели Makefile

Установить публичный ключ на сервер (если нет `ssh-copy-id`):
```bash
make push-key HOST=nl-ams-3
```

Принять host keys всех узлов группы:
```bash
make ssh-known-hosts
# или точечно
make ssh-known-hosts LIMIT=nl-ams-3
```

Сделать выпуск (git tag + запуск GitHub Actions deploy при наличии `gh`):
```bash
make release TAG=v2025.09.10-1 LIMIT=nl-ams-3
```

---

## 7) Частые проблемы

- **SSH спрашивает пароль/не видит ключ** — проверьте `~/.ssh/config` (правильный `IdentityFile` и `IdentitiesOnly yes`), права `600` у приватного ключа.
- **Ansible ругается на host key** — обновите `known_hosts`: `make ssh-known-hosts LIMIT=nl-ams-3`.
- **404 на / или /index.html** — проверьте `server_name`, `root`, `try_files` и SNI при тестах (`curl --resolve`).
- **reload не подхватил изменения** — если меняли HTTP-зоны (`limit_req_zone` и т.п.) или видите странности — выполните `systemctl restart nginx` (в плейбуке для http-конфига уже стоит `Restart Nginx`).

---

Готово! Теперь узел участвует в деплое и мониторится командами `make status`, `make test-nginx`.
