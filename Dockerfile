FROM mysql:8.0

LABEL maintainer="DevSecOps"
LABEL description="Custom MySQL image"
LABEL version="1.0"
RUN microdnf install -y iputils nmap-ncat bind-utils telnet curl

USER mysql

EXPOSE 3306

