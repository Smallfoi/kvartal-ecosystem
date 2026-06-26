# STAW backend — операторские команды.
# Dev: docker-compose.yml · Prod: docker-compose.prod.yml (+ .env). Подробности — docs/DEPLOY.md.
DC      := docker compose
DC_PROD := docker compose -f docker-compose.prod.yml --env-file .env

.DEFAULT_GOAL := help

help: ## список команд
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

# ── Dev ───────────────────────────────────────────────────────────
up: ## поднять dev (postgis + web)
	$(DC) up -d
down: ## остановить dev
	$(DC) down
logs: ## логи web (dev)
	$(DC) logs -f web
test: ## прогнать тесты
	$(DC) exec -T web python manage.py test
migrate: ## миграции (dev)
	$(DC) exec -T web python manage.py migrate
shell: ## bash в web (dev)
	$(DC) exec web bash

# ── Prod (на сервере) ─────────────────────────────────────────────
prod-deploy: ## деплой/обновление прод (бэкап+сборка+миграции+smoke)
	./deploy/deploy.sh
prod-up: ## поднять прод
	$(DC_PROD) up -d --build
prod-down: ## остановить прод
	$(DC_PROD) down
prod-logs: ## логи прод-web
	$(DC_PROD) logs -f web
backup: ## бэкап прод-БД
	./deploy/backup.sh
restore: ## восстановить БД: make restore FILE=backups/xxx.sql.gz
	./deploy/restore.sh $(FILE)
smoke: ## smoke-тест прод
	./deploy/smoke.sh

.PHONY: help up down logs test migrate shell prod-deploy prod-up prod-down prod-logs backup restore smoke
