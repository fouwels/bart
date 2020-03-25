# Compose
COMPOSE=docker-compose
BUILDFILE=build.yml
STACKFILE=./stack/stack.yml
DOCKER=docker

# Config
build:
	$(COMPOSE) -f $(BUILDFILE) build
push:
	$(COMPOSE) -f $(BUILDFILE) push