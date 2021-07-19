<!--
SPDX-FileCopyrightText: 2021 Belcan Advanced Solution

SPDX-License-Identifier: MIT
-->

Heavily modified and dockerized by KF

An additional script has been added, executable via `restore-to-docker.sh`.

This will take files restored by BART into, and restore them to ldap, and the alfresco and postgres database containers. This should be run after performing a BART restore

BART commands can be called once the container is running via `docker exec -it bart bart.sh <command>`. For example, `docker exec -it bart bart.sh backup`, `docker exec -it bart bart.sh backup ldap`

Restore_container can be called as `docker exec -it bart restore-to-docker.sh`.

LDAP Backup support has been added.

See https://github.com/toniblyx/alfresco-backup-and-recovery-tool for upstream