ARG POSTGRES_VERSION
FROM postgres:$POSTGRES_VERSION as build
# kill all settings on the postgres image
FROM scratch
ARG POSTGRES_VERSION
COPY --from=build / /

RUN apt-get update && apt-get install -y curl && \
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
  echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# FIXME: install a specific version!
RUN apt-get update && apt-get install -y \
  pg-auto-failover-cli \
  postgresql-$POSTGRES_VERSION-auto-failover \
  sudo

RUN mkdir -p /etc/pgaf/
RUN mkdir -p /etc/pgaf/config
COPY config /etc/pgaf/config/

COPY pgaf.sh /usr/bin/pgaf
RUN chmod +x /usr/bin/pgaf

RUN mkdir -p /var/lib/postgresql/data
RUN chown -R postgres:postgres /var/lib/postgresql

ENV PGAF_SSL_CA /var/run/secrets/ssl_ca
# TODO: implement CRL support?
# ENV PGAF_SSL_CRL /var/run/secrets/ssl_crl
ENV PGAF_SSL_CERT /var/run/secrets/ssl_cert
ENV PGAF_SSL_KEY /var/run/secrets/ssl_key
ENV PGAF_SSL_MODE verify-ca

ENV PGDATA /var/lib/postgresql/data/cluster

USER root
ENTRYPOINT ["pgaf"]
