# 分半导入
# sudo mv TAQ2007080[0-9].csv ../temp/
# sudo mv TAQ2007081[0-5].csv ../temp/

# 修改时区
# sudo ln -sf /usr/share/zoneinfo/Etc/GMT-1 /etc/localtime

# for filename in ./*.csv; do
#         python csv_transfer.py $filename | \
#         clickhouse-client --use_client_time_zone true --query="INSERT INTO taq FORMAT CSV"
# done 

echo "start inserting" >> time.txt
starttime=end:$(date +%Y-%m-%d\ %H:%M:%S)
echo $starttime >> time.txt

for filename in ./*.csv; do
        clickhouse-client --use_client_time_zone true --query="INSERT INTO taq FORMAT CSV" < $filename
done 

ttime=start:$(date +"%Y-%m-%d %H:%M:%S")
echo $ttime >> time.txt

# 恢复
# sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime


