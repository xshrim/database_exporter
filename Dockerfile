FROM oraclelinux:8
# FROM        ghcr.io/oracle/oraclelinux7-instantclient:19

WORKDIR     /exporter/

ADD         database_exporter.tgz /exporter/

RUN         dnf -y update && dnf clean all && dnf -y install libaio make gcc gcc-c++ glibc-devel oracle-instantclient-release-el8 oracle-instantclient-basic oracle-instantclient-devel oracle-instantclient-sqlplus && rm -rf /var/cache/dnf

EXPOSE      9285

CMD  [ "/exporter/database_exporter", "-logtostderr=true" ]

