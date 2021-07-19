# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT

# Compose
COMPOSE=compose-cli compose
BUILDFILE=stack.yml
DOCKER=docker

# Config
build:
	$(COMPOSE) -f $(BUILDFILE) build
push:
	$(COMPOSE) -f $(BUILDFILE) push