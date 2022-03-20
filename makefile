# SPDX-FileCopyrightText: 2022 Kaelan Thijs Fouwels <kaelan.thijs@fouwels.com>
# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT

# Compose
COMPOSE=docker compose
BUILDFILE=compose.yml
DOCKER=docker

# Config
build:
	$(COMPOSE) -f $(BUILDFILE) build
push:
	$(COMPOSE) -f $(BUILDFILE) push