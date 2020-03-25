from alpine:latest
# Verified on alpine:3.11

RUN apk add --no-cache bash python3 librsync gnupg py3-boto mysql-client postgresql-client

ENV basedir=/root
COPY src $basedir/src

