
USER root

RUN apt-get update && apt-get install -y postgresql-client curl

RUN mkdir -p /etc/haproxy
COPY check_primary.sh /etc/haproxy/check_primary.sh
COPY check_secondary.sh /etc/haproxy/check_secondary.sh

USER haproxy