# Dokcer 环境下并发导入脚本

# 分半导入
# sudo mv TAQ2007080[0-9].csv ../temp/
# sudo mv TAQ2007081[0-5].csv ../temp/

# 修改时区
# sudo ln -sf /usr/share/zoneinfo/Etc/GMT-1 /etc/localtime

echo "start time:" >> time.txt
starttime=$(date +%Y-%m-%d\ %H:%M:%S)
echo $starttime >> time.txt

for i in 1 2 3 4 5 6 7 8; do
        for filename in ./*.csv; do
                clickhouse-client --port --use_client_time_zone true --query="INSERT INTO taq FORMAT CSV" < $filename
        done 
done

echo "end time:" >> time.txt
endtime=$(date +"%Y-%m-%d %H:%M:%S")
echo $endtime >> time.txt

# 恢复
# sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime