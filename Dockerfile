FROM alpine:3.12.1

RUN apk add --no-cache bash py3-pip python3 librsync gnupg py3-boto mysql-client postgresql-client gcc python3-dev musl-dev linux-headers librsync openldap-clients
RUN apk add --no-cache librsync-dev rsync gettext
RUN pip3 install setuptools_scm
RUN pip3 install duplicity

COPY ./src/ /root/src/
RUN chmod +x /root/src/bart.sh
RUN chmod +x /root/src/restore-to-docker.sh

ENV PATH $PATH:/root/src
