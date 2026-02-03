FROM mysql:5.7

COPY appdb.sql /docker-entrypoint-initdb.d/

RUN useradd -m mysql
RUN chown -R mysql /var/lib/mysql
USER mysql

EXPOSE 3306
CMD ["mysqld"]

