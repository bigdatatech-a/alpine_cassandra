#!/bin/sh

CASSANDRA_VERSION="3.7"
URL="http://archive.apache.org/dist/cassandra/${CASSANDRA_VERSION}/apache-cassandra-${CASSANDRA_VERSION}-bin.tar.gz" 

curl -L $URL > /tmp/cassandra.tar.gz

mkdir -p /opt

tar -xzvf /tmp/cassandra.tar.gz -C /opt
ln -s /opt/apache-cassandra-${CASSANDRA_VERSION} /opt/cassandra
rm -rf /tmp/cassandra.tar.gz
mkdir -p /var/lib/cassandra
mkdir -p /var/log/cassandra

