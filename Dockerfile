FROM mysql:9.6.0

LABEL maintainer="DevSecOps"

COPY --chown=mysql:mysql appdb.sql /docker-entrypoint-initdb.d/

HEALTHCHECK CMD mysqladmin ping -h localhost || exit 1
USER mysql
EXPOSE 3306
