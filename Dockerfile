# SPDX-FileCopyrightText: 2022 Kaelan Thijs Fouwels <kaelan.thijs@fouwels.com>
# SPDX-FileCopyrightText: 2021 Belcan Advanced Solution
#
# SPDX-License-Identifier: MIT


FROM alpine:3.16.2

RUN apk add --no-cache bash duplicity py3-pip python3 py3-paramiko openldap-clients postgresql-client rsync
RUN pip3 install azure-storage-blob

COPY ./src/ /root/src/

ENV PATH $PATH:/root/src/
