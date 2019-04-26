#!/bin/bash

# 并发批量导入数据

# sudo docker run -it yandex/clickhouse-client --use_client_time_zone true --host $clickhouseip --port 1900$1 --query="INSERT INTO taq FORMAT CSV" < $filename

# sudo docker run -d -v /hdd/hdd1/data/:/hdd/hdd1/data/ \
# yandex/clickhouse-client \
# --use_client_time_zone true \
# --host 115.239.209.224 \
# --port 19001 \
# --query="INSERT INTO taq FORMAT CSV"  < /mnt/data/NEW_TAQ/TAQ20070816.csv


for i in 1 2 3 6 7 8 9 10 13 14 15; do
clickhouse-client \
--use_client_time_zone true \
--host 115.239.209.224 \
--port 19001 \
--query="INSERT INTO taq FORMAT CSV"  < /mnt/data/NEW_TAQ/TAQ200708$i.csv &
done;

for i in 20 21 22 23 24 27 28 29 30 31; do
clickhouse-client \
--use_client_time_zone true \
--host 115.239.209.224 \
--port 19002 \
--query="INSERT INTO taq FORMAT CSV"  < /mnt/data/NEW_TAQ/TAQ200708$i.csv &
done;