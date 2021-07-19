# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT


FROM alpine:3.14.0

RUN apk add --no-cache bash duplicity py3-paramiko openldap-clients postgresql-client rsync

COPY ./src/ /root/src/
RUN chmod +x /root/src/bart.sh
RUN chmod +x /root/src/restore-to-docker.sh

ENV PATH $PATH:/root/src/
