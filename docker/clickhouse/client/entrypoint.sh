#!/bin/bash

# 并发批量导入数据
sleep 10

starttime=$(date +%Y-%m-%d\ %H:%M:%S)
echo $starttime
for i in 1 2 3 4 5 6 7; do
    for file in /hdd/hdd${i}/data/*.csv ; do
        clickhouse-client \
        --use_client_time_zone true \
        --host 10.5.0.$((${i} + 1)) \
        --port 9000 \
        --query="INSERT INTO taq5 FORMAT CSV"  < $file &
    done;
done;


sleep infinity

# sudo docker run -it \
# yandex/clickhouse-client \
# --use_client_time_zone true \
# --host 115.239.209.224 \
# --port 19001 \
