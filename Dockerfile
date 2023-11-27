FROM        ghcr.io/oracle/oraclelinux7-instantclient:19
WORKDIR     /exporter/

ADD         database_exporter.tgz /exporter/

RUN         yum -y update && yum clean all && yum -y install libaio make gcc gcc-c++ glib-headers

EXPOSE      9285

CMD  [ "/exporter/database_exporter", "-logtostderr=true" ]

