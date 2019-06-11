
starttime=start$(date +%Y-%m-%d\ %H:%M:%S)
echo $starttime 
for ((a=1; a<=1000;a++)) do
    clickhouse-client --port 19001 --use_client_time_zone true --query="INSERT INTO test_table FORMAT CSV" < rand.csv
    echo $a
done 
endtime=end$(date +"%Y-%m-%d %H:%M:%S")
echo $endtime 