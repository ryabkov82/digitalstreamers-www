# ---- Makefile for Digital Streamers ----
SHELL := /bin/bash
.DEFAULT_GOAL := help

# Detect Compose CLI (Docker Desktop/WSL supports the plugin form)
COMPOSE := $(shell docker compose version >/dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Ansible
INV ?= deploy/ansible/inventory.ini
ANSIBLE_PLAYBOOK := ansible-playbook -i $(INV)
ANSIBLE_LINT := ansible-lint
YAMLLINT := yamllint

# Limit to host/group if provided: make deploy LIMIT=nl-ams-1
LIMIT ?=
LIMIT_FLAG := $(if $(strip $(LIMIT)),-l $(LIMIT),)

# For ad-hoc ansible (ping/test), choose pattern explicitly
TARGET := $(if $(strip $(LIMIT)),$(LIMIT),mask_nodes)

# Tooling presence
HAVE_GH := $(shell command -v gh >/dev/null 2>&1 && echo yes || echo no)
HAVE_JQ := $(shell command -v jq >/dev/null 2>&1 && echo yes || echo no)
HAVE_AI := $(shell command -v ansible-inventory >/dev/null 2>&1 && echo yes || echo no)

# Release tagging
TAG ?= v$(shell date -u +%Y%m%d-%H%M%S)
MSG ?= release $(TAG)

.PHONY: help up down logs ps rebuild deploy deploy-check status lint lint-yaml env \
        ping test-nginx release ssh-known-hosts

help:
	@echo ""
	@echo "Targets:"
	@echo "  make up               - docker compose up --build -d (локальный контейнер)"
	@echo "  make down             - docker compose down"
	@echo "  make logs             - docker compose logs -f --tail=200"
	@echo "  make ps               - docker compose ps"
	@echo "  make rebuild          - полная пересборка образов и запуск"
	@echo "  make deploy           - ansible-playbook playbook.yml   [LIMIT=<host|group>]"
	@echo "  make deploy-check     - dry-run (+diff) деплоя           [LIMIT=<host|group>]"
	@echo "  make status           - ansible check_status.yml         [LIMIT=<host|group>]"
	@echo "  make ping             - ansible ping хостов              [LIMIT=<host|group>]"
	@echo "  make test-nginx       - удалённый 'nginx -t' по всем     [LIMIT=<host|group>]"
	@echo "  make ssh-known-hosts  - собрать ~/.ssh/known_hosts из inventory.ini (alias/ansible_host/ansible_port)"
	@echo "  make release          - git tag + push; если есть gh — триггерит workflow 'deploy'"
	@echo "  make lint             - ansible-lint плейбуков"
	@echo "  make lint-yaml        - yamllint каталога deploy/ansible"
	@echo "  make env              - показать важные переменные"
	@echo ""
	@echo "Примеры:"
	@echo "  make deploy LIMIT=nl-ams-1"
	@echo "  make test-nginx LIMIT=mask_nodes"
	@echo "  make release TAG=v2025.09.10-1 LIMIT=nl-ams-1"
	@echo ""

# ---- Docker (локальная разработка) ----
# Локально поднять контейнеры: make up
up:
	$(COMPOSE) up --build -d

down:
	$(COMPOSE) down

# Посмотреть логи: make logs
logs:
	$(COMPOSE) logs -f --tail=200

ps:
	$(COMPOSE) ps

# Пересобрать «с нуля»: make rebuild
rebuild:
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

# ---- Ansible ----
# Прокатить деплой на один узел: make deploy LIMIT=nl-ams-1
deploy:
	$(ANSIBLE_PLAYBOOK) deploy/ansible/playbook.yml $(LIMIT_FLAG)

# «Сухой» прогон (diff, без изменений) на группу/узел: make deploy-check LIMIT=mask_nodes
deploy-check:
	$(ANSIBLE_PLAYBOOK) deploy/ansible/playbook.yml --check --diff $(LIMIT_FLAG)

# Проверить /api/status на всех узлах: make status
status:
	$(ANSIBLE_PLAYBOOK) deploy/ansible/check_status.yml $(LIMIT_FLAG)

lint:
	$(ANSIBLE_LINT) deploy/ansible/playbook.yml
	$(ANSIBLE_LINT) deploy/ansible/check_status.yml

lint-yaml:
	$(YAMLLINT) deploy/ansible

env:
	@echo "COMPOSE      = $(COMPOSE)"
	@echo "INV          = $(INV)"
	@echo "LIMIT        = $(LIMIT)"
	@echo "TARGET       = $(TARGET)"
	@echo "LIMIT_FLAG   = $(LIMIT_FLAG)"
	@echo "HAVE_GH      = $(HAVE_GH)"
	@echo "HAVE_JQ      = $(HAVE_JQ)"
	@echo "HAVE_AI      = $(HAVE_AI)"
	@echo "TAG          = $(TAG)"
	@echo "MSG          = $(MSG)"

# ---- Ad-hoc checks ----
# Пинг всех узлов: make ping
# Только один хост/группу: make ping LIMIT=nl-ams-1
ping:
	ansible -i $(INV) $(TARGET) -m ping -o

# Проверка конфигурации nginx на удалённых серверах: make test-nginx, make test-nginx LIMIT=nl-ams-1
test-nginx:
	ansible -i $(INV) $(TARGET) -b -m command -a 'nginx -t' -o

# ---- SSH known_hosts from inventory ----
# make ssh-known-hosts заранее заполняет ваш ~/.ssh/known_hosts ключами всех серверов из инвентаря
# работает с алиасами из ~/.ssh/config
# Собрать known_hosts по всем хостам группы mask_nodes: make ssh-known-hosts
# Без этого при первом коннекте SSH спрашивает подтверждение ключа, что ломает автоматизацию.
# С предзаполненным known_hosts Ansible работает полностью без диалогов, при этом проверка хоста не выключена
ssh-known-hosts:
	@set -euo pipefail; \
	hosts="$$(ansible -i $(INV) $(TARGET) --list-hosts | sed '1d;s/^[[:space:]]*//')"; \
	if [ -z "$$hosts" ]; then echo "No hosts matched ($(TARGET))"; exit 1; fi; \
	for h in $$hosts; do \
	  echo ">>> Accepting host key for $$h"; \
	  ssh -q \
	    -o StrictHostKeyChecking=accept-new \
	    -o BatchMode=yes \
	    -o ConnectTimeout=5 \
	    "$$h" 'exit 0' || true; \
	done; \
	echo "known_hosts updated: $$HOME/.ssh/known_hosts"

# ---- Release helper ----
# 1) Создаёт аннотированный git-тег и пушит его.
# 2) Если установлен GitHub CLI (gh) и есть workflow 'deploy' с workflow_dispatch —
#    запускает его с inputs: limit=$(LIMIT), check=false.
# Релиз (тег + запуск Actions «deploy», если установлен gh):
# make release                # создаст тег вида vYYYYMMDD-HHMMSS
# make release TAG=v2025.09.10-1 LIMIT=nl-ams-1
release:
	@git tag -a $(TAG) -m "$(MSG)" && git push origin $(TAG)
ifeq ($(HAVE_GH),yes)
	@echo "gh detected → triggering workflow 'deploy' (workflow_dispatch)…"
	@gh workflow run deploy -f limit="$(LIMIT)" -f check=false || \
	  (echo "Failed to trigger GH workflow. Open Actions tab and run 'deploy' manually."; exit 1)
else
	@echo "No gh CLI found. Tag $(TAG) pushed."
	@echo "If you want to auto-trigger GitHub Actions, install GitHub CLI (gh) or run the 'deploy' workflow manually."
endif

# Установка публичного ключа на целевой сервер (HOST=алиас из ~/.ssh/config)
# Если есть пароль (первичное подключение), ssh спросит его.
# make push-key HOST=nl-ams-3
push-key:
	@if [ -z "$(HOST)" ]; then echo "Usage: make push-key HOST=nl-ams-3"; exit 1; fi
	@if [ ! -f $$HOME/.ssh/ds_ansible.pub ]; then echo "~/.ssh/ds_ansible.pub not found"; exit 1; fi
	@echo ">>> Installing ~/.ssh/ds_ansible.pub to $(HOST):~/.ssh/authorized_keys"
	@cat $$HOME/.ssh/ds_ansible.pub | ssh -o StrictHostKeyChecking=accept-new -o BatchMode=no "$(HOST)" \
	  'umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys && echo OK' || \
	  (echo "Failed to copy key. Check HOST, password, network."; exit 1)