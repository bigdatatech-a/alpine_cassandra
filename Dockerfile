FROM bigdatatech/alpine_with_jdk8:latest

MAINTAINER sandeep <bigdatatechcomputing@gmail.com>

COPY setup_cassandra.sh /tmp/setup_cassandra.sh

RUN chmod +x /tmp/*.sh
RUN /tmp/setup_cassandra.sh

ENV CASSANDRA_HOME /opt/cassandra
ENV PATH ${PATH}:${CASSANDRA_HOME}/bin
ENV CQLSH_NO_BUNDLED true

EXPOSE 7199 7000 7001 9160 9042
VOLUME ["/opt/cassandra/data"]

ADD config_and_start_C.sh /usr/bin/config_and_start_C.sh
RUN chmod +x /usr/bin/*.sh

RUN pip install cassandra-driver

COPY metrics-graphite-3.1.2.jar /opt/cassandra/lib

CMD config_and_start_C.sh
