#!/bin/bash

for i in 0 1 2 3 4 5 6 7; do
    echo $i
    sudo mkdir -p /hdd/hdd${i}/clickhouse/log
    sudo mkdir -p /hdd/hdd${i}/data
done;

sudo mkdir -p /hdd/etc/clickhouse
sudo cp env/config/* /hdd/etc/clickhouse-server/
sudo cp env/config/metrika.xml /hdd/etc/metrika.xml