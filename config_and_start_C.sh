#!/bin/sh

echo -e "Running setup for ${NAME}"

HOST_IP=$(/sbin/ifconfig eth0 | grep 'inet addr:' | cut -d: -f2 | awk '{ print $1}')
HOST=$(hostname)
echo "127.0.0.1 $HOST localhost.localdomain localhost" > /etc/hosts
echo "::1 $HOST localhost.localdomain localhost" >> /etc/hosts



if [[ -z $SEED ]]; then
    SEEDS=$HOST_IP
    IP=$HOST_IP

else
    
    cp /etc/resolv.conf /etc/resolv.conf.bkp
    echo "nameserver $NAME_SERVER" > /etc/resolv.conf

# Make sure mesos dns will add new seeds when deployed for the first time
    sleep 60
 
    SEED=`echo $(dig +short $SEED) | tr ' ' ','`
   
for i in $(echo $SEED | sed "s/,/ /g")
do
    # call your procedure/other scripts here below
    ip_to_host=`nslookup $i | grep -i Address`
    hostname=`echo $ip_to_host | awk '{print $4}'`
    echo $hostname

if [ -z "$SEEDS" ]; then
SEEDS=$hostname
else
SEEDS=$SEEDS",$hostname"
fi

# Resolve containser hostname from container IP for listen_address and broadcast_address

if [ "$i" == "$HOST_IP" ]; then
IP=$hostname
fi

done

if [ -z "$IP" ]; then
ip_to_host=`nslookup $HOST_IP | grep -i Address`
IP=`echo $ip_to_host | awk '{print $4}'`
fi

fi


echo "Seeds list is : $SEEDS"


echo -e "Listening on: ${IP}"
echo -e "Found seeds: ${SEEDS}"

# configure cacassandra.yaml
CONFIG=/opt/cassandra/conf/cassandra.yaml
CASS_ENV=/opt/cassandra/conf/cassandra-env.sh

sed -i -e "s/^listen_address.*/listen_address: ${IP}/" ${CONFIG}
sed -i -e "s/^rpc_address.*/rpc_address: 0.0.0.0/" ${CONFIG}
sed -i -e "s/^# broadcast_rpc_address: 1.2.3.4/broadcast_rpc_address: ${IP}/g" ${CONFIG}
sed -i -e "s/- seeds: \"127.0.0.1\"/- seeds: \"${SEEDS}\"/" ${CONFIG}
sed -i -e "s/start_rpc: false/start_rpc: true/g" ${CONFIG}
sed -i -e "s/commitlog_directory: \/var\/lib\/cassandra\/commitlog/commitlog_directory: \/tmp\/commmitlog/g" ${CONFIG}


sed -i -e "s/# JVM_OPTS=\"${JVM_OPTS} -Djava.rmi.server.hostname=<public name>\"/ JVM_OPTS=\"${JVM_OPTS} -Djava.rmi.server.hostname=$IP\"/" ${CASS_ENV}
sed -i -e "s/LOCAL_JMX=yes/LOCAL_JMX=no/g" ${CASS_ENV}
sed -i -e 's/JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=true"/JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=false"/g' ${CASS_ENV}
echo "JVM_OPTS=\"\$JVM_OPTS -Dcassandra.metricsReporterConfigFile=influxdb.yaml\"" >> ${CASS_ENV}


#Influxdb related settings

echo "graphite:" > /opt/cassandra/conf/influxdb.yaml
echo "-" >> /opt/cassandra/conf/influxdb.yaml
echo "  period: 60" >> /opt/cassandra/conf/influxdb.yaml
echo "  timeunit: 'SECONDS'" >> /opt/cassandra/conf/influxdb.yaml
echo "  prefix: '$(hostname)'" >> /opt/cassandra/conf/influxdb.yaml
echo "  hosts:" >> /opt/cassandra/conf/influxdb.yaml
echo "  - host: '${HOST_IP}'" >> /opt/cassandra/conf/influxdb.yaml
echo "    port: 2003" >> /opt/cassandra/conf/influxdb.yaml
echo "  predicate:" >> /opt/cassandra/conf/influxdb.yaml
echo "    color: \"white\"" >> /opt/cassandra/conf/influxdb.yaml
echo "    useQualifiedName: true" >> /opt/cassandra/conf/influxdb.yaml
echo "    patterns:" >> /opt/cassandra/conf/influxdb.yaml
echo "    - \".*\"" >> /opt/cassandra/conf/influxdb.yaml





# If we were passed a cluster name in the env that use that, else set it.
if [ -z "${CLUSTER_NAME}" ]; then
    CLUSTER_NAME="CASSANDRA DOCKER"
    echo -e "Cluster name will be: ${CLUSTER_NAME}"
    sed -i -e "s/cluster_name: 'Test Cluster'/cluster_name: '${CLUSTER_NAME}'/g" ${CONFIG}
else
    CLUSTER_NAME=${CLUSTER_NAME}
    echo -e "Cluster name will be: ${CLUSTER_NAME}"
    sed -i -e "s/cluster_name: 'Test Cluster'/cluster_name: '${CLUSTER_NAME}'/g" ${CONFIG}
fi

#Heap memory calculation

MEM_INTEGER=$(free -m | awk '/:/ {print $2;exit}')


half_system_memory_in_mb=`expr $MEM_INTEGER / 2`

quarter_system_memory_in_mb=`expr $half_system_memory_in_mb / 2`

if [ "$half_system_memory_in_mb" -gt "1024" ]
then
	half_system_memory_in_mb="1024"
fi

if [ "$quarter_system_memory_in_mb" -gt "8192" ]
then
	quarter_system_memory_in_mb="8192"
fi

if [ "$half_system_memory_in_mb" -gt "$quarter_system_memory_in_mb" ]
then
	max_heap_size_in_mb="$half_system_memory_in_mb"
else
	max_heap_size_in_mb="$quarter_system_memory_in_mb"
fi


export MAX_HEAP_SIZE="${max_heap_size_in_mb}M"
desired_yg_in_mb=`expr $max_heap_size_in_mb / 4`
export HEAP_NEWSIZE="${desired_yg_in_mb}M"

echo "HEAP_NEWSIZE=" $HEAP_NEWSIZE
echo "MAX_HEAP_SIZE=" $MAX_HEAP_SIZE

echo 'echo $JVM_OPTS' >> ${CASS_ENV}

#ulimit -c unlimited

cassandra -f -R
