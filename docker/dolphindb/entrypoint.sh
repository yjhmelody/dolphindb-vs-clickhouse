#!/bin/bash

cd /data/ddb/server && \
mkdir -p /data/ddb/server/log && \
echo $(date) > /data/ddb/server/log/run.log

# run job based on mode
if [[ -z "${DEPLOY_MODE}" ]]; then
echo "Running ddb in standalone mode." >> /data/ddb/server/log/run.log
./dolphindb -console 0 >> /data/ddb/server/log/run.log &
elif [ $DEPLOY_MODE == 'controller' ]
then
echo "Running ddb in controller mode." >> /data/ddb/server/log/run.log
/data/ddb/server/dolphindb -console 0 -mode controller -home /data/ddb/server -config config/controller.cfg -logFile log/controller.log -nodesFile config/cluster.nodes -clusterConfig config/cluster.cfg &
elif [ $DEPLOY_MODE == 'agent' ]
then
echo "Running ddb in agent mode." >> /data/ddb/server/log/run.log
/data/ddb/server/dolphindb -console 0 -mode agent -home /data/ddb/server -config config/agent.cfg -logFile log/agent.log &
else
echo "Something is wrong in parsing ddb mode." >> /data/ddb/server/log/run.log
fi

# ps job
ps -ef | grep dolphindb >> /data/ddb/server/log/run.log

# keep alive
sleep infinity

# have to map the following Volumes
# /data/ddb/server/log
# /data/ddb/server/master
# /data/ddb/server/P1-agent
# /data/ddb/server/P1-node1
# /data/ddb/server/P1-node2
# ...
# file
