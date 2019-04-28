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
        --query="INSERT INTO taq FORMAT CSV"  < $file &
    done;
done;

sleep infinity

# sudo docker run -it yandex/clickhouse-client --use_client_time_zone true --host $clickhouseip --port 1900$1 --query="INSERT INTO taq FORMAT CSV" < $filename

sudo docker run -it \
yandex/clickhouse-client \
--use_client_time_zone true \
--host 115.239.209.224 \
--port 19001 \



# starttime=$(date +%Y-%m-%d\ %H:%M:%S)
# echo $starttime

# for i in 01 02 03 06 07 08 09 10 13 14 15; do
# clickhouse-client \
# --use_client_time_zone true \
# --host 115.239.209.224 \
# --port 19001 \
# --query="INSERT INTO taq FORMAT CSV"  < /mnt/data/NEW_TAQ/TAQ200708$i.csv
# done;

# for i in 16 17 20 21 22 23 24 27 28 29 30 31; do
# clickhouse-client \
# --use_client_time_zone true \
# --host 115.239.209.224 \
# --port 19002 \
# --query="INSERT INTO taq FORMAT CSV"  < /mnt/data/NEW_TAQ/TAQ200708$i.csv
# done;

# endtime=$(date +"%Y-%m-%d %H:%M:%S")
# echo $endtime