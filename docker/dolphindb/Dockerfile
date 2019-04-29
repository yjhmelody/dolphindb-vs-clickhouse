FROM centos:latest

ARG base_url="http://www.dolphindb.com/downloads/"

ARG dolphindb_version="DolphinDB_Linux64_V0.95.3.zip"
ARG zlib_version="ZLIB_V0.95.0.zip"
ARG awss3_version="AWSS3_V0.95.0.zip"

ARG dolphindb="${base_url}${dolphindb_version}"
ARG zlib="${base_url}${zlib_version}"
ARG awss3="${base_url}${awss3_version}"

RUN yum install -y unzip
RUN yum install -y wget

RUN mkdir -p /data/ddb/
RUN mkdir -p /data/ddb/server/config

ADD entrypoint.sh /root/
RUN chmod 755 /root/entrypoint.sh

ADD ${dolphindb} /data/ddb/
ADD ${awss3} /data/ddb/server/
ADD ${zlib} /data/ddb/server/

RUN cd /data/ddb/ && unzip /data/ddb/${dolphindb_version}
RUN cd /data/ddb/server/ && unzip -n /data/ddb/server/${zlib_version}
RUN cd /data/ddb/server/ && unzip -n /data/ddb/server/${awss3_version}
RUN chmod 755 /data/ddb/server/dolphindb

RUN rm -rf /data/ddb/server/plugins/README.md
RUN rm -rf /data/ddb/server/${dolphindb_version}
RUN rm -rf /data/ddb/server/${zlib_version}
RUN rm -rf /data/ddb/server/${awss3_version}

ENTRYPOINT ["/root/entrypoint.sh"]
#CMD ["/bin/bash"]
