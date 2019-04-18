# 修改时区
sudo ln -sf /usr/share/zoneinfo/Etc/GMT-1 /etc/localtime

clickhouse-client --use_client_time_zone true  --query="INSERT INTO taq_local FORMAT CSV" < new_TAQ.csv

for filename in ./*.csv; do
        python csv_transfer.py $filename | \
        # clickhouse-client --use_client_time_zone true --query="INSERT INTO taq_local FORMAT CSV"
done 

# 恢复
sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
