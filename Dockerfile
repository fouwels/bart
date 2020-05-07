FROM alpine:latest
# Verified on alpine:3.11

RUN apk add --no-cache bash py3-pip python3 librsync gnupg py3-boto mysql-client postgresql-client gcc python3-dev musl-dev linux-headers librsync
RUN apk add --no-cache librsync-dev rsync gettext
RUN pip3 install setuptools_scm
RUN pip3 install duplicity

COPY ./src/ /root/src/
RUN chmod +x /root/src/bart.sh
RUN chmod +x /root/src/restore_container.sh
ENV PATH $PATH:/root/src

# Create to allow script to place it's logs
RUN mkdir -p /var/log/bart
RUN touch /var/log/bart/log.txt
RUN ln -sf /dev/stdout /var/log/bart/log.txt && ln -sf /dev/stderr /var/log/bart/log.txt

CMD ["tail", "-f", "/var/log/bart/log.txt"]
