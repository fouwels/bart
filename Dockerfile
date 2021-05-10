FROM alpine:3.13.5

RUN apk add --no-cache bash duplicity py3-paramiko

COPY ./src/ /root/src/
RUN chmod +x /root/src/bart.sh
RUN chmod +x /root/src/restore-to-docker.sh

ENV PATH $PATH:/root/src/
