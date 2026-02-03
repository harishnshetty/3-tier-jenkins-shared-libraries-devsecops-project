FROM mysql:5.7

COPY appdb.sql /docker-entrypoint-initdb.d/

USER mysql

EXPOSE 3306
CMD ["mysqld"]

