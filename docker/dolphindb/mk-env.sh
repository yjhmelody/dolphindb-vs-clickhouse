#!/bin/bash
# please run it at `pwd`

for i in 1 2 3 4 5 6 7; do
    echo $i
    sudo mkdir -p /hdd/hdd${i}/dolphindb/data/ddb/server/log
    sudo mkdir -p /hdd/hdd${i}/dolphindb/data/ddb/server/config
    sudo mkdir -p /hdd/hdd${i}/data2/TAQ
    sudo cp -r ./cluster/server${i} /hdd/hdd${i}/dolphindb/
done;
