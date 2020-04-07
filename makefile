# Compose
COMPOSE=docker-compose
BUILDFILE=stack.yml
DOCKER=docker

# Config
build:
	$(COMPOSE) -f $(BUILDFILE) build
push:
	$(COMPOSE) -f $(BUILDFILE) push