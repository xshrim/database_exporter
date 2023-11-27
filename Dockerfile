FROM        ghcr.io/oracle/oraclelinux7-instantclient:19
WORKDIR     /exporter/
RUN         yum -y update && yum clean all
RUN         yum -y install libaio

ADD         https://github.com/xshrim/database_exporter/releases/download/0.6.6/database_exporter.tar.gz /exporter/
RUN         tar -xzvf database_exporter.tar.gz

EXPOSE      9285

ENTRYPOINT  [ "/exporter/database_exporter", "-logtostderr=true" ]

