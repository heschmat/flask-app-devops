COMPOSE=docker compose -f app/docker-compose.dev.yaml

.PHONY: run lint test format build down

run:
	$(COMPOSE) up app

lint:
	$(COMPOSE) run --rm lint

test:
	$(COMPOSE) run --rm test

format:
	$(COMPOSE) run --rm format

build:
	$(COMPOSE) build

down:
	$(COMPOSE) down
