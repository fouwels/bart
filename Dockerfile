# SPDX-FileCopyrightText: 2022 Kaelan Thijs Fouwels <kaelan.thijs@fouwels.com>
# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT


FROM alpine:3.15.1

RUN apk add --no-cache bash duplicity py3-paramiko openldap-clients postgresql-client rsync

# Manually upgrade for CVE-2022-0778
RUN apk add --no-cache libretls=3.3.4-r3

COPY ./src/ /root/src/
RUN chmod +x /root/src/bart.sh
RUN chmod +x /root/src/restore-to-docker.sh

ENV PATH $PATH:/root/src/
