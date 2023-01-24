ARG POSTGRES_VERSION
FROM postgres:$POSTGRES_VERSION as pg_base

FROM pg_base as base_build
ARG POSTGRES_MAJOR_VERSION

RUN apt-get update && apt-get install -y \
  curl \
  gcc \
  make \
  postgresql-server-dev-${POSTGRES_MAJOR_VERSION} \
  libkrb5-dev \
  libselinux1-dev \
  libxslt1-dev \
  libzstd-dev \
  liblz4-dev \
  libpam-dev \
  libreadline-dev \
  zlib1g-dev

FROM base_build as citus

ARG POSTGRES_MAJOR_VERSION
ARG CITUSTAG=v11.1.5

ENV PG_CONFIG /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_config

RUN git clone -b ${CITUSTAG} --depth 1 https://github.com/citusdata/citus.git /usr/src/citus
WORKDIR /usr/src/citus

RUN ./configure
RUN make -s clean && make -s -j8 install

FROM base_build as pg_cron

ARG POSTGRES_MAJOR_VERSION
ARG PG_CRON_TAG=v1.4.2

ENV PG_CONFIG /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_config

RUN git clone -b ${PG_CRON_TAG} --depth 1 https://github.com/citusdata/pg_cron.git /usr/src/pg_cron
WORKDIR /usr/src/pg_cron

RUN ./configure
RUN make -s clean && make -s -j8 install

FROM base_build as pg_auto_failover
ARG POSTGRES_VERSION
ARG POSTGRES_MAJOR_VERSION
ARG PG_AUTO_FAILOVER_VERSION=2.0

ENV PG_CONFIG /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_config

RUN mkdir -p /build && \
  curl -L https://github.com/citusdata/pg_auto_failover/archive/refs/tags/v${PG_AUTO_FAILOVER_VERSION}.tar.gz -o /build/pgaf.tar.gz && \
  cd /build && tar -xvf pgaf.tar.gz && \
  cd /build/pg_auto_failover-${PG_AUTO_FAILOVER_VERSION} && \
  make -s clean && make -s install -j8

# kill all settings on the postgres image
FROM scratch
ARG PG_AUTO_FAILOVER_VERSION=2.0
ARG POSTGRES_VERSION
ARG POSTGRES_MAJOR_VERSION
ENV POSTGRES_MAJOR_VERSION=$POSTGRES_MAJOR_VERSION
COPY --from=pg_base / /

COPY --from=pg_cron /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib/pg_cron*.so /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib
COPY --from=pg_cron /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/pg_cron* /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/

COPY --from=citus /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib/citus*.so /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib
COPY --from=citus /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/citus* /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/

COPY --from=pg_auto_failover /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib/pgautofailover.so /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/lib
COPY --from=pg_auto_failover /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/pgautofailover* /usr/share/postgresql/${POSTGRES_MAJOR_VERSION}/extension/
COPY --from=pg_auto_failover /usr/lib/postgresql/${POSTGRES_MAJOR_VERSION}/bin/pg_autoctl /usr/local/bin

RUN apt-get update && apt-get install -y \
  sudo \
  libncurses6

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
