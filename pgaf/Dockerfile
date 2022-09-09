FROM postgres:14.5

RUN apt-get update && apt-get install -y curl && \
  curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - && \
  echo "deb http://apt.postgresql.org/pub/repos/apt bullseye-pgdg main" > /etc/apt/sources.list.d/pgdg.list

# FIXME: install a specific version!
RUN apt-get update && apt-get install -y \
  pg-auto-failover-cli \
  postgresql-14-auto-failover \
  sudo

RUN mkdir -p /etc/pgaf/
RUN mkdir -p /etc/pgaf/ssl
COPY ssl /etc/pgaf/ssl/
RUN mkdir -p /etc/pgaf/ssl/certs

COPY entrypoint.sh /usr/bin/entrypoint
RUN chmod +x /usr/bin/entrypoint

RUN mkdir -p /var/lib/postgresql/data
RUN chown -R postgres:postgres /var/lib/postgresql

ENV PGAF_SSL_CA /var/run/secrets/ssl_ca
# TODO: implement CRL support
# ENV PGAF_SSL_CRL /var/run/secrets/ssl_crl
ENV PGAF_SSL_CERT /var/run/secrets/ssl_cert
ENV PGAF_SSL_KEY /var/run/secrets/ssl_key
ENV PGAF_SSL_MODE verify-ca

USER root
ENTRYPOINT ["entrypoint"]
